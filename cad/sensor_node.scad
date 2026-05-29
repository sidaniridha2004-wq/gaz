// ============================================================
// Wireless Gas Sensor Node – Wall-Mount Enclosure
// Gas Safety System – OpenSCAD Parametric Design
// ============================================================
// Compact wall-mounted box housing ESP32, MQ-2, MQ-7 gas sensors,
// LiPo battery, and TP4056 charger. Front grille for gas sensors,
// RGB LED window, side USB port for charging.
// Two-part: base (wall-mount, rear shelf for ESP32+battery) +
// front cover (grille, LED window).
// ============================================================

/* [Enclosure Dimensions] */
box_width        = 80;    // mm – X (horizontal)
box_height       = 65;    // mm – Y (vertical on wall)
box_depth        = 32;    // mm – Z (protrusion from wall)
wall_thickness   = 2.0;   // mm
corner_radius    = 2.5;   // mm

/* [Gas Sensor Grille] */
grille_width     = 50;    // mm – perforated area
grille_height    = 30;    // mm
grille_offset_x  = 15;    // mm from left edge of front face
grille_offset_y  = 28;    // mm from bottom edge (upper portion)
grille_slot_w    = 2.0;   // mm – slot width
grille_slot_h    = 12.0;  // mm – slot length (vertical)
grille_slot_gap  = 3.5;   // mm – horizontal spacing between slots
grille_row_gap   = 4.0;   // mm – vertical spacing between rows

/* [RGB LED Window] */
led_window_w     = 8;     // mm
led_window_h     = 4;     // mm
led_window_x     = 36;    // mm from left (centered roughly)
led_window_y     = 18;    // mm from bottom edge (below grille)
led_diffuser_depth = 1.0; // mm – recess for translucent insert

/* [USB Port Access (side)] */
usb_port_w       = 12;    // mm – micro-USB or USB-C opening
usb_port_h       = 7;     // mm
usb_port_x       = 15;    // mm from bottom of side face
usb_port_z       = 8;     // mm from back (wall side)

/* [Gas Sensors – MQ-2 & MQ-7] */
// Both sensors are cylindrical with pin header base
mq_sensor_d      = 18;    // mm – sensor cylinder diameter
mq_sensor_h      = 15;    // mm – sensor height
mq_pcb_w         = 32;    // mm – breakout board width
mq_pcb_h         = 20;    // mm – breakout board height
mq2_pos          = [12, 35]; // XY on front shelf (relative to inner)
mq7_pos          = [46, 35]; // XY on front shelf

/* [ESP32 Module] */
// ESP32 DevKit Mini or similar compact module
esp32_w          = 48;    // mm
esp32_h          = 25;    // mm
esp32_pos        = [14, 5]; // XY on rear shelf

/* [LiPo Battery] */
lipo_w           = 40;    // mm
lipo_h           = 30;    // mm
lipo_thickness   = 6;     // mm (flat pouch cell)
lipo_pos         = [5, 30]; // XY on rear shelf

/* [TP4056 Charger Module] */
tp4056_w         = 25;    // mm
tp4056_h         = 18;    // mm
tp4056_pos       = [50, 30]; // XY on rear shelf (USB faces side wall)

/* [Internal Shelf] */
shelf_thickness  = 2.0;   // mm – divider between front/rear compartments
shelf_z_position = 18;    // mm from back wall – where shelf sits

/* [Mounting] */
standoff_outer_d = 4.5;
standoff_hole_d  = 2.2;   // M2
standoff_h_front = 4.0;   // sensor board standoffs
standoff_h_rear  = 5.0;   // ESP32/charger standoffs

// Wall mount – hidden screw slots on back
wall_mount_slot_w = 4.5;
wall_mount_slot_h = 8.0;
wall_mount_hole_d = 4.0;
wall_mount_spacing = 50;  // mm between mount points

/* [Lid Fastening] */
snap_tab_w       = 8;     // mm – snap-fit tab width
snap_tab_h       = 2;     // mm – tab protrusion
snap_tab_count   = 2;     // tabs per side (top and bottom)
screw_hole_d     = 2.2;   // M2 self-tap
screw_boss_d     = 5.5;
screw_positions  = [[6, 6], [box_width - 6, 6], [6, box_height - 6], [box_width - 6, box_height - 6]];

/* [Rendering] */
$fn = 48;
explode = 15; // mm – set to 0 for assembled view

// ============================================================
// MODULES
// ============================================================

module rounded_box(w, h, d, r) {
    hull() {
        for (x = [r, w - r])
            for (y = [r, h - r])
                for (z = [r, d - r])
                    translate([x, y, z])
                        sphere(r = r);
    }
}

module standoff(h, d_outer, d_hole) {
    difference() {
        cylinder(d = d_outer, h = h);
        translate([0, 0, -0.1])
            cylinder(d = d_hole, h = h + 0.2);
    }
}

module keyhole_slot(w, h, hole_d) {
    hull() {
        circle(d = w);
        translate([0, h - w, 0])
            circle(d = w);
    }
    translate([0, -h/2 + w/2, 0])
        circle(d = hole_d);
}

module grille_pattern(width, height, slot_w, slot_h, gap_x, gap_y) {
    cols = floor(width / (slot_w + gap_x));
    rows = floor(height / (slot_h + gap_y));
    
    for (c = [0:cols-1])
        for (r = [0:rows-1]) {
            // Offset every other row for better airflow
            x_offset = (r % 2 == 0) ? 0 : (slot_w + gap_x) / 2;
            translate([c * (slot_w + gap_x) + x_offset, r * (slot_h + gap_y), 0])
                // Rounded-end slots
                hull() {
                    translate([slot_w/2, slot_w/2, 0])
                        cylinder(d = slot_w, h = wall_thickness + 1, center = true);
                    translate([slot_w/2, slot_h - slot_w/2, 0])
                        cylinder(d = slot_w, h = wall_thickness + 1, center = true);
                }
        }
}

// ============================================================
// BASE (mounts to wall, holds ESP32 + battery + charger)
// ============================================================

module sensor_base() {
    difference() {
        // Outer shell
        rounded_box(box_width, box_height, box_depth, corner_radius);
        
        // Hollow interior
        translate([wall_thickness, wall_thickness, wall_thickness])
            rounded_box(box_width - wall_thickness*2,
                       box_height - wall_thickness*2,
                       box_depth + 5, // open front
                       max(0.5, corner_radius - 1));
        
        // Open front face (lid goes here)
        translate([-1, -1, box_depth - wall_thickness])
            cube([box_width + 2, box_height + 2, wall_thickness + 2]);
        
        // Wall mount keyhole slots (back face)
        for (dx = [-wall_mount_spacing/2, wall_mount_spacing/2])
            translate([box_width/2 + dx, box_height/2, wall_thickness/2])
                linear_extrude(height = wall_thickness + 1, center = true)
                    keyhole_slot(wall_mount_slot_w, wall_mount_slot_h, wall_mount_hole_d);
        
        // USB port cutout (right side wall)
        translate([box_width - wall_thickness/2, usb_port_x, usb_port_z])
            cube([wall_thickness + 1, usb_port_h, usb_port_w], center = true);
    }
    
    // Internal divider shelf (separates front sensor compartment from rear electronics)
    translate([wall_thickness, wall_thickness, shelf_z_position])
        difference() {
            cube([box_width - wall_thickness*2, box_height - wall_thickness*2, shelf_thickness]);
            
            // Wire routing holes through shelf
            translate([(box_width - wall_thickness*2)/4, (box_height - wall_thickness*2)/2, -0.1])
                cylinder(d = 8, h = shelf_thickness + 0.2);
            translate([3*(box_width - wall_thickness*2)/4, (box_height - wall_thickness*2)/2, -0.1])
                cylinder(d = 8, h = shelf_thickness + 0.2);
        }
    
    // Rear shelf standoffs for ESP32
    translate([wall_thickness + esp32_pos[0], wall_thickness + esp32_pos[1], wall_thickness]) {
        for (dx = [3, esp32_w - 3])
            for (dy = [3, esp32_h - 3])
                translate([dx, dy, 0])
                    standoff(standoff_h_rear, standoff_outer_d, standoff_hole_d);
    }
    
    // Rear shelf standoffs for TP4056
    translate([wall_thickness + tp4056_pos[0], wall_thickness + tp4056_pos[1], wall_thickness]) {
        for (dx = [3, tp4056_w - 3])
            for (dy = [3, tp4056_h - 3])
                translate([dx, dy, 0])
                    standoff(standoff_h_rear, standoff_outer_d, standoff_hole_d);
    }
    
    // Battery retainer posts (corners of LiPo)
    translate([wall_thickness + lipo_pos[0], wall_thickness + lipo_pos[1], wall_thickness]) {
        for (dx = [0, lipo_w])
            for (dy = [0, lipo_h])
                translate([dx, dy, 0])
                    cylinder(d = 3, h = lipo_thickness + 2);
    }
    
    // Front shelf standoffs for gas sensors (on top of divider)
    translate([wall_thickness, wall_thickness, shelf_z_position + shelf_thickness]) {
        // MQ-2 board standoffs
        translate([mq2_pos[0], mq2_pos[1] - mq_pcb_h/2, 0]) {
            for (dx = [3, mq_pcb_w - 3])
                for (dy = [3, mq_pcb_h - 3])
                    translate([dx, dy, 0])
                        standoff(standoff_h_front, standoff_outer_d, standoff_hole_d);
        }
        // MQ-7 board standoffs
        translate([mq7_pos[0], mq7_pos[1] - mq_pcb_h/2, 0]) {
            for (dx = [3, mq_pcb_w - 3])
                for (dy = [3, mq_pcb_h - 3])
                    translate([dx, dy, 0])
                        standoff(standoff_h_front, standoff_outer_d, standoff_hole_d);
        }
    }
    
    // Screw bosses for front lid (4 corners)
    for (pos = screw_positions)
        translate([pos[0], pos[1], wall_thickness])
            standoff(box_depth - wall_thickness*2 - 1, screw_boss_d, screw_hole_d);
}

// ============================================================
// FRONT COVER / LID (grille, LED window)
// ============================================================

module sensor_lid() {
    lid_thickness = wall_thickness;
    
    difference() {
        // Lid plate
        rounded_box(box_width, box_height, lid_thickness, corner_radius);
        
        // Gas sensor grille
        translate([grille_offset_x, grille_offset_y, lid_thickness/2])
            grille_pattern(grille_width, grille_height, 
                          grille_slot_w, grille_slot_h,
                          grille_slot_gap, grille_row_gap);
        
        // RGB LED window (rectangular cutout with diffuser recess)
        translate([led_window_x, led_window_y, -0.1])
            cube([led_window_w, led_window_h, lid_thickness + 0.2]);
        // Diffuser recess (slightly larger, on inner face)
        translate([led_window_x - 1, led_window_y - 1, -0.1])
            cube([led_window_w + 2, led_window_h + 2, led_diffuser_depth]);
        
        // Screw holes (4 corners)
        for (pos = screw_positions)
            translate([pos[0], pos[1], -0.1])
                cylinder(d = screw_hole_d, h = lid_thickness + 0.2);
    }
    
    // Inner alignment rim
    translate([wall_thickness + 0.3, wall_thickness + 0.3, lid_thickness])
        difference() {
            cube([box_width - wall_thickness*2 - 0.6, 
                  box_height - wall_thickness*2 - 0.6, 1.5]);
            translate([1.5, 1.5, -0.1])
                cube([box_width - wall_thickness*2 - 3.6,
                      box_height - wall_thickness*2 - 3.6, 1.7]);
        }
}

// ============================================================
// ASSEMBLY VIEW
// ============================================================

module assembly() {
    // Base (wall side)
    color("White", 0.85)
        sensor_base();
    
    // Front lid – exploded forward
    color("WhiteSmoke", 0.9)
        translate([0, 0, box_depth - wall_thickness + explode])
            sensor_lid();
    
    // Ghost components for reference
    // ESP32
    %translate([wall_thickness + esp32_pos[0], wall_thickness + esp32_pos[1],
                wall_thickness + standoff_h_rear])
        cube([esp32_w, esp32_h, 8]);
    
    // LiPo battery
    %translate([wall_thickness + lipo_pos[0], wall_thickness + lipo_pos[1],
                wall_thickness + 1])
        color("Blue", 0.3)
            cube([lipo_w, lipo_h, lipo_thickness]);
    
    // TP4056
    %translate([wall_thickness + tp4056_pos[0], wall_thickness + tp4056_pos[1],
                wall_thickness + standoff_h_rear])
        cube([tp4056_w, tp4056_h, 5]);
    
    // MQ-2 sensor (cylinder on PCB)
    %translate([wall_thickness + mq2_pos[0] + mq_pcb_w/2, 
                wall_thickness + mq2_pos[1],
                shelf_z_position + shelf_thickness + standoff_h_front + 2])
        cylinder(d = mq_sensor_d, h = mq_sensor_h);
    
    // MQ-7 sensor
    %translate([wall_thickness + mq7_pos[0] + mq_pcb_w/2,
                wall_thickness + mq7_pos[1],
                shelf_z_position + shelf_thickness + standoff_h_front + 2])
        cylinder(d = mq_sensor_d, h = mq_sensor_h);
}

// ============================================================
// RENDER
// ============================================================

// Uncomment one to render individual parts for printing:
// sensor_base();
// sensor_lid();

// Full assembly (default)
assembly();
