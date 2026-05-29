// =============================================================================
//  Central Control Unit (Hub) firmware  --  installed at the gas source
// -----------------------------------------------------------------------------
//  Responsibilities:
//    * Listen for encrypted ESP-NOW packets from every registered sensor node.
//    * On a confirmed ALERT, within <1 s:  close the ball valve (relay+servo),
//      sound the buzzer, show the alert on the 16x2 LCD, and SMS the homeowner.
//    * Keep the valve CLOSED until (a) every room reports safe AND (b) the
//      physical reset button is pressed  (safety interlock).
//    * Track per-room liveness, readings and battery for the LCD.
//
//  State machine:   NORMAL  --alert-->  ALARM  --all clear-->  AWAIT_RESET
//                      ^                                            |
//                      +-------------- reset btn + air safe --------+
// =============================================================================
#include <Arduino.h>
#include <WiFi.h>
#include <esp_now.h>
#include <esp_wifi.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <ESP32Servo.h>

#include "protocol.h"
#include "node_registry.h"

// ---- Link encryption (must match the nodes) --------------------------------
#ifndef ESPNOW_ENCRYPT
#define ESPNOW_ENCRYPT 1
#endif

// ---- Homeowner phone number for SMS alerts (E.164) -------------------------
#ifndef HOMEOWNER_PHONE
#define HOMEOWNER_PHONE "+10000000000"
#endif
// Set to 0 to compile/test without a SIM800L attached.
#ifndef GSM_ENABLE
#define GSM_ENABLE 1
#endif

// ---- Pin map ----------------------------------------------------------------
static const uint8_t PIN_SERVO  = 13;  // MG996R signal (PWM)
static const uint8_t PIN_RELAY  = 27;  // gates servo power
static const uint8_t PIN_BUZZER = 14;  // active buzzer (HIGH = on)
static const uint8_t PIN_RESET  = 15;  // momentary reset button to GND
static const uint8_t PIN_SIM_RX = 16;  // ESP RX  <- SIM800L TX
static const uint8_t PIN_SIM_TX = 17;  // ESP TX  -> SIM800L RX
// I2C LCD uses the default SDA=21 / SCL=22.

// Relay board polarity (most blue relay modules are active-LOW).
#define RELAY_ACTIVE_LOW 1
#if RELAY_ACTIVE_LOW
#define RELAY_ON()  digitalWrite(PIN_RELAY, LOW)
#define RELAY_OFF() digitalWrite(PIN_RELAY, HIGH)
#else
#define RELAY_ON()  digitalWrite(PIN_RELAY, HIGH)
#define RELAY_OFF() digitalWrite(PIN_RELAY, LOW)
#endif

// On a clean boot, should gas be flowing? true = open (utility-friendly),
// false = fail-safe closed until all nodes confirm safe + reset is pressed.
#ifndef BOOT_VALVE_OPEN
#define BOOT_VALVE_OPEN 1
#endif

// ---- Peripherals ------------------------------------------------------------
LiquidCrystal_I2C lcd(0x27, 16, 2);
Servo valveServo;

// ---- Hub state machine ------------------------------------------------------
enum HubState { STATE_NORMAL, STATE_ALARM, STATE_AWAIT_RESET };
static HubState state = STATE_NORMAL;
static bool valveClosed = false;

// ---- Per-room runtime state (parallel to NODE_REGISTRY) --------------------
struct RoomState {
  bool     seen      = false;
  uint32_t lastSeenMs = 0;
  uint16_t coPpm     = 0;
  uint16_t lpgPpm    = 0;
  uint8_t  triggered = TRIG_NONE;
  uint8_t  battery   = 0;
  bool     alerting  = false;
  bool     online    = false;
  bool     smsSent   = false;  // SMS already sent for the current event
};
static RoomState rooms[NODE_REGISTRY_COUNT];

// ---- ESP-NOW receive queue (callback -> main loop) -------------------------
struct RxItem {
  int       regIdx;
  SensorMsg msg;
};
static QueueHandle_t rxQueue = nullptr;

// =============================================================================
//  GSM / SIM800L helpers
// =============================================================================
static bool simWaitFor(const char *token, uint32_t timeoutMs) {
  uint32_t start = millis();
  size_t matched = 0;
  size_t need = strlen(token);
  while (millis() - start < timeoutMs) {
    while (Serial2.available()) {
      char c = (char)Serial2.read();
      Serial.write(c);  // mirror modem output to the debug console
      matched = (c == token[matched]) ? matched + 1 : (c == token[0] ? 1 : 0);
      if (matched == need) return true;
    }
    delay(2);
  }
  return false;
}

static void simInit() {
#if GSM_ENABLE
  Serial2.begin(9600, SERIAL_8N1, PIN_SIM_RX, PIN_SIM_TX);
  delay(1500);
  Serial.print(F("[GSM] init "));
  Serial2.print(F("AT\r"));
  bool ok = simWaitFor("OK", 2000);
  Serial2.print(F("AT+CMGF=1\r"));            // SMS text mode
  simWaitFor("OK", 2000);
  Serial2.print(F("AT+CSCS=\"GSM\"\r"));      // GSM character set
  simWaitFor("OK", 2000);
  Serial.println(ok ? F("OK") : F("(no response - check power/antenna)"));
#else
  Serial.println(F("[GSM] disabled at build time"));
#endif
}

static void sendSMS(const char *text) {
#if GSM_ENABLE
  Serial.printf("[GSM] SMS -> %s : %s\n", HOMEOWNER_PHONE, text);
  Serial2.print(F("AT+CMGF=1\r"));
  simWaitFor("OK", 2000);
  Serial2.print(F("AT+CMGS=\""));
  Serial2.print(F(HOMEOWNER_PHONE));
  Serial2.print(F("\"\r"));
  delay(300);                 // wait for the '>' prompt
  Serial2.print(text);
  Serial2.write(26);          // Ctrl+Z ends the message
  bool ok = simWaitFor("OK", 8000);
  Serial.println(ok ? F("[GSM] SMS sent") : F("[GSM] SMS send timeout"));
#else
  Serial.printf("[GSM-SIM] would SMS: %s\n", text);
#endif
}

// =============================================================================
//  Valve actuator (relay-gated servo)
// =============================================================================
static void closeValve() {
  RELAY_ON();                          // power the servo
  delay(20);
  valveServo.write(VALVE_CLOSED_DEG);  // rotate handle 90deg -> shut
  valveClosed = true;
  Serial.println(F("[VALVE] CLOSED (gas cut off)"));
  // Servo remains powered to hold torque against the valve spring.
}

static void openValve() {
  RELAY_ON();
  delay(20);
  valveServo.write(VALVE_OPEN_DEG);
  delay(800);                          // allow the handle to travel
  RELAY_OFF();                         // de-power servo to save energy
  valveClosed = false;
  Serial.println(F("[VALVE] OPEN (gas restored)"));
}

// =============================================================================
//  LCD helpers
// =============================================================================
static void lcdLine(uint8_t row, const String &s) {
  String line = s;
  while (line.length() < 16) line += ' ';
  if (line.length() > 16) line = line.substring(0, 16);
  lcd.setCursor(0, row);
  lcd.print(line);
}

// =============================================================================
//  Buzzer (non-blocking patterns)
// =============================================================================
static void updateBuzzer() {
  uint32_t now = millis();
  switch (state) {
    case STATE_ALARM:
      digitalWrite(PIN_BUZZER, (now / 300) % 2);   // fast on/off
      break;
    case STATE_AWAIT_RESET:
      digitalWrite(PIN_BUZZER, (now % 3000) < 80); // short chirp every 3 s
      break;
    default:
      digitalWrite(PIN_BUZZER, LOW);
      break;
  }
}

// =============================================================================
//  ESP-NOW
// =============================================================================
// Arduino-ESP32 2.0.x callback signature (IDF 4.4): sender MAC + payload.
static void onDataRecv(const uint8_t *mac, const uint8_t *data, int len) {
  if (len != (int)sizeof(SensorMsg)) return;
  SensorMsg m;
  memcpy(&m, data, sizeof(m));
  if (m.version != PROTOCOL_VERSION) return;

  int idx = registryIndexForMac(mac);
  if (idx < 0) return;  // packet from an unregistered device -> ignore

  RxItem item;
  item.regIdx = idx;
  item.msg = m;
  if (rxQueue) xQueueSend(rxQueue, &item, 0);
}

static void initEspNow() {
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  esp_wifi_set_channel(ESPNOW_CHANNEL, WIFI_SECOND_CHAN_NONE);

  Serial.print(F("[BOOT] HUB STA MAC (put this in HUB_MAC_BYTES on nodes): "));
  Serial.println(WiFi.macAddress());

  if (esp_now_init() != ESP_OK) {
    Serial.println(F("[FATAL] esp_now_init failed -- rebooting"));
    delay(2000);
    ESP.restart();
  }
  esp_now_register_recv_cb(onDataRecv);

#if ESPNOW_ENCRYPT
  esp_now_set_pmk((const uint8_t *)ESPNOW_PMK);
#endif

  // Register every known node so encrypted frames can be decrypted.
  for (size_t i = 0; i < NODE_REGISTRY_COUNT; ++i) {
    esp_now_peer_info_t peer = {};
    memcpy(peer.peer_addr, NODE_REGISTRY[i].mac, 6);
    peer.channel = ESPNOW_CHANNEL;
    peer.ifidx   = WIFI_IF_STA;
#if ESPNOW_ENCRYPT
    peer.encrypt = true;
    memcpy(peer.lmk, ESPNOW_LMK, 16);
#else
    peer.encrypt = false;
#endif
    if (esp_now_add_peer(&peer) != ESP_OK) {
      Serial.printf("[WARN] could not add peer for room %u\n",
                    NODE_REGISTRY[i].roomId);
    }
  }
  Serial.printf("[BOOT] %u node(s) registered, encryption=%d\n",
                (unsigned)NODE_REGISTRY_COUNT, ESPNOW_ENCRYPT);
}

// =============================================================================
//  Reset button (debounced, falling-edge = press)
// =============================================================================
static bool resetPressed() {
  static int lastReading = HIGH;
  static int stable = HIGH;
  static uint32_t lastChange = 0;
  int reading = digitalRead(PIN_RESET);
  if (reading != lastReading) {
    lastReading = reading;
    lastChange = millis();
  }
  if ((millis() - lastChange) > 50 && reading != stable) {
    stable = reading;
    if (stable == LOW) return true;  // press detected
  }
  return false;
}

// =============================================================================
//  Alarm / state-machine helpers
// =============================================================================
static const char *triggeredGasText(uint8_t trig) {
  if ((trig & TRIG_CO) && (trig & TRIG_LPG)) return "CO+LPG";
  if (trig & TRIG_CO)  return "CO";
  if (trig & TRIG_LPG) return "LPG";
  return "GAS";
}

static int firstAlertingRoom() {
  for (size_t i = 0; i < NODE_REGISTRY_COUNT; ++i)
    if (rooms[i].seen && rooms[i].alerting) return (int)i;
  return -1;
}

static bool anyAlerting() { return firstAlertingRoom() >= 0; }

static void enterAlarm() {
  state = STATE_ALARM;
  closeValve();  // fast path: gas off first
  Serial.println(F("[STATE] -> ALARM"));
}

// Compose + send the SMS for a newly alerting room.
static void smsForRoom(int i) {
  char buf[140];
  snprintf(buf, sizeof(buf),
           "GAS ALERT! %s (room %u): %s detected. CO=%u ppm, LPG=%u ppm. "
           "Gas valve CLOSED.",
           NODE_REGISTRY[i].name, NODE_REGISTRY[i].roomId,
           triggeredGasText(rooms[i].triggered), rooms[i].coPpm,
           rooms[i].lpgPpm);
  sendSMS(buf);
}

static void processMessage(const RxItem &item) {
  int i = item.regIdx;
  const SensorMsg &m = item.msg;
  RoomState &r = rooms[i];

  r.seen       = true;
  r.online     = true;
  r.lastSeenMs = millis();
  r.coPpm      = m.coPpm;
  r.lpgPpm     = m.lpgPpm;
  r.triggered  = m.triggered;
  r.battery    = m.batteryPct;

  bool danger = (m.msgType == MSG_ALERT) || (m.triggered != TRIG_NONE);
  bool clear  = (m.msgType == MSG_CLEAR);

  Serial.printf("[RX] room=%u type=%u trig=0x%02X CO=%u LPG=%u batt=%u%% seq=%lu\n",
                m.roomId, m.msgType, m.triggered, m.coPpm, m.lpgPpm,
                m.batteryPct, (unsigned long)m.seq);

  if (danger) {
    if (!r.alerting) {
      r.alerting = true;
      r.smsSent = false;  // new event -> allow one SMS
    }
  } else if (clear) {
    r.alerting = false;
  } else {  // STATUS with no trigger flag
    if (r.alerting && m.coPpm < CO_CLEAR_PPM && m.lpgPpm < LPG_CLEAR_PPM) {
      r.alerting = false;
    }
  }
}

// =============================================================================
//  LCD rendering (rotates through rooms in NORMAL)
// =============================================================================
static void updateLcd() {
  static uint32_t lastDraw = 0;
  static uint8_t rotor = 0;
  if (millis() - lastDraw < 1500) return;
  lastDraw = millis();

  if (state == STATE_ALARM) {
    int i = firstAlertingRoom();
    lcdLine(0, "** GAS ALERT **");
    if (i >= 0) {
      char b[20];
      snprintf(b, sizeof(b), "%s %s", NODE_REGISTRY[i].name,
               triggeredGasText(rooms[i].triggered));
      lcdLine(1, b);
    } else {
      lcdLine(1, "Valve CLOSED");
    }
    return;
  }

  if (state == STATE_AWAIT_RESET) {
    lcdLine(0, "Air CLEAR - safe");
    lcdLine(1, "Press RESET btn");
    return;
  }

  // NORMAL: header + rotating per-room readings.
  lcdLine(0, valveClosed ? "SYSTEM  VALVE-CL" : "SYSTEM OK  GAS:ON");
  if (NODE_REGISTRY_COUNT == 0) {
    lcdLine(1, "No nodes");
    return;
  }
  rotor = (rotor + 1) % NODE_REGISTRY_COUNT;
  RoomState &r = rooms[rotor];
  char b[20];
  if (!r.seen) {
    snprintf(b, sizeof(b), "%s --", NODE_REGISTRY[rotor].name);
  } else if (!r.online) {
    snprintf(b, sizeof(b), "%s OFFLINE", NODE_REGISTRY[rotor].name);
  } else {
    snprintf(b, sizeof(b), "%s C%u L%u", NODE_REGISTRY[rotor].name, r.coPpm,
             r.lpgPpm);
  }
  lcdLine(1, b);
}

// =============================================================================
//  Arduino entry points
// =============================================================================
void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println(F("\n=== Gas Safety Central Control Unit (Hub) ==="));

  pinMode(PIN_RELAY, OUTPUT);
  RELAY_OFF();
  pinMode(PIN_BUZZER, OUTPUT);
  digitalWrite(PIN_BUZZER, LOW);
  pinMode(PIN_RESET, INPUT_PULLUP);

  // LCD
  Wire.begin();
  lcd.init();
  lcd.backlight();
  lcdLine(0, "Gas Safety Hub");
  lcdLine(1, "starting...");

  // Servo / valve
  ESP32PWM::allocateTimer(0);
  valveServo.setPeriodHertz(50);
  valveServo.attach(PIN_SERVO, 500, 2400);  // MG996R pulse range (us)
#if BOOT_VALVE_OPEN
  openValve();
  state = STATE_NORMAL;
#else
  // Fail-safe: stay closed until air is confirmed clear and reset is pressed.
  closeValve();
  state = STATE_AWAIT_RESET;
#endif

  rxQueue = xQueueCreate(16, sizeof(RxItem));
  initEspNow();
  simInit();

  Serial.println(F("[BOOT] hub ready, monitoring nodes."));
}

void loop() {
  uint32_t now = millis();

  // 1) Drain received packets.
  RxItem item;
  while (rxQueue && xQueueReceive(rxQueue, &item, 0) == pdTRUE) {
    processMessage(item);
  }

  // 2) Mark stale nodes offline.
  for (size_t i = 0; i < NODE_REGISTRY_COUNT; ++i) {
    if (rooms[i].seen && (now - rooms[i].lastSeenMs) > NODE_OFFLINE_MS) {
      rooms[i].online = false;
    }
  }

  // 3) Send SMS for any room that just entered alert.
  for (size_t i = 0; i < NODE_REGISTRY_COUNT; ++i) {
    if (rooms[i].alerting && !rooms[i].smsSent) {
      rooms[i].smsSent = true;
      if (state != STATE_ALARM) enterAlarm();  // ensure valve shut first
      smsForRoom((int)i);
    }
  }

  // 4) State transitions.
  bool danger = anyAlerting();
  switch (state) {
    case STATE_NORMAL:
      if (danger) enterAlarm();
      break;
    case STATE_ALARM:
      if (!danger) {
        state = STATE_AWAIT_RESET;  // valve stays CLOSED (interlock)
        Serial.println(F("[STATE] ALARM -> AWAIT_RESET (air clear)"));
      }
      break;
    case STATE_AWAIT_RESET:
      if (danger) {
        enterAlarm();  // gas came back before reset
      } else if (resetPressed()) {
        openValve();
        for (size_t i = 0; i < NODE_REGISTRY_COUNT; ++i) rooms[i].smsSent = false;
        state = STATE_NORMAL;
        Serial.println(F("[STATE] AWAIT_RESET -> NORMAL (manual reset)"));
      }
      break;
  }

  // 5) Outputs.
  updateBuzzer();
  updateLcd();
}
