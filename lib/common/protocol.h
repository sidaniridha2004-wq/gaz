// =============================================================================
//  protocol.h  --  Shared definitions for the Gas & CO Safety System
// -----------------------------------------------------------------------------
//  This header is compiled into BOTH the sensor-node and hub firmware. The
//  on-air packet layout, the ESP-NOW encryption keys, and the safety
//  thresholds MUST be identical on every device, so they live in one place.
//
//  IMPORTANT: a packed struct is sent verbatim over ESP-NOW. Do not reorder
//  fields or change types without re-flashing every node and the hub.
// =============================================================================
#pragma once
#include <stdint.h>

// -----------------------------------------------------------------------------
//  Protocol version. The hub rejects packets whose version it does not know.
// -----------------------------------------------------------------------------
static const uint8_t PROTOCOL_VERSION = 1;

// -----------------------------------------------------------------------------
//  Hub MAC address.
//  Each sensor node is pre-registered with this address as its ESP-NOW peer.
//  Flash the hub once, read its STA MAC from the serial log, then paste it
//  here and re-flash the nodes. (Override at build time with -DHUB_MAC_BYTES=)
//  Format: six comma-separated hex bytes.
// -----------------------------------------------------------------------------
#ifndef HUB_MAC_BYTES
#define HUB_MAC_BYTES { 0x24, 0x6F, 0x28, 0x00, 0x00, 0x01 }
#endif

// -----------------------------------------------------------------------------
//  ESP-NOW link encryption (AES-128 / CCMP). Both keys are 16 bytes.
//  PMK = Primary Master Key (one per network). LMK = Local Master Key (per
//  peer link). CHANGE THESE before any real deployment.
// -----------------------------------------------------------------------------
#define ESPNOW_PMK "GasSafetyPMK_001"   // exactly 16 chars
#define ESPNOW_LMK "GasSafetyLMK_001"   // exactly 16 chars

// Fixed Wi-Fi channel used by every device (nodes + hub must match).
static const uint8_t ESPNOW_CHANNEL = 1;

// -----------------------------------------------------------------------------
//  Gas channels. A node carries one CO sensor (MQ-7) and one combustible-gas
//  sensor (MQ-2 for LPG / methane / propane).
// -----------------------------------------------------------------------------
enum GasChannel : uint8_t {
  GAS_CO  = 0,   // Carbon monoxide   (MQ-7)
  GAS_LPG = 1,   // LPG / methane     (MQ-2)
};

// Bitmask used in the "triggered" field so a single packet can flag both gases.
static const uint8_t TRIG_NONE = 0x00;
static const uint8_t TRIG_CO   = 0x01;   // bit0
static const uint8_t TRIG_LPG  = 0x02;   // bit1

// -----------------------------------------------------------------------------
//  Message types.
//   ALERT  : a confirmed over-threshold event -> hub must shut the valve.
//   STATUS : periodic heartbeat with live readings (proves the node is alive).
//   CLEAR  : a previously-alerting node reports it is back to safe levels.
// -----------------------------------------------------------------------------
enum MsgType : uint8_t {
  MSG_ALERT  = 1,
  MSG_STATUS = 2,
  MSG_CLEAR  = 3,
};

// -----------------------------------------------------------------------------
//  The packet exchanged over ESP-NOW (sensor node -> hub).
//  Kept small (16 bytes) for sub-5 ms transmission.
// -----------------------------------------------------------------------------
typedef struct __attribute__((packed)) {
  uint8_t  version;       // = PROTOCOL_VERSION
  uint8_t  msgType;       // MsgType
  uint8_t  roomId;        // unique room identifier (1..N)
  uint8_t  triggered;     // TRIG_* bitmask (which gas(es) crossed threshold)
  uint16_t coPpm;         // measured CO   concentration (ppm)
  uint16_t lpgPpm;        // measured LPG  concentration (ppm)
  uint8_t  batteryPct;    // node battery state of charge (0..100 %)
  uint8_t  reserved;      // padding / future use (keep struct word-aligned)
  uint32_t seq;           // monotonically increasing sequence number
  uint32_t uptimeSec;     // node uptime in seconds (diagnostics)
} SensorMsg;

// -----------------------------------------------------------------------------
//  Safety thresholds (ppm). Trigger an alert at-or-above these values.
//   CO  200 ppm  -> sustained exposure causes headache/nausea.
//   LPG 1000 ppm -> ~2% of the lower explosive limit; early-warning level.
// -----------------------------------------------------------------------------
static const uint16_t CO_THRESHOLD_PPM  = 200;
static const uint16_t LPG_THRESHOLD_PPM = 1000;

// A node is considered "clear" only when readings fall back below these
// hysteresis levels (lower than the trip points) to avoid chatter.
static const uint16_t CO_CLEAR_PPM  = 150;
static const uint16_t LPG_CLEAR_PPM = 700;

// -----------------------------------------------------------------------------
//  Timing constants (milliseconds unless noted).
// -----------------------------------------------------------------------------
static const uint32_t SAMPLE_PERIOD_MS    = 500;     // ADC sampling cadence
static const uint32_t WARMUP_SEC          = 120;     // sensor warm-up / R0 cal
static const uint32_t MIN_ALERT_GAP_MS    = 10000;   // min interval between alerts
static const uint32_t STATUS_PERIOD_MS    = 5000;    // heartbeat cadence
static const uint8_t  VOTE_WINDOW         = 3;       // readings in the vote window
static const uint8_t  VOTE_NEEDED         = 2;       // 2-of-3 majority to trip

// Hub-side: if no STATUS/ALERT from a node for this long, mark it offline.
static const uint32_t NODE_OFFLINE_MS     = 20000;

// Hub-side servo angles for the ball-valve coupler.
static const int VALVE_OPEN_DEG   = 0;    // gas flowing
static const int VALVE_CLOSED_DEG = 90;   // gas cut off

// Maximum number of rooms the hub tracks simultaneously.
static const uint8_t MAX_ROOMS = 16;
