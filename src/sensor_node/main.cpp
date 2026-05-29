// =============================================================================
//  Sensor Node firmware  --  one per room
// -----------------------------------------------------------------------------
//  Responsibilities:
//    * Sample MQ-7 (CO) and MQ-2 (LPG) every 500 ms via ADC1.
//    * Warm up for 120 s, calibrating R0 in clean air.
//    * Convert readings to ppm and apply a 2-of-3 majority vote.
//    * On a confirmed over-threshold event, transmit an encrypted ESP-NOW
//      ALERT packet to the hub (rate-limited to one per 10 s).
//    * Send a heartbeat STATUS packet every 5 s and a CLEAR packet when the
//      air returns to safe levels (needed for the hub's reopen interlock).
//
//  Build identity is injected per device:  -DROOM_ID=2 -DROOM_NAME='"Kitchen"'
// =============================================================================
#include <Arduino.h>
#include <WiFi.h>
#include <esp_now.h>
#include <esp_wifi.h>

#include "protocol.h"
#include "mq_sensor.h"

// ---- Per-node identity (overridable via build flags) ------------------------
#ifndef ROOM_ID
#define ROOM_ID 1
#endif
#ifndef ROOM_NAME
#define ROOM_NAME "Room"
#endif

// ---- Enable/disable ESP-NOW link encryption --------------------------------
//  Encryption is recommended, but the ESP32 supports at most 6 *encrypted*
//  peers on the hub. For very large installations set -DESPNOW_ENCRYPT=0.
#ifndef ESPNOW_ENCRYPT
#define ESPNOW_ENCRYPT 1
#endif

// ---- Pin map (ADC1 only -- ADC2 is unusable while Wi-Fi/ESP-NOW is on) ------
static const uint8_t PIN_MQ7_CO  = 34;  // ADC1_CH6 (input-only)
static const uint8_t PIN_MQ2_LPG = 35;  // ADC1_CH7 (input-only)
static const uint8_t PIN_BATT    = 33;  // ADC1_CH5 (battery divider)
static const uint8_t PIN_LED     = 2;   // onboard status LED

// ---- Battery (3.7 V LiPo via 1:2 divider) ----------------------------------
static const float BATT_DIVIDER = 2.0f;   // two equal resistors
static const float BATT_FULL_V  = 4.20f;  // 100 %
static const float BATT_EMPTY_V = 3.30f;  // 0 %

// ---- Sensor objects ---------------------------------------------------------
//  Curve coefficients (A,B) and clean-air ratios are datasheet starting points
//  and MUST be refined during calibration (see docs/calibration.md).
//                     pin           RL      Vc    div   cleanRatio   A         B
MQSensor mq7(PIN_MQ7_CO,  10000.0f, 5.0f, 1.5f,  27.00f,    99.042f, -1.518f);
MQSensor mq2(PIN_MQ2_LPG,  5000.0f, 5.0f, 1.5f,   9.83f,   574.250f, -2.222f);

// ---- Hub peer ---------------------------------------------------------------
static uint8_t hubMac[6] = HUB_MAC_BYTES;

// ---- Runtime state ----------------------------------------------------------
static bool     sensorsReady   = false;   // true once warm-up completes
static uint32_t bootMs         = 0;
static uint32_t lastSampleMs   = 0;
static uint32_t lastStatusMs   = 0;
static uint32_t lastAlertMs    = 0;
static uint32_t seqCounter     = 0;
static bool     alertActive    = false;   // currently in an alert condition
static uint8_t  lastTriggered  = TRIG_NONE;

// 2-of-3 majority-vote ring buffers (one bit per recent reading).
static bool coVote[VOTE_WINDOW]  = {false};
static bool lpgVote[VOTE_WINDOW] = {false};
static uint8_t voteIdx   = 0;
static uint8_t voteCount = 0;   // saturates at VOTE_WINDOW

// Latest computed concentrations (cached for packets/logging).
static float coPpm  = 0.0f;
static float lpgPpm = 0.0f;

// -----------------------------------------------------------------------------
//  Helpers
// -----------------------------------------------------------------------------
static uint8_t countTrue(const bool *buf) {
  uint8_t n = 0;
  for (uint8_t i = 0; i < VOTE_WINDOW; ++i) n += buf[i] ? 1 : 0;
  return n;
}

static uint8_t readBatteryPercent() {
  uint32_t mv = 0;
  for (uint8_t i = 0; i < 16; ++i) mv += analogReadMilliVolts(PIN_BATT);
  float vbat = (mv / 16.0f) / 1000.0f * BATT_DIVIDER;
  float pct = (vbat - BATT_EMPTY_V) / (BATT_FULL_V - BATT_EMPTY_V) * 100.0f;
  if (pct < 0.0f) pct = 0.0f;
  if (pct > 100.0f) pct = 100.0f;
  return (uint8_t)(pct + 0.5f);
}

// ESP-NOW transmit-complete callback (diagnostics only).
static void onDataSent(const uint8_t *mac, esp_now_send_status_t status) {
  (void)mac;
  if (status != ESP_NOW_SEND_SUCCESS) {
    Serial.println(F("[ESP-NOW] send FAILED (hub out of range / powered off?)"));
  }
}

static void sendMessage(uint8_t msgType, uint8_t triggered) {
  SensorMsg msg = {};
  msg.version    = PROTOCOL_VERSION;
  msg.msgType    = msgType;
  msg.roomId     = (uint8_t)ROOM_ID;
  msg.triggered  = triggered;
  msg.coPpm      = (uint16_t)(coPpm  + 0.5f);
  msg.lpgPpm     = (uint16_t)(lpgPpm + 0.5f);
  msg.batteryPct = readBatteryPercent();
  msg.reserved   = 0;
  msg.seq        = ++seqCounter;
  msg.uptimeSec  = (millis() - bootMs) / 1000;

  esp_err_t r = esp_now_send(hubMac, (const uint8_t *)&msg, sizeof(msg));
  Serial.printf("[TX] type=%u room=%u trig=0x%02X CO=%uppm LPG=%uppm batt=%u%% seq=%lu %s\n",
                msgType, msg.roomId, triggered, msg.coPpm, msg.lpgPpm,
                msg.batteryPct, (unsigned long)msg.seq,
                (r == ESP_OK) ? "queued" : "ERR");
}

static bool initEspNow() {
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  // Pin the radio to the agreed channel so node and hub always match.
  esp_wifi_set_channel(ESPNOW_CHANNEL, WIFI_SECOND_CHAN_NONE);

  Serial.print(F("[BOOT] Node STA MAC: "));
  Serial.println(WiFi.macAddress());

  if (esp_now_init() != ESP_OK) {
    Serial.println(F("[ERR] esp_now_init failed"));
    return false;
  }
  esp_now_register_send_cb(onDataSent);

#if ESPNOW_ENCRYPT
  esp_now_set_pmk((const uint8_t *)ESPNOW_PMK);
#endif

  esp_now_peer_info_t peer = {};
  memcpy(peer.peer_addr, hubMac, 6);
  peer.channel = ESPNOW_CHANNEL;
  peer.ifidx   = WIFI_IF_STA;
#if ESPNOW_ENCRYPT
  peer.encrypt = true;
  memcpy(peer.lmk, ESPNOW_LMK, 16);
#else
  peer.encrypt = false;
#endif
  if (esp_now_add_peer(&peer) != ESP_OK) {
    Serial.println(F("[ERR] esp_now_add_peer (hub) failed"));
    return false;
  }
  Serial.printf("[BOOT] Hub peer registered %02X:%02X:%02X:%02X:%02X:%02X (encrypt=%d)\n",
                hubMac[0], hubMac[1], hubMac[2], hubMac[3], hubMac[4], hubMac[5],
                ESPNOW_ENCRYPT);
  return true;
}

// -----------------------------------------------------------------------------
//  Sampling + safety evaluation (called every SAMPLE_PERIOD_MS)
// -----------------------------------------------------------------------------
static void sampleAndEvaluate() {
  uint32_t upSec = (millis() - bootMs) / 1000;

  // ---- Warm-up window: heat sensors and calibrate R0 in clean air ----------
  if (!sensorsReady) {
    mq7.accumulateCalibration();
    mq2.accumulateCalibration();
    digitalWrite(PIN_LED, (millis() / 250) % 2);  // blink ~2 Hz
    if (upSec >= WARMUP_SEC) {
      mq7.finishCalibration();
      mq2.finishCalibration();
      sensorsReady = true;
      digitalWrite(PIN_LED, LOW);
      Serial.printf("[WARMUP] complete. R0(CO)=%.0f ohm  R0(LPG)=%.0f ohm\n",
                    mq7.r0(), mq2.r0());
    } else if (upSec % 15 == 0) {
      Serial.printf("[WARMUP] %lu/%lu s ...\n",
                    (unsigned long)upSec, (unsigned long)WARMUP_SEC);
    }
    return;
  }

  // ---- Normal operation ----------------------------------------------------
  coPpm  = mq7.readPpm();
  lpgPpm = mq2.readPpm();

  // Push this reading into the vote ring buffers.
  coVote[voteIdx]  = (coPpm  >= CO_THRESHOLD_PPM);
  lpgVote[voteIdx] = (lpgPpm >= LPG_THRESHOLD_PPM);
  voteIdx = (voteIdx + 1) % VOTE_WINDOW;
  if (voteCount < VOTE_WINDOW) voteCount++;

  bool windowFull = (voteCount >= VOTE_WINDOW);
  bool coTrip  = windowFull && (countTrue(coVote)  >= VOTE_NEEDED);
  bool lpgTrip = windowFull && (countTrue(lpgVote) >= VOTE_NEEDED);

  uint8_t triggered = TRIG_NONE;
  if (coTrip)  triggered |= TRIG_CO;
  if (lpgTrip) triggered |= TRIG_LPG;

  Serial.printf("[SAMPLE] CO=%.0fppm(%c) LPG=%.0fppm(%c) trig=0x%02X\n",
                coPpm,  coTrip  ? 'X' : '.',
                lpgPpm, lpgTrip ? 'X' : '.', triggered);

  if (triggered != TRIG_NONE) {
    // Alert: send immediately on a new/changed condition, otherwise honour the
    // minimum 10 s alert interval to avoid flooding the hub.
    bool changed = (triggered != lastTriggered);
    if (changed || (millis() - lastAlertMs) >= MIN_ALERT_GAP_MS) {
      sendMessage(MSG_ALERT, triggered);
      lastAlertMs = millis();
    }
    alertActive   = true;
    lastTriggered = triggered;
    digitalWrite(PIN_LED, HIGH);  // solid LED = danger
  } else {
    // Air is below the trip points. If we had been alerting, only declare the
    // all-clear once we drop below the lower hysteresis levels.
    bool safe = (coPpm < CO_CLEAR_PPM) && (lpgPpm < LPG_CLEAR_PPM);
    if (alertActive && safe) {
      sendMessage(MSG_CLEAR, TRIG_NONE);
      alertActive   = false;
      lastTriggered = TRIG_NONE;
      Serial.println(F("[CLEAR] air returned to safe levels"));
    }
    digitalWrite(PIN_LED, LOW);
  }
}

// -----------------------------------------------------------------------------
//  Arduino entry points
// -----------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println();
  Serial.printf("=== Gas Safety Sensor Node | room %d \"%s\" ===\n",
                (int)ROOM_ID, ROOM_NAME);

  pinMode(PIN_LED, OUTPUT);
  digitalWrite(PIN_LED, LOW);

  analogReadResolution(12);
  mq7.begin();
  mq2.begin();
  mq7.resetCalibration();
  mq2.resetCalibration();

  if (!initEspNow()) {
    Serial.println(F("[FATAL] ESP-NOW init failed -- rebooting in 3 s"));
    delay(3000);
    ESP.restart();
  }

  bootMs = millis();
  Serial.printf("[BOOT] warming up sensors for %lu s...\n",
                (unsigned long)WARMUP_SEC);
}

void loop() {
  uint32_t now = millis();

  if (now - lastSampleMs >= SAMPLE_PERIOD_MS) {
    lastSampleMs = now;
    sampleAndEvaluate();
  }

  // Heartbeat so the hub knows the node is alive and sees live levels.
  if (sensorsReady && (now - lastStatusMs >= STATUS_PERIOD_MS)) {
    lastStatusMs = now;
    sendMessage(MSG_STATUS, alertActive ? lastTriggered : TRIG_NONE);
  }
}
