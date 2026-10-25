// Gehäuse für Heltec WiFi LoRa 32 V3 (Garagen-Node)
//
// Teile:  part = "base" | "lid" | "template" | "assembly"
//   base      Wanne mit USB-C-Öffnung, SMA-Bohrung für die externe Antenne, Rastnuten
//   lid       Deckel mit Displayfenster und Button-Löchern; Klick-Verschluss ohne Schrauben,
//             werkzeuglos zu öffnen (Griffzunge an einer Längsseite nach oben ziehen)
//   template  dünne Prüfplatte: auf die echte Platine legen, bevor Base/Lid gedruckt werden
//   assembly  Vorschau, Deckel aufgesetzt, Viertel aufgeschnitten
//
// Render:  openscad -o base.stl -D 'part="base"' heltec_v3_case.scad
//
// Maße aus dem Heltec-Datenblatt HTIT-WB32LA_V3.2 (Kap. 4 "Physical dimensions") und dem V3.2-Pinmap:
// Platine 50,2 x 25,5, Dicke gesamt 10,2 (Display 5,0 über der Platine, Rückseite 3,6). Display, Buttons, USB-C
// und IPEX liegen alle auf der Vorderseite. Positionen aus der Zeichnung abgelesen (Genauigkeit ca. 0,3 mm):
// vor dem Druck mit part="template" gegenlegen. Alle Positionen in mm von der linken unteren Platinenecke
// (Blick auf die Vorderseite, USB-C-Ende links, y nach oben).

part = "assembly";
explode = 0;      // assembly: Deckel um dieses Maß abheben (z. B. 8)
cut  = false;     // assembly: Viertelschnitt zeigen

$fn = 48;
eps = 0.01;

// ---- Platine -------------------------------------------------------------------------------
L        = 50.2;   // Länge (Datenblatt)
W        = 25.5;   // Breite (Datenblatt)
pcb_t    = 1.6;    // Platinendicke
under    = 4.0;    // Platz unter der Platine: Bauteile Rückseite 3,6 mm (ohne Stiftleisten)
disp_h   = 5.0;    // Display-Oberkante über der Platinenoberseite (Datenblatt: 10,2 - 3,6 - 1,6)
disp_gap = 0.3;    // Luft zwischen Displayglas und Deckelunterseite (Deckel schließt dicht über dem Display ab)
above    = disp_h + disp_gap;

// ---- Öffnungen -------------------------------------------------------------------------------
// USB-C an der linken Schmalseite, Mitte (Stecker ragt ~0,9 mm über die Platine hinaus). Cutout größer als der
// Stecker (Knickschutz).
usb_y     = W/2;       // 12,7 laut Zeichnung
usb_z     = 1.6;       // Mitte des Steckers über Platinenoberseite (Buchse ~3,2 hoch)
usb_cut_w = 13;
usb_cut_h = 8;

// Display (aus dem Foto, USB-C links): aktive Fläche ~22,5 x 12,5, Mitte 31,0 mm vom USB-C-Ende, 2,0 mm zur PRG-Seite
// (y hoch) aus der Mitte verschoben, also rechts von der Platinenmitte (25,1) und nicht mittig quer.
oled_x = 31.0;   oled_y = 14.75;
oled_w = 24.5;   oled_h = 14.0;      // Fenster = aktive Fläche + je 1 mm
win_bevel = 0.8;                     // Fase an der Außenseite

// Buttons PRG (oben, y hoch) und RST (unten) links neben dem USB-C. Positionen aus dem Foto, Mitte des Tasters.
btn_prg = [3.7, 20.8];
btn_rst = [3.5, 5.4];
btn_d   = 4.0;            // nur für die Prüfplatte
// Federnde Taste im Deckel (wie bei den Thingiverse-Vorlagen): Scheibe an einem dünnen Arm, Nippel drückt den Taster.
btn_disc    = 5.0;        // Scheibe
btn_slot    = 0.6;        // Schlitz um die Scheibe und neben dem Arm
btn_arm_w   = 4.0;
btn_arm_len = 9.0;        // Arm nach rechts (+x)
btn_thin    = 1.2;        // Dicke von Arm und Scheibe (Deckel sonst lid_t)
btn_nub_d   = 2.4;
sw_top      = 2.2;        // Oberkante der Taster über der Platine (MESSEN)
nub_gap     = 0.3;        // Luft zwischen Nippel und Taster

// Externe Antenne: IPEX sitzt am rechten Ende (x ~ 49,1, Mitte); SMA-Einbaubuchse (Gewinde 6,35 mm)
// in der rechten Schmalseite. Rechts der Platine liegt ein Hohlraum für die SMA-Mutter und den Pigtail-Bogen.
sma_d    = 6.6;
sma_y    = W/2;
sma_z    = 3.0;
ant_zone = 18;            // Hohlraum rechts der Platine (Kabelbogen)
ant_cut_w = 16;           // Lippenausschnitt am Antennenende

// ---- Gehäuse ---------------------------------------------------------------------------------
wall    = 2.4;
floor_t = 2.0;
lid_t   = 2.0;
clear   = 0.4;             // Luft um die Platine

// ---- Klick-Verschluss ----------------------------------------------------------------------------
lip_t   = 1.0;             // Wandstärke der Deckellippe (PETG: nicht dünner)
lip_h   = 4.5;             // Lippenhöhe; Unterkante bleibt ~0,8 mm über der Platine
lip_gap = 0.2;             // Spiel Lippe <-> Wannenwand
snap    = 0.4;             // Rasthöhe der Nase
tab_len = 16;              // Länge des Schnapparms (mittig auf beiden Längsseiten)
slit    = 1.0;             // Schlitz links/rechts vom Schnapparm
pull_w  = 14;  pull_x = 20;  // Griffzunge: Breite, Versatz aus der Mitte (an der +y-Längsseite)
pull_out = 4;

// ---- Auflage und Anschlag ------------------------------------------------------------------------
rail_w   = 1.5;            // Auflageleiste unter den Längskanten der Platine
stop_w   = 8.5;            // Anschlag: Breite ab Wand/Platinenkante; in der Mitte bleiben W - 2*stop_w frei
stop_l   = 3.0;
stop_gap = 0.1;            // Spiel Platinenende <-> Anschlag
stop_h   = under + pcb_t + 0.6;   // 0,6 mm über der Platinenoberseite; bleibt unter der Deckellippe (Unterkante 0,8 mm über der Platine)

// abgeleitet
inner_h = under + pcb_t + above;
in_l    = L + 2*clear + ant_zone;
in_w    = W + 2*clear;
out_l   = in_l + 2*wall;
out_w   = in_w + 2*wall;
out_h   = floor_t + inner_h;
// Platinen-Ursprung in Gehäusekoordinaten (linke untere Platinenecke)
bx = wall + clear;
by = wall + clear;
bz = floor_t + under;                              // Unterseite der Platine
ztop = bz + pcb_t;                                 // Oberseite der Platine
groove_z = out_h - lip_h;                          // Höhe der Rastnut (Lippenunterkante)

module rrect(l, w, r) {
  translate([r, r]) offset(r) square([l-2*r, w-2*r]);
}

// Öffnungen in den Schmalseiten, auch durch die Lippe geführt (Stecker und SMA-Mutter brauchen Platz)
module end_cuts() {
  translate([-eps, by + usb_y - usb_cut_w/2, ztop + usb_z - usb_cut_h/2])
    cube([wall + clear + lip_t + lip_gap + 2, usb_cut_w, usb_cut_h]);
  translate([out_l - wall - lip_t - lip_gap - 2, by + sma_y, ztop + sma_z]) rotate([0, 90, 0])
    cylinder(d = sma_d, h = wall + lip_t + lip_gap + 3);
}

module base() {
  tx0 = out_l/2 - tab_len/2;
  difference() {
    union() {
      difference() {
        linear_extrude(out_h) rrect(out_l, out_w, 3);
        translate([wall, wall, floor_t]) linear_extrude(inner_h + eps) rrect(in_l, in_w, 1.0);
      }
      // Auflageleisten unter beiden Längskanten der Platine (Randzone, auf der Rückseite frei von Bauteilen: prüfen)
      for (py = [0, W - rail_w])
        translate([bx, by + py, floor_t - eps]) cube([L, rail_w, under + eps]);
      // Anschlag am Antennenende: hält die Platine beim Einstecken des USB-Steckers; Mitte bleibt für den IPEX-Pigtail frei
      for (y0 = [wall, by + W - stop_w])
        translate([bx + L + stop_gap, y0, floor_t - eps])
          cube([stop_l, stop_w + clear, stop_h + eps]);
    }
    end_cuts();
    // Rastnuten innen an beiden Längswänden, etwas länger als der Schnapparm
    for (y = [wall - 0.5, out_w - wall - eps])
      translate([tx0 - 1, y, groove_z]) cube([tab_len + 2, 0.5 + eps, snap + 1.2]);
    // Fingermulde unter der Griffzunge (Längsseite +y)
    translate([out_l/2 + pull_x - pull_w/2 - 1, out_w - wall - 0.5, out_h - 3])
      cube([pull_w + 2, wall + 1, 3 + eps]);
  }
}

// Deckel in Montagelage: Platte oben auf der Wanne (z = out_h ... out_h + lid_t), Lippe nach unten.
module lid_body() {
  tx0 = out_l/2 - tab_len/2;
  ox = wall + lip_gap;                                  // Lippe außen
  difference() {
    union() {
      translate([0, 0, out_h]) linear_extrude(lid_t) rrect(out_l, out_w, 3);
      // Griffzunge an der +y-Seite
      translate([out_l/2 + pull_x - pull_w/2, out_w - 1, out_h]) cube([pull_w, pull_out + 1, lid_t]);
      // Lippe als Ring innerhalb der Wanne
      translate([ox, ox, out_h - lip_h]) linear_extrude(lip_h + eps)
        difference() {
          rrect(out_l - 2*ox, out_w - 2*ox, 1.5);
          translate([lip_t, lip_t]) rrect(out_l - 2*ox - 2*lip_t, out_w - 2*ox - 2*lip_t, 0.8);
        }
      // Rastnasen außen am Schnapparm (symmetrisches Profil, Auf- und Zuklicken leicht)
      for (side = [0, 1])
        translate([0, side == 0 ? 0 : out_w, 0]) mirror([0, side == 0 ? 0 : 1, 0])
          translate([tx0, ox, groove_z]) rotate([90, 0, 90]) linear_extrude(tab_len)
            polygon([[0.0, 0.0], [-snap, 0.5], [-snap, 1.0], [0.0, 1.5]]);
      // Andruckfinger: verlängern die Lippe an den Längsrändern bis auf die Platinenkante (freie Randzone)
      for (fx = [7, 46], y = [by - lip_gap, by + W - 1.2])
        translate([bx + fx, y, ztop + 0.2]) cube([3, 1.4, out_h - ztop - 0.2 + eps]);
    }
    // Lippe an den Tastern freistellen (Taster stehen nahe der linken Wand)
    for (b = [btn_rst, btn_prg])
      translate([ox - eps, by + b[1] - 3.5, out_h - lip_h - eps]) cube([lip_t + 3.5, 7, lip_h]);
    // Schlitze neben dem Schnapparm, damit er federt
    for (x = [tx0 - slit, tx0 + tab_len], y = [ox - eps, out_w - ox - lip_t - eps])
      translate([x, y, out_h - lip_h - eps]) cube([slit, lip_t + 2*eps, lip_h + eps]);
    end_cuts();
    // Lippe am Antennenende freistellen (SMA-Mutter)
    translate([out_l - wall - lip_gap - lip_t - 0.5, by + sma_y - ant_cut_w/2, out_h - lip_h - 1])
      cube([lip_t + lip_gap + 0.6, ant_cut_w, lip_h + 1.5]);
    // Displayfenster, Button-Löcher
    // Fenster mit Fase außen (Blickwinkel)
    translate([bx + oled_x - oled_w/2, by + oled_y - oled_h/2, out_h - eps])
      cube([oled_w, oled_h, lid_t - win_bevel + eps]);
    hull() {
      translate([bx + oled_x - oled_w/2, by + oled_y - oled_h/2, out_h + lid_t - win_bevel - eps])
        cube([oled_w, oled_h, eps]);
      translate([bx + oled_x - oled_w/2 - win_bevel, by + oled_y - oled_h/2 - win_bevel, out_h + lid_t])
        cube([oled_w + 2*win_bevel, oled_h + 2*win_bevel, 1]);
    }
    // Federtasten: Schlitz um Scheibe und Arm durch den Deckel, Unterseite im Bereich von Scheibe und Arm auf btn_thin gedünnt
    for (b = [btn_rst, btn_prg]) {
      translate([bx + b[0], by + b[1], out_h - eps]) linear_extrude(lid_t + 2*eps) btn_slot2d();
      translate([bx + b[0] - btn_disc/2 - btn_slot - 0.3, by + b[1] - btn_arm_w/2 - btn_slot - 0.3, out_h - eps])
        cube([btn_disc + btn_slot + btn_arm_len + 0.6 + btn_disc/2, btn_arm_w + 2*btn_slot + 0.6, lid_t - btn_thin + eps]);
    }
  }
}

module btn_slot2d() {
  difference() {
    difference() { circle(d = btn_disc + 2*btn_slot); circle(d = btn_disc); }
    translate([0, -btn_arm_w/2]) square([btn_disc, btn_arm_w]);     // Öffnung zum Arm hin (+x)
  }
  for (sg = [-1, 1])
    translate([0, sg*(btn_arm_w/2 + btn_slot/2) - btn_slot/2]) square([btn_disc/2 + btn_arm_len, btn_slot]);
}

module lid_assembled() {
  lid_body();
  // Nippel unter den Tastenscheiben
  for (b = [btn_rst, btn_prg])
    translate([bx + b[0], by + b[1], ztop + sw_top + nub_gap])
      cylinder(d = btn_nub_d, h = (out_h + lid_t - btn_thin) - (ztop + sw_top + nub_gap) + eps);
}

// Deckel zum Drucken: Außenseite nach unten, Lippe zeigt nach oben
// Drehung um die x-Achse (kein Spiegeln!): so dreht man den gedruckten Deckel auch von Hand um.
module flip_lid() {
  translate([0, out_w, lid_t]) rotate([180, 0, 0]) translate([0, 0, -out_h]) children();
}
module lid() {
  flip_lid() lid_assembled();
}

// Prüfplatte: Umriss der Platine + alle Öffnungen, 1,2 mm dick, auf die Platine legen.
// Rechts schließt der Antennenhohlraum an: Platte reicht bis zur Innenwand, der Kreis markiert die SMA-Bohrung.
module template() {
  ant_end = L + clear + ant_zone;           // Innenseite der rechten Wand
  difference() {
    translate([-3, -3, 0]) cube([ant_end + 3 + 3, W + 6, 1.2]);
    translate([oled_x - oled_w/2, oled_y - oled_h/2, -eps]) cube([oled_w, oled_h, 2]);
    for (b = [btn_rst, btn_prg]) translate([b[0], b[1], -eps]) cylinder(d = btn_d, h = 2);
    // USB-C-Mitte als Markierung am linken Rand
    translate([-3 - eps, usb_y - 3, -eps]) cube([3 + 1, 6, 2]);
    // SMA-Bohrung in der rechten Wand (Mitte der Platte quer)
    translate([ant_end, sma_y, -eps]) cylinder(d = sma_d, h = 2);
    // Platinenende (x = L) als Kerbe oben und unten, damit man die Platine ausrichten kann
    for (y = [-3, W + 3 - 1.5]) translate([L, y, -eps]) cube([0.6, 1.5, 2]);
  }
}

// Prüfmodell der Platine mit Bauteilen (Maximalmaße) für die Kollisionsprüfung.
// chk wählt ein Bauteil: 0 alle, 1 Platine, 2 Display, 3 Taster, 4 USB-C, 5 IPEX
chk = 0;
module board_model() {
  if (chk == 0 || chk == 1) translate([bx, by, bz]) cube([L, W, pcb_t]);
  // Displaymodul (Glas inkl. Rahmen, großzügig) bis disp_h über der Platine
  if (chk == 0 || chk == 2) translate([bx + oled_x - 13.5, by + oled_y - 9.75, ztop]) cube([27, 19.5, disp_h]);
  // Taster
  if (chk == 0 || chk == 3) for (b = [btn_rst, btn_prg]) translate([bx + b[0] - 3, by + b[1] - 2, ztop]) cube([6, 4, sw_top]);
  // USB-C-Buchse, ragt 0,9 mm über die Platine hinaus
  if (chk == 0 || chk == 4) translate([bx - 0.9, by + usb_y - 4.5, ztop]) cube([9, 9, 3.2]);
  // IPEX-Buchse mit Stecker und Kabel Richtung Antennenhohlraum
  if (chk == 0 || chk == 5) translate([bx + L - 4, by + sma_y - 1.5, ztop]) cube([4, 3, 2]);
}

// Teilstücke zum Anprobieren der Details mit der echten Platine
slices = [[0, 26], [26, 47], [47, 1000]];
slice_id = 0;
module sliced(id) {
  intersection() {
    children();
    translate([slices[id][0], -10, -10]) cube([slices[id][1] - slices[id][0], out_w + 30, 60]);
  }
}

if (part == "base") base();
else if (part == "lid") lid();
else if (part == "template") template();
else if (part == "test_base") sliced(slice_id) base();
else if (part == "test_lid") flip_lid() sliced(slice_id) lid_assembled();
else if (part == "check_base") intersection() { board_model(); base(); }
else if (part == "check_lid") intersection() { board_model(); lid_assembled(); }
else if (part == "check_fit") intersection() { base(); lid_assembled(); }
else if (part == "check_flip") difference() { lid_assembled(); flip_lid() import("lid.stl"); }
else {
  difference() {
    union() {
      color("#4a5568") base();
      color("#a0aec0") translate([0, 0, explode]) lid_assembled();
      color("#1a8f3c") translate([bx, by, bz]) cube([L, W, pcb_t]);
      color("#222") translate([bx + oled_x - 11, by + oled_y - 5.6, ztop]) cube([22, 11.2, 3.5]);
    }
    if (cut) translate([out_l/2, -10, -1]) cube([out_l, out_w + 20, out_h + 30]);
  }
}
