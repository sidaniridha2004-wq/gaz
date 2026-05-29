# Bill of Materials (BOM)

Indicative hobbyist prices (USD). A **3-room** system = 3 sensor nodes + 1 hub.

## Per sensor node (×N rooms)

| # | Component | Qty | ~Unit | Notes |
|---|-----------|----:|------:|-------|
| 1 | ESP32 DevKit (WROOM-32) | 1 | $4.50 | dual-core, Wi-Fi/ESP-NOW |
| 2 | MQ-7 module (CO) | 1 | $2.00 | analog output |
| 3 | MQ-2 module (LPG/methane) | 1 | $1.80 | analog output |
| 4 | 3.7 V LiPo cell (1200–2000 mAh) | 1 | $4.00 | runtime depends on heaters |
| 5 | TP4056 charge module (w/ protection) | 1 | $0.60 | USB-C charging |
| 6 | MT3608 / 5 V boost converter | 1 | $0.70 | MQ heaters need 5 V |
| 7 | Resistors (divider 10k/20k ×2, batt 2×100k) | — | $0.20 | ADC scaling |
| 8 | Enclosure + vents + wiring | 1 | $2.00 | ventilated for airflow |
| | **Node subtotal** | | **≈ $15.6** | |

> The MQ heaters draw ~150 mA at 5 V continuously, so a node is effectively a
> low-power *plugged* device; the LiPo is primarily for outage ride-through.
> For a permanently battery-only node, budget a larger cell or USB power.

## Central hub (×1)

| # | Component | Qty | ~Unit | Notes |
|---|-----------|----:|------:|-------|
| 1 | ESP32 DevKit (WROOM-32) | 1 | $4.50 | hub controller |
| 2 | MG996R servo (metal gear) | 1 | $3.50 | valve actuator |
| 3 | 1-channel 5 V relay module | 1 | $1.00 | gates servo power |
| 4 | 16×2 I2C LCD (PCF8574) | 1 | $2.50 | status display |
| 5 | SIM800L GSM module + antenna | 1 | $4.50 | SMS alerts |
| 6 | Active buzzer (5 V) | 1 | $0.40 | local alarm |
| 7 | Momentary push button | 1 | $0.20 | manual reset |
| 8 | ¼" brass ball valve | 1 | $3.50 | shutoff element |
| 9 | 3D-printed clamp + coupler (PLA) | 1 | $1.50 | ~40 g filament |
| 10| 5 V 2 A supply + small UPS/power bank | 1 | $6.00 | SIM800L bursts to ~2 A |
| 11| Buck/LDO for SIM800L (~4.0 V) | 1 | $0.80 | SIM800L is not 5 V tolerant |
| | **Hub subtotal** | | **≈ $32.9** | |

## System totals

| System | Nodes | Approx. total |
|--------|------:|--------------:|
| 1-room | 1 | ≈ $48 |
| 3-room | 3 | ≈ $79 |

> The headline "$40–60 for 3 rooms" is achievable with bulk/AliExpress pricing
> and by omitting the UPS/boost extras; the table above is a conservative
> single-unit estimate.

## Critical sourcing notes
* **SIM800L power:** needs a stable 3.4–4.4 V rail able to source ~2 A pulses.
  Powering it from the ESP32 3V3 pin **will not work** and causes brownout
  resets. Use a dedicated buck converter + a large electrolytic cap (≥1000 µF).
* **MG996R stall current** is ~2.5 A. Power the servo from the 5 V rail through
  the relay, **not** from the ESP32 regulator.
* Use a 2G/GSM-capable SIM and confirm 2G is still available in your region.
