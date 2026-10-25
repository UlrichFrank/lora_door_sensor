# Gehäuse Heltec WiFi LoRa 32 V3

`heltec_v3_case.scad` (OpenSCAD, parametrisch) mit vorgerenderten `base.stl`, `lid.stl`, `template.stl`.

## Maße der Platine (Quelle: Heltec-Datenblatt HTIT-WB32LA_V3.2, Kap. 4, und V3.2-Pinmap)

| Maß | Wert |
|---|---|
| Platine | 50,2 x 25,5 mm, Dicke 1,6 |
| Gesamtdicke | 10,2 mm: Display 5,0 über der Platine, Bauteile Rückseite 3,6 |
| Display | Glas 27,28 x 18,56 mm (Datenblatt); aktive Fläche ~22,5 x 12,5 mm, Mitte 31,0 mm vom USB-C-Ende (Platinenmitte: 25,1), 2,0 mm zur PRG-Seite aus der Quermitte (Foto) |
| Stiftleisten | keine angelötet (Löcher im Raster 2,54 mm) |
| USB-C | linke Schmalseite, Mitte (y = 12,7), ragt ~0,9 mm über die Platine hinaus |
| PRG / RST | links neben dem USB-C, ~3,6 mm vom USB-C-Ende; PRG bei y = 20,8, RST bei y = 5,4 (USB-C links, PRG oben; Foto) |
| IPEX (Antenne) | rechtes Ende, Mitte, ~1,1 mm vom Rand |

Alle Teile (Display, Buttons, USB-C, IPEX) liegen auf der Vorderseite. Die Positionen sind aus der Zeichnung und dem
Foto abgelesen (Genauigkeit ca. 0,3 mm; Oberkante der Taster `sw_top` = 2,2 ist geschätzt). Vor dem Druck `template.stl` ausdrucken (5 Minuten), auf die Platine legen und
bei Abweichungen die Parameter oben in der `.scad`-Datei ändern.

## Das Gehäuse

- **Display** sichtbar durch ein Fenster im Deckel (24,5 x 14 mm) über der aktiven Fläche, also rechts der Mitte. Zum Schutz Klarsichtfolie oder Acrylscheibe von innen aufkleben.
- **Buttons** PRG und RST als federnde Tasten im Deckel (wie bei den Thingiverse-Vorlagen): eine Scheibe an einem 1,2 mm dünnen Arm, ein Nippel darunter drückt den Taster. Einfach mit dem Finger drücken, kein Stift nötig.
- **USB-C** an der linken Schmalseite, Öffnung 13 x 8 mm für den Stecker samt Knickschutz.
- **Externe Antenne:** SMA-Einbaubuchse (Gewinde 6,35 mm) in der rechten Schmalseite; rechts der Platine ist ein 18 mm langer
  Hohlraum für die SMA-Mutter und den Bogen des IPEX-Pigtails.
- **Deckel nur geklickt, ohne Schrauben:** Eine Lippe im Deckel greift in die Wanne, zwei Schnapparme (je eine Längsseite) rasten
  in Nuten. Zum Öffnen die Griffzunge an der einen Längsseite mit dem Fingernagel nach oben ziehen, kein Werkzeug nötig.
- Keine Laschen oder Schraublöcher; zur Wandmontage doppelseitiges Klebeband oder Klett auf die Rückseite. Die Platine liegt auf vier Pads und wird oben von vier Fingern an den Längsrändern leicht niedergehalten.

Druck: Wanne mit der Öffnung nach oben, Deckel mit der Außenseite nach unten (so exportiert), PETG, 0,2 mm Layer. Die Schnapparme
sind 1 mm dick und 4,5 mm lang: PETG federt, PLA bricht leicht. Ist der Deckel zu fest oder zu lose, `snap` (Rasthöhe, 0,4) und
`lip_gap` (0,2) anpassen. Die Flexarme der Tasten (1,2 mm dick) halten in PETG; Pressen sie zu hart oder zu weich, `btn_thin` ändern. Nicht wasserdicht (kein Dichtring); für die
Garage innen gedacht.
