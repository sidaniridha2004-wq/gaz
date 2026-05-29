# Validation & Test Plan

Maps each project claim to a repeatable experiment with a pass criterion.
Record results in the table at the bottom.

## A. Gas concentration / calibration

| ID | Test | Method | Pass criterion |
|----|------|--------|----------------|
| A1 | R0 baseline stability | Boot node 5× in clean air; log `R0` | `R0` within ±15 % across boots |
| A2 | CO trip point | Inject CO test-gas; compare to reference detector | `ALERT` raised within ±20 % of 200 ppm |
| A3 | LPG trip point | Butane/LPG test-gas near sensor | `ALERT` raised at/above ~1000 ppm |
| A4 | ppm curve fit | 3 known concentrations vs logged ppm | monotonic, within ±25 % after A/B fit |

## B. Response time (target: shutoff <1 s after confirmation)

| ID | Test | Method | Pass criterion |
|----|------|--------|----------------|
| B1 | Node detect→TX | Timestamp from threshold cross to `[TX] ALERT` | < ~1.5 s (≈ 3 samples for the vote) |
| B2 | Hub RX→valve | Scope/log: `[RX]` to `[VALVE] CLOSED` | < 1 s |
| B3 | End-to-end | Gas applied → valve physically shut | < 2.5 s total (incl. vote window) |
| B4 | Servo travel | Time servo 0°→90° under load | < 0.7 s, valve fully closed |

> The 2-of-3 vote intentionally adds ~1 sample of latency to reject spikes; the
> *post-confirmation* shutoff (B2) is the <1 s figure.

## C. Wireless range & reliability (ESP-NOW)

| ID | Test | Method | Pass criterion |
|----|------|--------|----------------|
| C1 | Open-air range | Walk node away from hub; watch delivery cb | reliable to ≥ 30 m LoS |
| C2 | Through-walls | Node in adjacent rooms / floors | reliable within a typical house |
| C3 | Packet loss | Count `send FAILED` over 1000 packets | < 1 % at in-house distances |
| C4 | Encryption | Confirm peers paired; sniff to verify payload not plaintext | non-registered device ignored |

## D. False-alarm rejection

| ID | Test | Method | Pass criterion |
|----|------|--------|----------------|
| D1 | Single-sample spike | Inject a 1-sample transient (brief breath/lighter puff <1 s) | **no** `ALERT` (vote rejects it) |
| D2 | Warm-up suppression | Power on next to a gas source | no alert during the 120 s warm-up |
| D3 | Alert rate limit | Sustained over-threshold | ≤ 1 `ALERT` per 10 s per node |
| D4 | Hysteresis chatter | Hold gas just around threshold | no rapid alert/clear oscillation |

## E. Safety interlock & system behaviour

| ID | Test | Method | Pass criterion |
|----|------|--------|----------------|
| E1 | Manual-reset interlock | After alarm, clear air, press reset | valve opens **only** after reset *and* air clear |
| E2 | Premature reset blocked | Press reset while gas still present | valve stays closed |
| E3 | Multi-room | Trigger 2 rooms; clear 1 | valve stays closed until **all** clear |
| E4 | LCD content | Observe display in each state | shows room, gas type, ppm correctly |
| E5 | SMS delivery | Trigger alert | SMS received with room + gas + ppm |
| E6 | Node offline | Power off a node | hub flags it OFFLINE on LCD within 20 s |

## F. Power / resilience

| ID | Test | Method | Pass criterion |
|----|------|--------|----------------|
| F1 | Mains outage | Cut hub mains (UPS), cut node mains (LiPo) | system keeps detecting + can shut valve |
| F2 | Node battery report | Discharge LiPo; check `batt%` in logs | tracks voltage monotonically |
| F3 | Brownout-free GSM | Send SMS while logging hub | no resets during SIM800L TX burst |

## Results log (fill in)

| ID | Date | Result | Measured value | Notes |
|----|------|--------|----------------|-------|
| A1 |  |  |  |  |
| B2 |  |  |  |  |
| C1 |  |  |  |  |
| D1 |  |  |  |  |
| E1 |  |  |  |  |
| E3 |  |  |  |  |

## Bench testing without gas
* Use `-DGSM_ENABLE=0` to test the hub without a SIM800L attached.
* Temporarily lower `CO_THRESHOLD_PPM` / `LPG_THRESHOLD_PPM`, or breathe on / use
  a lighter (unlit, brief) near the MQ-2 to push readings up safely.
* The serial logs on both node and hub print every sample, packet and state
  transition, which is sufficient to validate the full logic chain on the bench.
