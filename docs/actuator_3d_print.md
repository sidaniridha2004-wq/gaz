# 3D-Printed Valve Actuator

A custom PLA assembly couples an MG996R servo to a ¼" brass ball valve so a 90°
servo rotation drives the valve handle from **open** to **closed**.

## Assembly (3 printed parts)

```
        ┌─────────────────┐
        │  servo platform │  ← MG996R bolts here (M3), raised so the horn
        │   (bridges the  │     aligns with the valve handle axis
        │   valve body)   │
        └────────┬────────┘
                 │  M3 standoffs
   ┌─────────────┴─────────────┐
   │  two-piece clamp (halves)  │  ← wraps the valve body; M4 bolts pull the
   │  bolted around valve body  │     halves together (rigid, no rotation)
   └────────────────────────────┘

   servo horn ──[coupler arm]── valve handle
   (the arm has a slot/D-profile that grips the OEM handle)
```

1. **Two-piece clamp** – split cylindrical clamp sized to the valve body OD.
   The two halves bolt together (M4) and react the actuation torque so the
   whole assembly does not spin on the pipe.
2. **Servo platform** – mounts on the clamp via standoffs; locates the MG996R so
   its output shaft is coaxial (or parallel-and-offset) with the valve handle.
3. **Coupler arm** – links the servo horn to the valve handle. One end matches
   the MG996R spline (use the OEM horn captured in a pocket, or a printed
   24-tooth spline); the other end is a slot/D-shape gripping the handle.

## Recommended print settings (PLA / PETG)

| Parameter | Value | Reason |
|-----------|-------|--------|
| Material | **PETG** preferred (PLA OK indoors) | PETG tolerates heat/creep better |
| Layer height | 0.2 mm | balance of speed/strength |
| Walls / perimeters | 4 | torque-bearing parts |
| Infill | 40–60 % | clamp & coupler see real load |
| Top/bottom layers | 5 | stiffness |
| Orientation | print coupler so layers are **across** the torque path | avoid splitting along layer lines |

> The coupler arm is the most stressed part — print it so the servo torque
> loads the part *across* the layers, not peeling them apart.

## Torque / mechanical check

* MG996R stall torque ≈ **9–11 kg·cm @ 6 V**.
* A clean ¼" ball valve needs roughly **3–6 kg·cm** to turn; verify your actual
  valve with a small torque wrench / luggage scale + lever arm.
* Add a **mechanical hard stop** at the 90° closed position so the servo is not
  fighting the handle end-stop indefinitely (reduces stall heating).
* If torque is marginal, increase the coupler lever length or step up to a
  higher-torque servo (e.g. DS3218, ~20 kg·cm).

## Design files

This repo ships **firmware + design docs**; the CAD/STL files are produced
separately (Fusion 360 / FreeCAD / OpenSCAD). Suggested deliverables to add
under `cad/`:
* `valve_clamp_half.stl` (print ×2)
* `servo_platform.stl`
* `coupler_arm.stl`
* source `.f3d` / `.FCStd` / `.scad`

Parameterise the clamp bore diameter and the handle slot so the same model fits
different valve sizes.

## Safety note

This printed actuator is a **prototype** to demonstrate the electromechanical
integration. A production system would use a listed motorised/solenoid gas
shutoff valve certified for fuel-gas service.
