# Wiring Reference

All GPIO numbers match the firmware. Double-check against your specific ESP32
DevKit silkscreen (pin *positions* vary between boards, GPIO *numbers* do not).

## Sensor node

| Signal | ESP32 GPIO | Connects to | Notes |
|--------|-----------|-------------|-------|
| MQ-7 (CO) analog out | **GPIO34** (ADC1_CH6) | divider → MQ-7 `AO` | input-only pin |
| MQ-2 (LPG) analog out | **GPIO35** (ADC1_CH7) | divider → MQ-2 `AO` | input-only pin |
| Battery sense | **GPIO33** (ADC1_CH5) | LiPo+ via 1:2 divider | 4.2 V → 2.1 V |
| Status LED | **GPIO2** | onboard LED | warm-up blink / solid = alert |
| MQ heaters Vcc | 5 V | boost converter out | ~150 mA each |
| Grounds | GND | common | tie all grounds together |

**Why a divider on the MQ outputs?** The MQ modules output up to ~5 V but the
ESP32 ADC tops out at ~3.3 V. Use R1 = 10 kΩ (from `AO`) and R2 = 20 kΩ (to GND);
the ADC reads `AO × 20/30 = 0.667·AO`, i.e. 5 V → 3.33 V. This matches the
firmware's `dividerRatio = 1.5`.

```
 MQ AO ──[10k]──┬── GPIO34/35 (ADC)
                │
              [20k]
                │
               GND
```

Battery divider: two equal resistors (e.g. 100 kΩ/100 kΩ) → `BATT_DIVIDER = 2.0`.

### Power chain (node)
```
LiPo 3.7V ─ TP4056 (charge/protect) ─┬─ MT3608 boost → 5V → MQ heaters
                                     └─ ESP32 5V/VIN (or 3V3 via LDO)
```

## Central hub

| Signal | ESP32 GPIO | Connects to | Notes |
|--------|-----------|-------------|-------|
| Servo PWM | **GPIO13** | MG996R signal | 50 Hz, 500–2400 µs |
| Relay control | **GPIO27** | relay `IN` | active-LOW board (see firmware) |
| Buzzer | **GPIO14** | active buzzer + | HIGH = on |
| Reset button | **GPIO15** | button → GND | uses internal pull-up |
| LCD SDA | **GPIO21** | LCD `SDA` | I2C |
| LCD SCL | **GPIO22** | LCD `SCL` | I2C, addr 0x27 |
| SIM800L → ESP RX | **GPIO16** | SIM800L `TXD` | |
| ESP TX → SIM800L | **GPIO17** | SIM800L `RXD` | level-OK at 3.3 V logic |

### Relay → servo power path
```
5V 2A ──▶ relay COM
relay NO ──▶ MG996R Vcc        (servo powered only when relay is energised)
GPIO27 ──▶ relay IN            (active-LOW: LOW = energise = servo on)
GPIO13 ──▶ MG996R signal
GND common (ESP32 + servo + relay)
```

### SIM800L power (do this right or it browns out)
```
5V ──▶ buck converter ──▶ 4.0 V ──▶ SIM800L VCC
                                     ╫── 1000 µF cap across VCC/GND
GND common with ESP32
```

## Common-ground rule
Every subsystem (ESP32, sensors, servo, relay, SIM800L, LCD) **must share a
common ground**. Floating grounds are the #1 cause of "works on the bench,
fails when assembled" behaviour with these modules.
