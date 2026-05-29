// ============================================================
// Central Control Unit (CU) – Wall-Mount Enclosure
// Gas Safety System – OpenSCAD Parametric Design
// ============================================================
// Wall-mounted box housing ESP32, SIM800L, relay, LCD 16x2,
// buzzer, LEDs, and control buttons.
// Two-part: base (wall-mount) + lid (front panel with cutouts).
// ============================================================

/* [Enclosure Dimensions] */
box_width        = 140;   // mm – X (horizontal)
box_height       = 100;   // mm – Y (vertical on wall)
box_depth        = 45;    // mm – Z (protrusion from wall)
wall_thickness   = 2.5;   // mm
corner_radius    = 3.0;   // mm – rounded corners

/* [LCD 16x2 Display] */
lcd_window_w     = 72;    // mm – visible area width
lcd_window_h     = 25;    // mm – visible area height
lcd_pcb_w        = 80;    // mm – PCB width
lcd_pcb_h        = 36;    // mm – PCB height
lcd_mount_holes  = [[3, 3], [77, 3], [3, 33], [77, 33]]; // relative to PCB corner
lcd_mount_hole_d = 2.8;   // M2.5 clearance
lcd_offset_x     = 10;    // mm from left inner wall
lcd_offset_y     = 55;    // mm from bottom inner wall (upper portion)
lcd_standoff_h   = 4.0;

/* [LEDs] */
led_diameter     = 5.0;   // mm – 5mm LED
led_power_x      = 20;    // mm from left edge (front panel)
led_power_y      = 45;    // mm from bottom edge
led_alarm_x      = 40;    // mm from left edge
led_alarm_y      = 45;    // mm from bottom edge

/* [Buttons] */
button_diameter  = 12.0;  // mm – momentary push button
button_reset_x   = 70;    // mm from left edge
button_reset_y   = 25;    // mm from bottom edge
button_test_x    = 100;   // mm from left edge
button_test_y    = 25;    // mm from bottom edge

/* [Buzzer] */
buzzer_diameter  = 25;    // mm – piezo buzzer
buzzer_x         = 110;   // mm from left edge (front panel center)
buzzer_y         = 70;    // mm from bottom edge
buzzer_grille_holes = 8;  // number of holes in grille pattern
buzzer_hole_d    = 2.5;   // mm each grille hole

/* [Internal Components] */
// ESP32 DevKit V1 (narrow)
esp32_w          = 51;
esp32_h          = 25;
esp32_standoff_h = 6;
esp32_pos        = [10, 10]; // XY position inside base

// SIM800L module
sim800l_w        = 25;
sim800l_h        = 23;
sim800l_standoff_h = 6;
sim800l_pos      = [70, 10];

// Relay module (single channel)
relay_w          = 35;
relay_h          = 25;
relay_standoff_h = 6;
relay_pos        = [70, 45];

/* [Mounting & Access] */
standoff_outer_d = 5.0;
standoff_hole_d  = 2.5;   // M2.5
wall_mount_slot_w = 5.0;  // keyhole slot width
wall_mount_slot_h = 10.0; // keyhole slot height
wall_mount_hole_d = 4.5;  // screw head passes through
wall_mount_spacing = 80;  // mm between mount points

// Power input hole
power_hole_d     = 8.0;   // DC barrel jack or cable gland
power_hole_pos   = [box_width - 15, box_depth / 2]; // on bottom face

// SMA antenna hole for SIM800L
antenna_hole_d   = 6.5;   // SMA connector
antenna_hole_pos = [box_width - 15, box_height - 15]; // top-right of back

/* [Lid Fastening] */
screw_boss_d     = 8.0;
screw_hole_d     = 2.5;   // M2.5 self-tap
screw_boss_h     = box_depth - wall_thickness * 2 - 1;
// Screw positions (4 corners, inset)
screw_inset      = 8;

/* [Rendering] */
$fn = 48;
explode = 20; // mm – set to 0 for assembled view

// ============================================================
// MODULES
// ============================================================

module rounded_box(w, h, d, r) {
    // Rounded-corner box using hull of spheres at corners
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
    // Keyhole for wall mounting
    hull() {
        circle(d = w);
        translate([0, h - w, 0])
            circle(d = w);
    }
    // Wider bottom for screw head entry
    translate([0, -h/2 + w/2, 0])
        circle(d = hole_d);
}

module buzzer_grille(center_x, center_y, count, hole_d, radius) {
    // Circular pattern of holes
    translate([center_x, center_y, 0]) {
        cylinder(d = hole_d, h = wall_thickness + 1, center = true);
        for (i = [0:count-1]) {
            angle = i * 360 / count;
            translate([radius * cos(angle), radius * sin(angle), 0])
                cylinder(d = hole_d, h = wall_thickness + 1, center = true);
        }
        // Second ring
        for (i = [0:count-1]) {
            angle = i * 360 / count + 360 / count / 2;
            translate([radius * 1.7 * cos(angle), radius * 1.7 * sin(angle), 0])
                cylinder(d = hole_d, h = wall_thickness + 1, center = true);
        }
    }
}

// ============================================================
// BASE (mounts to wall, holds electronics)
// ============================================================

module cu_base() {
    difference() {
        // Outer shell
        rounded_box(box_width, box_height, box_depth, corner_radius);
        
        // Hollow interior
        translate([wall_thickness, wall_thickness, wall_thickness])
            rounded_box(box_width - wall_thickness*2, 
                       box_height - wall_thickness*2, 
                       box_depth + 10, // open top (lid side)
                       corner_radius - 0.5);
        
        // Cut off the front face (lid goes here)
        translate([-1, -1, box_depth - wall_thickness])
            cube([box_width + 2, box_height + 2, wall_thickness + 2]);
        
        // Wall mount keyhole slots (on back face)
        for (dx = [-wall_mount_spacing/2, wall_mount_spacing/2])
            translate([box_width/2 + dx, box_height/2, wall_thickness/2])
                rotate([0, 0, 0])
                    linear_extrude(height = wall_thickness + 1, center = true)
                        keyhole_slot(wall_mount_slot_w, wall_mount_slot_h, wall_mount_hole_d);
        
        // Power input hole (bottom face)
        translate([power_hole_pos[0], 0, power_hole_pos[1]])
            rotate([-90, 0, 0])
                cylinder(d = power_hole_d, h = wall_thickness + 1, center = true);
        
        // SMA antenna hole (back panel, near top)
        translate([antenna_hole_pos[0], antenna_hole_pos[1], wall_thickness/2])
            cylinder(d = antenna_hole_d, h = wall_thickness + 1, center = true);
    }
    
    // Internal screw bosses for lid attachment (4 corners)
    for (x = [screw_inset, box_width - screw_inset])
        for (y = [screw_inset, box_height - screw_inset])
            translate([x, y, wall_thickness])
                standoff(screw_boss_h, screw_boss_d, screw_hole_d);
    
    // ESP32 standoffs
    translate([wall_thickness + esp32_pos[0], wall_thickness + esp32_pos[1], wall_thickness]) {
        for (dx = [3, esp32_w - 3])
            for (dy = [3, esp32_h - 3])
                translate([dx, dy, 0])
                    standoff(esp32_standoff_h, standoff_outer_d, standoff_hole_d);
    }
    
    // SIM800L standoffs
    translate([wall_thickness + sim800l_pos[0], wall_thickness + sim800l_pos[1], wall_thickness]) {
        for (dx = [3, sim800l_w - 3])
            for (dy = [3, sim800l_h - 3])
                translate([dx, dy, 0])
                    standoff(sim800l_standoff_h, standoff_outer_d, standoff_hole_d);
    }
    
    // Relay standoffs
    translate([wall_thickness + relay_pos[0], wall_thickness + relay_pos[1], wall_thickness]) {
        for (dx = [3, relay_w - 3])
            for (dy = [3, relay_h - 3])
                translate([dx, dy, 0])
                    standoff(relay_standoff_h, standoff_outer_d, standoff_hole_d);
    }
}

// ============================================================
// LID (front panel with display, LEDs, buttons, buzzer)
// ============================================================

module cu_lid() {
    lid_thickness = wall_thickness;
    
    difference() {
        // Lid plate
        translate([0, 0, 0])
            rounded_box(box_width, box_height, lid_thickness, corner_radius);
        
        // LCD window cutout
        translate([lcd_offset_x, lcd_offset_y, -0.1])
            cube([lcd_window_w, lcd_window_h, lid_thickness + 1]);
        
        // LED holes
        translate([led_power_x, led_power_y, -0.1])
            cylinder(d = led_diameter, h = lid_thickness + 1);
        translate([led_alarm_x, led_alarm_y, -0.1])
            cylinder(d = led_diameter, h = lid_thickness + 1);
        
        // Button holes
        translate([button_reset_x, button_reset_y, -0.1])
            cylinder(d = button_diameter, h = lid_thickness + 1);
        translate([button_test_x, button_test_y, -0.1])
            cylinder(d = button_diameter, h = lid_thickness + 1);
        
        // Buzzer grille
        translate([0, 0, lid_thickness / 2])
            buzzer_grille(buzzer_x, buzzer_y, buzzer_grille_holes, buzzer_hole_d, buzzer_diameter / 4);
        
        // Screw holes (matching base bosses)
        for (x = [screw_inset, box_width - screw_inset])
            for (y = [screw_inset, box_height - screw_inset])
                translate([x, y, -0.1])
                    cylinder(d = screw_hole_d, h = lid_thickness + 1);
    }
    
    // LCD mounting standoffs (on inner face of lid)
    translate([lcd_offset_x, lcd_offset_y - 5, lid_thickness]) {
        for (pos = lcd_mount_holes)
            translate([pos[0], pos[1], 0])
                standoff(lcd_standoff_h, standoff_outer_d, lcd_mount_hole_d);
    }
    
    // Inner lip/rim for alignment
    translate([wall_thickness + 0.5, wall_thickness + 0.5, lid_thickness])
        difference() {
            cube([box_width - wall_thickness*2 - 1, box_height - wall_thickness*2 - 1, 2]);
            translate([1.5, 1.5, -0.1])
                cube([box_width - wall_thickness*2 - 4, box_height - wall_thickness*2 - 4, 2.2]);
        }
}

// ============================================================
// LABELS (embossed text on front panel)
// ============================================================

module front_labels() {
    font_size = 4;
    label_depth = 0.5;
    
    // LED labels
    translate([led_power_x, led_power_y - 8, wall_thickness - label_depth])
        linear_extrude(height = label_depth + 0.1)
            text("PWR", size = font_size, halign = "center", font = "Liberation Sans:style=Bold");
    
    translate([led_alarm_x, led_alarm_y - 8, wall_thickness - label_depth])
        linear_extrude(height = label_depth + 0.1)
            text("ALM", size = font_size, halign = "center", font = "Liberation Sans:style=Bold");
    
    // Button labels
    translate([button_reset_x, button_reset_y - 10, wall_thickness - label_depth])
        linear_extrude(height = label_depth + 0.1)
            text("RESET", size = font_size, halign = "center", font = "Liberation Sans:style=Bold");
    
    translate([button_test_x, button_test_y - 10, wall_thickness - label_depth])
        linear_extrude(height = label_depth + 0.1)
            text("TEST", size = font_size, halign = "center", font = "Liberation Sans:style=Bold");
}

// ============================================================
// ASSEMBLY VIEW
// ============================================================

module assembly() {
    // Base (wall side)
    color("WhiteSmoke", 0.85)
        cu_base();
    
    // Lid (front panel) – exploded forward
    color("LightSteelBlue", 0.9)
        translate([0, 0, box_depth - wall_thickness + explode])
            cu_lid();
    
    // Labels on lid
    color("DarkSlateGray")
        translate([0, 0, box_depth - wall_thickness + explode])
            front_labels();
    
    // Ghost components for reference
    // ESP32
    %translate([wall_thickness + esp32_pos[0], wall_thickness + esp32_pos[1], 
                wall_thickness + esp32_standoff_h])
        cube([esp32_w, esp32_h, 10]);
    
    // SIM800L
    %translate([wall_thickness + sim800l_pos[0], wall_thickness + sim800l_pos[1],
                wall_thickness + sim800l_standoff_h])
        cube([sim800l_w, sim800l_h, 8]);
    
    // Relay
    %translate([wall_thickness + relay_pos[0], wall_thickness + relay_pos[1],
                wall_thickness + relay_standoff_h])
        cube([relay_w, relay_h, 15]);
}

// ============================================================
// RENDER
// ============================================================

// Uncomment one to render individual parts for printing:
// cu_base();
// cu_lid();

// Full assembly (default)
assembly();
