// =============================================================================
//  valve_actuator.scad
//  Parametric 3D-printed gas valve actuator for MG996R servo + 1/4" ball valve
// -----------------------------------------------------------------------------
//  Assembly:
//    1. Two-piece clamp (bolts around the valve body, reacts torque)
//    2. Servo platform (bridges the clamp, holds the MG996R)
//    3. Coupler arm (links servo horn spline to the valve handle)
//
//  Units: millimeters. Print in PETG or PLA, 0.2mm layers, 4 walls, 50% infill.
//  Author: Generated for the Gas Safety System project
// =============================================================================

// ---- PARAMETERS (adjust to your valve + servo) -----------------------------

// Ball valve body
valve_body_od       = 28.0;    // outer diameter of the valve body (measure!)
valve_body_length   = 30.0;    // how much of the body the clamp grips
handle_height       = 15.0;    // center of handle above top of valve body
handle_width        = 8.0;     // valve handle cross-section (flat/D shape)
handle_thickness    = 4.0;     // handle thickness (for D-slot grip)

// MG996R servo dimensions (standard, don't change unless different servo)
servo_body_l        = 40.5;    // length (along shaft axis)
servo_body_w        = 20.0;    // width
servo_body_h        = 38.0;    // height (bottom to top of case, excl shaft)
servo_flange_l      = 54.5;    // total length including mounting flanges
servo_flange_w      = 20.0;    // flange width (same as body)
servo_flange_h      = 2.5;     // flange thickness
servo_flange_z      = 28.0;    // height from bottom to flange underside
servo_shaft_offset  = 10.0;    // shaft center offset from body center (along L)
servo_shaft_dia     = 6.0;     // output shaft diameter
servo_horn_dia      = 25.0;    // horn circle diameter (for clearance)
servo_mount_hole    = 4.5;     // mounting screw hole diameter (M4)
servo_mount_spacing_l = 49.0;  // hole-to-hole along length
servo_mount_spacing_w = 10.0;  // hole-to-hole along width

// Clamp design
clamp_wall          = 5.0;     // wall thickness of the clamp halves
clamp_bolt_dia      = 4.5;     // M4 bolt holes to join halves
clamp_bolt_count    = 2;       // bolts per side (top & bottom)
clamp_bolt_margin   = 6.0;     // distance from clamp end to bolt center
clamp_gap           = 0.4;     // split gap (accounts for print tolerance)

// Platform
platform_thickness  = 5.0;     // thickness of the servo mounting plate
platform_standoff_h = 10.0;    // height of standoffs above clamp top
standoff_dia        = 10.0;    // standoff outer diameter
standoff_hole_dia   = 4.5;     // M4 through-hole in standoffs

// Coupler arm
coupler_length      = 35.0;    // center-to-center (servo shaft to valve handle)
coupler_width       = 12.0;    // arm width
coupler_thickness   = 8.0;     // arm thickness
horn_bore_dia       = 6.2;     // bore for the servo horn hub (press-fit)
horn_screw_dia      = 3.2;     // M3 screw to hold horn in coupler

// Rendering quality
$fn = 64;

// ---- DERIVED VALUES --------------------------------------------------------
clamp_od = valve_body_od + 2 * clamp_wall;
clamp_r  = clamp_od / 2;
valve_r  = valve_body_od / 2;

// =============================================================================
//  MODULE: clamp_half
//  One half of the two-piece clamp. Print 2x, bolt together around valve body.
// =============================================================================
module clamp_half() {
    difference() {
        union() {
            // Main semicircular body
            difference() {
                cylinder(h = valve_body_length, r = clamp_r);
                cylinder(h = valve_body_length + 1, r = valve_r + 0.2); // bore + clearance
                // Cut away the other half
                translate([-clamp_r - 1, -clamp_r - 1, -0.5])
                    cube([clamp_od + 2, clamp_r + 1 - clamp_gap/2, valve_body_length + 1]);
            }
            // Bolt flanges (flat ears sticking out for the clamping bolts)
            for (z = [clamp_bolt_margin, valve_body_length - clamp_bolt_margin]) {
                translate([0, clamp_r - 1, z])
                    rotate([-90, 0, 0])
                        cylinder(h = clamp_wall, r = clamp_bolt_dia + 2);
                translate([0, -(clamp_r - 1) - clamp_wall, z])
                    rotate([-90, 0, 0])
                        cylinder(h = clamp_wall, r = clamp_bolt_dia + 2);
            }
        }
        // Bolt holes through the flanges
        for (z = [clamp_bolt_margin, valve_body_length - clamp_bolt_margin]) {
            translate([0, -clamp_r - clamp_wall - 1, z])
                rotate([-90, 0, 0])
                    cylinder(h = clamp_od + 2 * clamp_wall + 2, d = clamp_bolt_dia);
        }
    }
}

// =============================================================================
//  MODULE: servo_platform
//  Mounts on top of the assembled clamp via standoffs. Holds the MG996R.
// =============================================================================
module servo_platform() {
    plate_l = servo_flange_l + 10;
    plate_w = max(clamp_od + 10, servo_flange_w + 10);

    difference() {
        union() {
            // Main plate
            translate([-plate_l/2, -plate_w/2, 0])
                cube([plate_l, plate_w, platform_thickness]);

            // Standoffs (connect down to clamp bolt positions)
            for (x = [-servo_mount_spacing_l/2, servo_mount_spacing_l/2]) {
                for (y = [-servo_mount_spacing_w/2, servo_mount_spacing_w/2]) {
                    translate([x, y, -platform_standoff_h])
                        cylinder(h = platform_standoff_h, d = standoff_dia);
                }
            }
        }

        // Servo body pocket (recessed into the plate for stability)
        translate([-servo_body_l/2, -servo_body_w/2, -1])
            cube([servo_body_l, servo_body_w, platform_thickness + 2]);

        // Servo mounting screw holes (M4 through flanges)
        for (x = [-servo_mount_spacing_l/2, servo_mount_spacing_l/2]) {
            for (y = [-servo_mount_spacing_w/2, servo_mount_spacing_w/2]) {
                translate([x, y, -platform_standoff_h - 1])
                    cylinder(h = platform_standoff_h + platform_thickness + 2,
                             d = servo_mount_hole);
            }
        }

        // Shaft clearance hole (servo output shaft + horn pass through)
        translate([servo_shaft_offset, 0, -1])
            cylinder(h = platform_thickness + 2, d = servo_horn_dia + 4);

        // Standoff bolt holes (M4, for attaching to clamp)
        for (x = [-servo_mount_spacing_l/2, servo_mount_spacing_l/2]) {
            for (y = [-servo_mount_spacing_w/2, servo_mount_spacing_w/2]) {
                translate([x, y, -platform_standoff_h - 1])
                    cylinder(h = platform_standoff_h + platform_thickness + 2,
                             d = standoff_hole_dia);
            }
        }
    }
}

// =============================================================================
//  MODULE: coupler_arm
//  Links the servo horn to the valve handle. Transmits the 90-degree rotation.
// =============================================================================
module coupler_arm() {
    difference() {
        union() {
            // Main arm body
            hull() {
                // Servo end (circular)
                cylinder(h = coupler_thickness, d = coupler_width);
                // Valve handle end (circular)
                translate([coupler_length, 0, 0])
                    cylinder(h = coupler_thickness, d = coupler_width);
            }

            // Boss around horn bore (thicker for grip)
            cylinder(h = coupler_thickness + 2, d = coupler_width - 2);
        }

        // Servo horn bore (round hole to accept the horn hub)
        translate([0, 0, -1])
            cylinder(h = coupler_thickness + 4, d = horn_bore_dia);

        // Horn retaining screw (M3 from top, threads into horn)
        translate([0, 0, coupler_thickness - 2])
            cylinder(h = 5, d = horn_screw_dia);

        // Valve handle slot (D-shape / rectangular to grip the flat handle)
        translate([coupler_length - handle_width/2,
                   -handle_thickness/2, -1])
            cube([handle_width, handle_thickness, coupler_thickness + 2]);

        // Pinch slot on valve end (allows slight flex for handle grip)
        translate([coupler_length - 0.5, -coupler_width/2, -1])
            cube([1.0, coupler_width, coupler_thickness + 2]);
    }
}

// =============================================================================
//  MODULE: assembled_view
//  Shows all parts in their assembled positions (for visualization only).
// =============================================================================
module assembled_view() {
    color("DodgerBlue", 0.7) {
        // Bottom clamp half
        clamp_half();
        // Top clamp half (rotated 180 around Z)
        rotate([0, 0, 180]) clamp_half();
    }

    // Platform above the clamp
    color("Orange", 0.8)
        translate([0, 0, valve_body_length + platform_standoff_h])
            servo_platform();

    // Coupler arm above the platform (at shaft height)
    color("LimeGreen", 0.9)
        translate([servo_shaft_offset,
                   0,
                   valve_body_length + platform_standoff_h + platform_thickness + 2])
            coupler_arm();

    // Ghost: valve body (for reference, not printed)
    %cylinder(h = valve_body_length, r = valve_r);

    // Ghost: valve handle (for reference)
    %translate([-coupler_length + servo_shaft_offset, -handle_thickness/2,
                valve_body_length + platform_standoff_h + platform_thickness + handle_height])
        cube([handle_width, handle_thickness, 20]);
}

// =============================================================================
//  MODULE: print_plate
//  Lays all parts flat for 3D printing on one build plate.
// =============================================================================
module print_plate() {
    spacing = clamp_od + 15;

    // Clamp half 1
    translate([0, 0, 0])
        rotate([90, 0, 0])
            clamp_half();

    // Clamp half 2
    translate([spacing, 0, 0])
        rotate([90, 0, 0])
            rotate([0, 0, 180])
                clamp_half();

    // Servo platform (flat, as-is)
    translate([0, -spacing, 0])
        servo_platform();

    // Coupler arm (flat, as-is)
    translate([spacing, -spacing, 0])
        coupler_arm();
}

// =============================================================================
//  RENDER SELECTION
//  Uncomment ONE of these to render/export individual STLs or view assembly.
// =============================================================================

// Option 1: Full assembled view (default - for visualization)
assembled_view();

// Option 2: Print plate (all parts laid flat for slicing)
// print_plate();

// Option 3: Individual parts (uncomment one for STL export)
// clamp_half();
// servo_platform();
// coupler_arm();
