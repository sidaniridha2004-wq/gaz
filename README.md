# Intelligent Home Gas & CO Detection Safety System

An ESP32-based safety system that detects carbon monoxide (CO) and combustible
gas (LPG / methane / propane) in every room of a house and **automatically shuts
off the gas supply at the source** when a confirmed leak is detected.

The system is split into two firmware subsystems that talk over **ESP-NOW**
(router-free, peer-to-peer Wi-Fi):

```
   ┌────────────────────┐        ESP-NOW (encrypted, <5 ms)        ┌───────────────────────────┐
   │  Sensor Node (xN)   │  ───────────────────────────────────▶   │   Central Control Unit     │
   │  per room           │     ALERT / STATUS / CLEAR packets       │   (Hub @ gas source)       │
   │                     │                                          │                            │
   │  ESP32              │                                          │  ESP32                     │
   │  MQ-7  (CO)         │                                          │  Relay ─ Servo ─ Ball valve│
   │  MQ-2  (LPG)        │                                          │  Buzzer                    │
   │  LiPo + TP4056      │                                          │  16x2 I2C LCD              │
   │                     │                                          │  SIM800L GSM (SMS)         │
   └────────────────────┘                                          │  Reset button (interlock)  │
                                                                    └───────────────────────────┘
```

## Repository layout

```
gas-safety-system/
├── platformio.ini              # two build envs: sensor_node + hub
├── lib/common/protocol.h       # shared ESP-NOW packet + thresholds + timing
├── src/
│   ├── sensor_node/
│   │   ├── main.cpp            # sampling, warm-up cal, vote, ESP-NOW TX
│   │   └── mq_sensor.{h,cpp}   # Rs/R0 -> ppm gas-sensor driver
│   └── hub/
│       ├── main.cpp            # ESP-NOW RX, valve, LCD, buzzer, GSM, FSM
│       └── node_registry.h     # MAC <-> room table (edit for your install)
└── docs/
    ├── BOM.md                  # bill of materials + cost
    ├── wiring.md               # pin-by-pin connections
    ├── calibration.md          # MQ sensor calibration procedure
    ├── actuator_3d_print.md    # 3D-printed valve clamp / coupler
    └── test_plan.md            # validation experiments
```

## How it works

### Sensor node (one per room)
1. **Warm-up (120 s):** the MQ heaters stabilise. During this window the node
   averages the clean-air sensor resistance to compute `R0`.
2. **Sampling (every 500 ms):** each sensor's voltage is read on an ADC1 pin,
   converted to a resistance `Rs`, and turned into ppm with the datasheet curve
   `ppm = A·(Rs/R0)^B`.
3. **Majority vote (2 of 3):** a reading only counts as a trip if at least 2 of
   the last 3 samples are over threshold — this rejects single-sample spikes.
4. **Alert:** on a confirmed trip (`CO ≥ 200 ppm` or `LPG ≥ 1000 ppm`) the node
   sends an encrypted `ALERT` packet to the hub (rate-limited to 1 per 10 s).
   It also sends a `STATUS` heartbeat every 5 s and a `CLEAR` packet once the
   air drops back below the lower hysteresis levels.

### Central hub (at the gas source)
On receiving an `ALERT` it executes the **fast safety path in under 1 second**:
close the valve → sound the buzzer → update the LCD. It then sends an SMS to the
homeowner (slower, done after the valve is already shut).

The valve is held **CLOSED** until **both** conditions are met (safety interlock):
* every room reports gas back to safe levels, **and**
* the physical **reset button** on the hub is pressed.

```
 NORMAL ──(alert)──▶ ALARM ──(all rooms clear)──▶ AWAIT_RESET ──(reset btn)──▶ NORMAL
   ▲                                                   │
   └──────────────── (gas returns) ◀───────────────────┘
```

## Build & flash (PlatformIO)

Each room is its own build environment (`node_living_room`, `node_kitchen`,
`node_bedroom`, …). Add a room by copying a `node_*` block in `platformio.ini`
and changing `ROOM_ID` / `ROOM_NAME`. Verified: all environments compile for
`esp32dev`.

```bash
# Install PlatformIO Core (once)
pip install platformio

# Build everything (sanity check)
pio run

# --- Hub ---
pio run -e hub -t upload
pio device monitor -b 115200          # note the printed HUB STA MAC

# --- Sensor nodes (one env per room) ---
pio run -e node_living_room -t upload
pio run -e node_kitchen     -t upload
pio run -e node_bedroom     -t upload
```

### One-time pairing procedure
1. Flash the **hub**, open the serial monitor, copy the printed
   `HUB STA MAC` into `HUB_MAC_BYTES` in `lib/common/protocol.h`.
2. Flash each **node**; copy each printed `Node STA MAC` + its room into
   `src/hub/node_registry.h` (the `roomId` there must match the env's `ROOM_ID`).
3. Re-flash the hub. Nodes and hub now trust each other (encrypted ESP-NOW).
4. Set the homeowner phone number in the `hub` env build flags, e.g.
   `-DHOMEOWNER_PHONE='"+15551234567"'`. Use `-DGSM_ENABLE=0` to build/test
   without a SIM800L attached.

## Key configuration (in `lib/common/protocol.h`)

| Setting | Default | Meaning |
|---|---|---|
| `CO_THRESHOLD_PPM` | 200 | CO alert trip point |
| `LPG_THRESHOLD_PPM` | 1000 | combustible-gas alert trip point |
| `SAMPLE_PERIOD_MS` | 500 | ADC sampling cadence |
| `WARMUP_SEC` | 120 | sensor warm-up / R0 calibration |
| `VOTE_NEEDED / VOTE_WINDOW` | 2 / 3 | majority vote |
| `MIN_ALERT_GAP_MS` | 10000 | min interval between alerts per node |
| `VALVE_OPEN_DEG / CLOSED_DEG` | 0 / 90 | servo angles |

Build-flag options: `ESPNOW_ENCRYPT` (1/0), `GSM_ENABLE` (1/0),
`BOOT_VALVE_OPEN` (1/0), `HOMEOWNER_PHONE`, `ROOM_ID`, `ROOM_NAME`.

## Important engineering notes & limitations

* **ADC1 only on nodes.** ESP-NOW uses the Wi-Fi radio, which makes ADC2 pins
  unusable. The sensors are therefore on GPIO34/35 (ADC1).
* **MQ-7 CO accuracy.** A laboratory-grade MQ-7 reading needs a dual-voltage
  heater cycle (5 V/1.4 V). This prototype runs the common constant-5 V module,
  which is adequate for threshold alarming but not metrology — see
  `docs/calibration.md`.
* **Encrypted-peer limit.** The ESP32 supports at most **6 encrypted** ESP-NOW
  peers. For more than 6 rooms either build with `-DESPNOW_ENCRYPT=0` or run
  multiple hub radios. (The "unlimited nodes" goal holds for the *unencrypted*
  configuration.)
* **Curve constants must be calibrated.** The `A`, `B` and clean-air ratios in
  `src/sensor_node/main.cpp` are datasheet starting points; calibrate against a
  reference per `docs/calibration.md` before trusting absolute ppm values.
* **Safety scope.** This is an academic prototype demonstrating the full
  electromechanical + firmware integration. It is **not** a certified life-safety
  appliance and should not be relied upon as a sole protection device.

See `docs/` for the bill of materials, wiring, calibration, 3D-printed actuator,
and the validation test plan.
