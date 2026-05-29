# MQ Sensor Calibration

The firmware reports ppm via the standard MQ model:

```
Rs  = RL · (Vc − Vout) / Vout          # sensor resistance
R0  = Rs_clean_air / clean_air_ratio   # baseline (measured at warm-up)
ppm = A · (Rs / R0)^B                  # datasheet log-log curve
```

There are **two** things to calibrate: the per-unit baseline `R0` (done
automatically) and the gas curve constants `A`, `B` (done once per sensor type).

## 1. Automatic R0 baseline (every boot)

During the 120 s warm-up the node must be in **clean air**. It averages `Rs`
and computes `R0 = Rs_clean / clean_air_ratio` using:

| Sensor | `clean_air_ratio` (Rs/R0 in air) | source |
|--------|----------------------------------|--------|
| MQ-2 (LPG) | 9.83 | datasheet |
| MQ-7 (CO)  | 27.0 (verify per unit) | datasheet/empirical |

Watch the serial log line after warm-up:
```
[WARMUP] complete. R0(CO)=NNN ohm  R0(LPG)=NNN ohm
```
A sane MQ-2 `R0` is typically tens of kΩ. Wildly different values usually mean
a wrong `RL`, a missing divider, or a sensor still off-gassing (run it for a few
hours first, "burn-in").

## 2. Gas curve constants A, B

`A` and `B` come from linearising the datasheet curve on a log-log plot:
```
log(ppm) = log(A) + B · log(Rs/R0)   ⇒   pick two points (x1,y1),(x2,y2)
B = (log y1 − log y2) / (log x1 − log x2)
A = y1 / x1^B
```
Read two `(Rs/R0, ppm)` points off the target-gas line in the datasheet
(e.g. MQ-2 LPG curve, MQ-7 CO curve) and compute `A`, `B`. Defaults shipped in
`src/sensor_node/main.cpp`:

| Sensor / gas | A | B |
|--------------|---|---|
| MQ-7 / CO  | 99.042 | −1.518 |
| MQ-2 / LPG | 574.25 | −2.222 |

Update the `MQSensor` constructor arguments after computing your own.

## 3. Setting RL (load resistor)

Cheap modules have RL set by an onboard resistor or trimmer pot (often
0.5–20 kΩ). Measure it with a multimeter (power off) and set `rlOhms` in the
`MQSensor` constructor to match. The firmware defaults: MQ-7 = 10 kΩ,
MQ-2 = 5 kΩ.

## 4. Reference-gas verification (recommended)

1. Place the node + a calibrated reference detector in a sealed test chamber.
2. Inject a known gas concentration (e.g. a 50 % LEL test-gas can for LPG, or a
   CO test-gas can for MQ-7).
3. Compare the firmware's ppm log against the reference; adjust `A`/`B` until
   the trip points (`200 ppm` CO, `1000 ppm` LPG) line up.
4. Record the response time from injection to `ALERT` for the test plan.

## 5. Known accuracy caveats

* **MQ-7 ideally needs a heater duty cycle** (5 V for 60 s, then 1.4 V for 90 s)
  for accurate CO measurement. This firmware reads at constant 5 V (typical for
  the cheap modules), which is fine for *threshold alarming* but not precise
  metrology. Implementing the dual-voltage cycle is a good extension: drive the
  heater through a transistor/PWM and sample at the end of the low phase.
* MQ sensors drift with temperature/humidity and age; re-verify periodically.
* Treat reported ppm as **relative/indicative**, with the safety value being the
  reliable *crossing* of a calibrated threshold, not the absolute number.
