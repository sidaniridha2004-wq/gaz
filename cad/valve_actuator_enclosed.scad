// ============================================================
// Valve Actuator Node – 3D-Printed Clamp Housing
// Gas Safety System – OpenSCAD Parametric Design
// ============================================================
// Two clamshell halves that clamp around a brass ball valve body.
// High-torque servo on top, ESP32 + relay mounted internally.
// ============================================================

/* [Valve Body Parameters] */
valve_body_diameter    = 33;    // mm – brass ball valve hex body across-flats
valve_body_length      = 50;    // mm – length of hex section
valve_stem_diameter    = 8;     // mm – square stem (across flats)
valve_clearance        = 0.5;   // mm – radial clearance around valve body

/* [Housing Shell] */
wall_thickness         = 3.0;   // mm
housing_split_plane    = 0;     // 0 = horizontal split (top/bottom halves)
bolt_diameter          = 4.0;   // M4 clamping bolts
bolt_count             = 4;     // bolts joining two halves
bolt_head_diameter     = 7.5;   // M4 cap head
bolt_nut_trap          = 7.8;   // M4 nut width across flats
bolt_nut_height        = 3.2;   // M4 nut thickness

/* [Servo Mount] */
// MG996R / DS3218 form factor
servo_length           = 40.5;  // mm
servo_width            = 20.0;  // mm
servo_height           = 38.0;  // mm (body only)
servo_flange_width     = 54.5;  // mm (ear to ear)
servo_flange_thickness = 2.5;   // mm
servo_shaft_offset     = 10.0;  // mm from center to shaft axis
servo_mount_holes      = 49.0;  // mm between mounting holes (diagonal pair)
servo_mount_hole_dia   = 3.2;   // M3 clearance
servo_platform_size    = [56, 42]; // platform top surface

/* [Electronics Plate] */
esp32_board_size       = [51, 25, 1.6]; // NodeMCU Mini / DevKit narrow
relay_board_size       = [35, 25, 1.6]; // single 5V relay module
electronics_plate_thickness = 2.0;
standoff_height        = 6.0;
standoff_diameter      = 5.0;
standoff_hole          = 2.5;   // M2.5

/* [Cable & Ventilation] */
cable_gland_hole       = 12.0;  // PG7 cable gland
vent_hole_diameter     = 3.0;
vent_rows              = 3;
vent_cols              = 4;
vent_spacing           = 5.0;

/* [Derived Dimensions] */
inner_radius = (valve_body_diameter / 2) + valve_clearance;
outer_radius = inner_radius + wall_thickness;
total_housing_width  = outer_radius * 2 + 20; // extra for electronics bay
total_housing_height = outer_radius * 2 + servo_height + 20;
total_housing_length = valve_body_length + 20;

// Explode for visualization (set to 0 for assembled view)
explode = 15; // mm separation between halves

$fn = 64;

// ============================================================
// MODULES
// ============================================================

module hex_pocket(diameter, length, clearance) {
    // Hexagonal pocket matching valve body
    af = diameter + clearance * 2; // across-flats with clearance
    translate([0, 0, -length/2])
        linear_extrude(height = length)
            circle(d = af, $fn = 6);
}

module valve_pocket_cylinder(diameter, length, clearance) {
    // Cylindrical pocket (simpler, works for round or hex bodies)
    r = diameter / 2 + clearance;
    translate([0, 0, -length/2])
        cylinder(r = r, h = length);
}

module bolt_hole(x, y, z, length) {
    translate([x, y, z])
        rotate([0, 0, 0])
            cylinder(d = bolt_diameter, h = length, center = true);
}

module bolt_head_recess(x, y, z) {
    translate([x, y, z])
        cylinder(d = bolt_head_diameter, h = 5, center = false);
}

module nut_trap(x, y, z) {
    translate([x, y, z])
        rotate([0, 0, 30])
            cylinder(d = bolt_nut_trap, h = bolt_nut_height, $fn = 6);
}

module servo_mount_platform() {
    // Flat platform on top of housing for servo
    pw = servo_platform_size[0];
    pd = servo_platform_size[1];
    ph = servo_flange_thickness + 2;
    
    difference() {
        translate([-pw/2, -pd/2, 0])
            cube([pw, pd, ph]);
        
        // Servo body pocket (goes down into housing)
        translate([servo_shaft_offset, 0, -0.1])
            cube([servo_width + 1, servo_length + 1, ph + 1], center = true);
        
        // Mounting holes (4 corners of servo flange)
        for (dx = [-servo_mount_holes/2, servo_mount_holes/2])
            for (dy = [-10, 10])
                translate([dx, dy, -0.1])
                    cylinder(d = servo_mount_hole_dia, h = ph + 1);
        
        // Shaft pass-through hole
        translate([0, 0, -0.1])
            cylinder(d = valve_stem_diameter + 4, h = ph + 1);
    }
}

module standoff(h, d_outer, d_hole) {
    difference() {
        cylinder(d = d_outer, h = h);
        translate([0, 0, -0.1])
            cylinder(d = d_hole, h = h + 0.2);
    }
}

module electronics_bay() {
    // Internal mounting plate with standoffs for ESP32 + relay
    plate_w = esp32_board_size[0] + relay_board_size[0] + 10;
    plate_d = max(esp32_board_size[1], relay_board_size[1]) + 6;
    
    // Vertical plate
    color("DarkGray", 0.6)
    translate([0, 0, 0]) {
        // Base plate
        cube([plate_w, plate_d, electronics_plate_thickness], center = true);
        
        // ESP32 standoffs
        esp_x_off = -plate_w/4;
        for (dx = [-esp32_board_size[0]/2 + 3, esp32_board_size[0]/2 - 3])
            for (dy = [-esp32_board_size[1]/2 + 3, esp32_board_size[1]/2 - 3])
                translate([esp_x_off + dx, dy, electronics_plate_thickness/2])
                    standoff(standoff_height, standoff_diameter, standoff_hole);
        
        // Relay standoffs
        rel_x_off = plate_w/4;
        for (dx = [-relay_board_size[0]/2 + 3, relay_board_size[0]/2 - 3])
            for (dy = [-relay_board_size[1]/2 + 3, relay_board_size[1]/2 - 3])
                translate([rel_x_off + dx, dy, electronics_plate_thickness/2])
                    standoff(standoff_height, standoff_diameter, standoff_hole);
    }
}

module vent_grid(rows, cols, hole_d, spacing) {
    for (r = [0:rows-1])
        for (c = [0:cols-1])
            translate([c * spacing, r * spacing, 0])
                cylinder(d = hole_d, h = wall_thickness + 1, center = true);
}

module cable_gland_hole() {
    cylinder(d = cable_gland_hole, h = wall_thickness + 2, center = true);
}

// ============================================================
// MAIN HOUSING – BOTTOM HALF
// ============================================================

module housing_bottom_half() {
    difference() {
        // Outer shell – elongated shape to include electronics bay
        hull() {
            // Valve pocket region (cylindrical)
            translate([0, 0, 0])
                cylinder(r = outer_radius, h = total_housing_length, center = true);
            // Electronics bay extension
            translate([outer_radius + 10, 0, 0])
                cube([30, outer_radius * 2, total_housing_length], center = true);
        }
        
        // Inner valve pocket (hex)
        hex_pocket(valve_body_diameter, valve_body_length + 2, valve_clearance);
        
        // Pipe pass-through holes (both ends)
        for (side = [-1, 1])
            translate([0, 0, side * (total_housing_length / 2)])
                cylinder(d = valve_body_diameter - 5, h = 20, center = true);
        
        // Split plane – cut away top half
        translate([-100, -100, 0])
            cube([200, 200, 100]);
        
        // Bolt holes (4 corners)
        for (i = [0:bolt_count-1]) {
            angle = i * 360 / bolt_count + 45;
            bx = (outer_radius + 5) * cos(angle);
            by = (outer_radius + 5) * sin(angle);
            // Through-holes along Z
            for (zpos = [-total_housing_length/4, total_housing_length/4])
                translate([bx, by, zpos])
                    cylinder(d = bolt_diameter, h = outer_radius * 2, center = true);
        }
        
        // Nut traps on bottom
        for (i = [0:bolt_count-1]) {
            angle = i * 360 / bolt_count + 45;
            bx = (outer_radius + 5) * cos(angle);
            by = (outer_radius + 5) * sin(angle);
            for (zpos = [-total_housing_length/4, total_housing_length/4])
                translate([bx, by, zpos - outer_radius])
                    nut_trap(0, 0, 0);
        }
        
        // Ventilation holes on side
        translate([outer_radius + 25, 0, 0])
            rotate([0, 90, 0])
                vent_grid(vent_rows, vent_cols, vent_hole_diameter, vent_spacing);
        
        // Cable gland hole (bottom, side)
        translate([outer_radius + 20, 0, -total_housing_length/3])
            rotate([0, 90, 0])
                cable_gland_hole();
    }
}

// ============================================================
// MAIN HOUSING – TOP HALF
// ============================================================

module housing_top_half() {
    difference() {
        union() {
            // Outer shell (same as bottom)
            hull() {
                translate([0, 0, 0])
                    cylinder(r = outer_radius, h = total_housing_length, center = true);
                translate([outer_radius + 10, 0, 0])
                    cube([30, outer_radius * 2, total_housing_length], center = true);
            }
            
            // Servo platform on top
            translate([0, 0, outer_radius])
                servo_mount_platform();
        }
        
        // Inner valve pocket (hex)
        hex_pocket(valve_body_diameter, valve_body_length + 2, valve_clearance);
        
        // Pipe pass-through holes
        for (side = [-1, 1])
            translate([0, 0, side * (total_housing_length / 2)])
                cylinder(d = valve_body_diameter - 5, h = 20, center = true);
        
        // Split plane – cut away bottom half
        translate([-100, -100, -100])
            cube([200, 200, 100]);
        
        // Valve stem pass-through to servo
        translate([0, 0, outer_radius - 1])
            cylinder(d = valve_stem_diameter + 2, h = 20);
        
        // Bolt holes (same positions as bottom)
        for (i = [0:bolt_count-1]) {
            angle = i * 360 / bolt_count + 45;
            bx = (outer_radius + 5) * cos(angle);
            by = (outer_radius + 5) * sin(angle);
            for (zpos = [-total_housing_length/4, total_housing_length/4])
                translate([bx, by, zpos])
                    cylinder(d = bolt_diameter, h = outer_radius * 2, center = true);
        }
        
        // Bolt head recesses on top
        for (i = [0:bolt_count-1]) {
            angle = i * 360 / bolt_count + 45;
            bx = (outer_radius + 5) * cos(angle);
            by = (outer_radius + 5) * sin(angle);
            for (zpos = [-total_housing_length/4, total_housing_length/4])
                translate([bx, by, zpos + outer_radius - 4])
                    cylinder(d = bolt_head_diameter, h = 5);
        }
        
        // Ventilation on electronics bay side
        translate([outer_radius + 25, 0, 5])
            rotate([0, 90, 0])
                vent_grid(vent_rows, vent_cols, vent_hole_diameter, vent_spacing);
    }
}

// ============================================================
// HANDLE COUPLER (replaces butterfly handle)
// ============================================================

module valve_stem_coupler() {
    // Connects servo horn to valve stem with 45-degree offset
    coupler_height = 15;
    coupler_outer_d = 20;
    stem_socket_depth = 10;
    horn_mount_depth = 5;
    
    difference() {
        cylinder(d = coupler_outer_d, h = coupler_height);
        
        // Bottom: square socket for valve stem (rotated 45 degrees)
        rotate([0, 0, 45])
            translate([0, 0, -0.1])
                linear_extrude(height = stem_socket_depth + 0.1)
                    square(valve_stem_diameter + 0.3, center = true);
        
        // Top: servo horn screw hole
        translate([0, 0, coupler_height - horn_mount_depth])
            cylinder(d = 3.2, h = horn_mount_depth + 0.1);
        
        // Grub screw hole (M3) to lock onto stem
        translate([coupler_outer_d/2, 0, stem_socket_depth/2])
            rotate([0, -90, 0])
                cylinder(d = 3.0, h = coupler_outer_d/2 + 1);
    }
}

// ============================================================
// ASSEMBLY VIEW
// ============================================================

module assembly() {
    // Bottom half
    color("LightGray", 0.8)
        translate([0, 0, -explode/2])
            housing_bottom_half();
    
    // Top half
    color("LightBlue", 0.8)
        translate([0, 0, explode/2])
            housing_top_half();
    
    // Servo (simplified representation)
    color("DarkSlateGray", 0.7)
        translate([0, 0, outer_radius + explode/2 + servo_flange_thickness + 2])
            cube([servo_width, servo_length, servo_height], center = true);
    
    // Stem coupler
    color("Orange", 0.9)
        translate([0, 0, outer_radius + explode/2 - 5])
            valve_stem_coupler();
    
    // Electronics bay (shown offset for visibility)
    color("Green", 0.5)
        translate([outer_radius + 10, 0, -explode/2 - 5])
            rotate([0, 0, 0])
                electronics_bay();
    
    // Ghost valve body for reference
    %translate([0, 0, 0])
        cylinder(d = valve_body_diameter, h = valve_body_length, center = true, $fn = 6);
}

// ============================================================
// RENDER
// ============================================================

// Uncomment one of the following to render individual parts for printing:
// housing_bottom_half();
// housing_top_half();
// valve_stem_coupler();

// Full assembly view (default)
assembly();
