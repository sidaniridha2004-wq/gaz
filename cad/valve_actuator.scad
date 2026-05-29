// =============================================================================
//  valve_actuator.scad
//  Parametric 3D-printed SERVO-ACTUATED BALL VALVE mount (two-plate cage)
// -----------------------------------------------------------------------------
//  Style: matches the classic servo-actuated ball valve build -> two parallel
//  plates sandwich the valve, joined by FOUR corner standoffs (the yellow rods
//  in the reference photo). The MG996R servo bolts to the TOP plate with its
//  output shaft COAXIAL to the valve stem and drives the stem directly through
//  a coupler. The cage reacts all the torque so nothing twists on the pipe.
//
//      [ TOP PLATE ] <- servo bolts here, shaft on stem axis
//        |  |  |  |    <- 4 standoffs (threaded rod + nuts, or printed)
//      [ BOT PLATE ] <- valve body seats here
//           ||         <- pipe passes out the sides
//
//  Force path: servo horn -> stem_coupler -> valve stem -> ball turns 90 deg.
//
//  PRINTED PARTS:
//    1. bottom_plate   (x1)   seats the valve body, anchors the standoffs
//    2. top_plate      (x1)   holds the servo + clears the stem coupler
//    3. stem_coupler   (x1)   servo horn  ->  valve stem flats
//    4. standoff       (x4)   OPTIONAL printed spacer; or use M4 threaded rod
//
//  Units = mm. Print PETG (preferred) / PLA, 0.2 mm layers, 4 walls,
//  40-60% infill. The coupler is the load-critical part -> print it solid.
// =============================================================================

// ============================ PARAMETERS =====================================
// ---- VALVE (MEASURE YOURS with calipers and edit) --------------------------
valve_body_od     = 28.0;  // round body outer diameter (where it sits in plate)
valve_body_h      = 30.0;  // body height = gap set between the two plates
pipe_od           = 14.0;  // pipe / union OD that exits the sides of the cage
stem_dia          = 7.0;   // round diameter of the valve stem
stem_flat_across  = 5.5;   // distance across the two stem flats (double-D)
stem_flat_len     = 9.0;   // length of the flats down from the stem top
stem_top_z        = 22.0;  // valve body top -> stem top (stem sticks up this far)

// ---- MG996R SERVO (standard; change only for another servo) ----------------
servo_body_l      = 40.5;  // body length
servo_body_w      = 20.0;  // body width
servo_shaft_off   = 10.0;  // output-shaft offset from body length-center
servo_horn_dia    = 24.0;  // round horn outer diameter
servo_horn_th     = 5.0;   // horn thickness (sits in coupler recess)
servo_mh_dia      = 4.3;   // flange mount-hole dia (M4)
servo_mh_span_l   = 49.5;  // flange hole spacing along length
servo_mh_span_w   = 10.0;  // flange hole spacing across width
servo_clear_w     = 21.0;  // body slot width in the plate (body + clearance)
servo_clear_l     = 41.5;  // body slot length in the plate

// ---- PLATES + CAGE ---------------------------------------------------------
plate_l           = 72.0;  // plate length (X)
plate_w           = 52.0;  // plate width  (Y)
plate_th          = 6.0;   // plate thickness
corner_inset      = 7.0;   // standoff hole inset from plate corners
standoff_hole     = 4.4;   // M4 clearance for the standoff rods
standoff_od       = 9.0;   // printed-standoff outer diameter (if used)

// ---- STEM COUPLER ----------------------------------------------------------
coupler_dia       = 22.0;  // coupler outer diameter
coupler_h         = 16.0;  // coupler height
coupler_fit       = 0.30;  // clearance on the stem flats (print tolerance)
horn_screw_dia    = 2.6;   // self-tap holes for horn screws (M2.5/M3)
horn_screw_pcd    = 14.0;  // horn screw pitch-circle diameter
horn_screw_n      = 4;     // number of horn screws

// ---- misc ------------------------------------------------------------------
eps = 0.01;
$fn = 96;

// ============================ DERIVED ========================================
// Standoff hole centers (shared by both plates so the cage lines up).
sx = plate_l/2 - corner_inset;
sy = plate_w/2 - corner_inset;
standoff_pts = [[ sx, sy], [-sx, sy], [-sx,-sy], [ sx,-sy]];

// Servo body center is offset so the output SHAFT lands on the plate center
// (= the valve stem axis). MG996R shaft is servo_shaft_off from body center.
servo_cx = -servo_shaft_off;

// ============================ HELPERS ========================================
// Vertical prism shaped like the valve stem: a cylinder with two flats.
module stem_profile(d, across, h) {
    intersection() {
        cylinder(h = h, d = d);
        cube([d + 1, across, 2*h], center = true);
    }
}

module corner_holes(d) {
    for (p = standoff_pts)
        translate([p[0], p[1], -eps])
            cylinder(h = plate_th + 2*eps, d = d);
}

// ===================== PART 1: BOTTOM PLATE =================================
// The valve body seats in a shallow circular pocket; the pipe escapes through
// side slots. Four corner holes anchor the standoffs.
module bottom_plate() {
    color("Silver")
    difference() {
        // plate
        translate([-plate_l/2, -plate_w/2, 0])
            cube([plate_l, plate_w, plate_th]);

        // shallow seat pocket so the valve body cannot slide around
        translate([0, 0, plate_th - 2.5])
            cylinder(h = 2.5 + eps, d = valve_body_od + 0.6);

        // central bore (lets the lower stem / body boss clear if needed)
        translate([0,0,-eps])
            cylinder(h = plate_th + 2*eps, d = pipe_od + 2);

        // pipe pass-through slots on +X / -X edges
        for (mx = [1, -1])
            translate([mx*plate_l/2, 0, plate_th/2])
                rotate([0,90,0])
                    cylinder(h = 24, d = pipe_od + 1.5, center = true);

        corner_holes(standoff_hole);
    }
}

// ===================== PART 2: TOP PLATE ====================================
// Holds the servo (shaft centered on the stem axis) and clears the coupler.
module top_plate() {
    color("Gainsboro")
    difference() {
        translate([-plate_l/2, -plate_w/2, 0])
            cube([plate_l, plate_w, plate_th]);

        // servo body slot (body drops through; flanges rest on the plate top)
        translate([servo_cx, 0, -eps])
            translate([-servo_clear_l/2, -servo_clear_w/2, 0])
                cube([servo_clear_l, servo_clear_w, plate_th + 2*eps]);

        // servo flange mounting holes (4, around the body slot)
        for (mx = [1,-1])
            for (my = [1,-1])
                translate([servo_cx + mx*servo_mh_span_l/2,
                           my*servo_mh_span_w/2, -eps])
                    cylinder(h = plate_th + 2*eps, d = servo_mh_dia);

        corner_holes(standoff_hole);
    }
}

// ===================== PART 3: STEM COUPLER =================================
// Bottom: socket matching the valve stem double-D. Top: recess + screw holes
// for the servo horn. Servo turns horn -> turns coupler -> turns stem.
module stem_coupler() {
    color("LimeGreen")
    difference() {
        cylinder(h = coupler_h, d = coupler_dia);

        // stem socket (bottom)
        translate([0,0,-eps])
            stem_profile(stem_dia + coupler_fit,
                         stem_flat_across + coupler_fit,
                         stem_flat_len + 1);

        // servo-horn recess (top)
        translate([0,0,coupler_h - servo_horn_th])
            cylinder(h = servo_horn_th + eps, d = servo_horn_dia + 0.6);

        // central clearance through-hole
        translate([0,0,-eps])
            cylinder(h = coupler_h + 2*eps, d = 4.2);

        // horn fixing screws
        for (i = [0:horn_screw_n-1])
            rotate([0,0, i*360/horn_screw_n])
                translate([horn_screw_pcd/2, 0, coupler_h - servo_horn_th - 6])
                    cylinder(h = 6 + eps, d = horn_screw_dia);
    }
}

// ===================== PART 4: STANDOFF (optional printed) ==================
// Use 4. If you prefer metal M4 threaded rod + nuts (like the yellow rods in
// the photo), skip printing these and set the rod length = valve_body_h.
module standoff() {
    color("Goldenrod")
    difference() {
        cylinder(h = valve_body_h, d = standoff_od);
        translate([0,0,-eps])
            cylinder(h = valve_body_h + 2*eps, d = standoff_hole);
    }
}

// ===================== GHOST REFERENCE (not printed) ========================
module ghost_valve() {
    %union() {
        // body
        translate([0,0,-valve_body_h + plate_th])  // sit on bottom plate top
            cylinder(h = valve_body_h, d = valve_body_od);
        // pipe out both sides
        translate([0,0,-valve_body_h/2 + plate_th])
            rotate([0,90,0])
                cylinder(h = plate_l + 30, d = pipe_od, center = true);
        // stem up
        translate([0,0,plate_th])
            stem_profile(stem_dia, stem_flat_across, stem_top_z);
    }
}

module ghost_servo() {
    %color("IndianRed")
    translate([servo_cx, 0, valve_body_h + plate_th*2 + 1])
        translate([-servo_body_l/2, -servo_body_w/2, 0])
            cube([servo_body_l, servo_body_w, 38]);
}

// ============================ VIEWS =========================================
module assembled_view() {
    // bottom plate at z=0
    bottom_plate();

    // standoffs rise from the bottom plate top
    translate([0,0,plate_th])
        for (p = standoff_pts) translate([p[0], p[1], 0]) standoff();

    // top plate on top of the standoffs
    translate([0,0,plate_th + valve_body_h]) top_plate();

    // stem coupler: sits on the stem, just under the top plate
    translate([0,0,plate_th + (stem_top_z - stem_flat_len)])
        stem_coupler();

    ghost_valve();
    ghost_servo();
}

module print_plate() {
    g = plate_l/2 + 10;
    translate([-g, 0, 0]) bottom_plate();
    translate([ g, 0, 0]) top_plate();
    translate([-g, plate_w, 0]) stem_coupler();
    for (i = [0:3])
        translate([ g - 18 + i*12, plate_w, 0]) standoff();
}

// ============================ RENDER SELECT =================================
// Show ONE. Default = assembled visualization.
assembled_view();

// --- For STL export: comment assembled_view() and uncomment ONE -------------
// bottom_plate();
// top_plate();
// stem_coupler();
// standoff();
// print_plate();
