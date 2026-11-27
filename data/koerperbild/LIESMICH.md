# Koerperbild: Skelette der Uebungsvideos

`skelette/<key>.skelett.json` sind die mit Apples Vision (`VNDetectHumanBodyPoseRequest`)
erkannten Koerper-Skelette je Bild der Uebungsvideos aus `catalog/media/videos`
(ein `Skelettfolge`-Objekt: Bildrate, Seitenverhaeltnis, je Bild Gelenk -> [x, y, Sicherheit];
x/y 0...1 von oben links, vier Nachkommastellen). Sie sind Testdaten fuer den Bericht zur
Koerpererkennung (`SkelettDateienTests` liest sie).

Die Videos zeigen keine echten Personen (KI-erzeugte Uebungsvideos), die Dateien enthalten
nur Gelenkpunkte, keine Bilder.

## Erzeugen

Aus `apps/ios-member/Packages/Koerperbild`:

    swift run -c release skelette-rechnen ../../../../catalog/media/videos ../../../../data/koerperbild/skelette

Je Video eine Zeile `<key> <Bilder> <Anteil erkannt %>`.

## Letzter Lauf

- Datum: 24.11.2026
- macOS 26.7.1 (Build 25G241), Apple Silicon, Vision-Standardeinstellung
- 201 Videos, 201 Dateien, 7,6 MB
- Mittlerer Anteil erkannter Bilder: 92,6 % (je Video gemittelt)
- Ohne Erkennung (0 %): zehn Cardio-Geraete-Videos (`cardio_*`), `db_farmers_walk`,
  `row_machine_single`; fast nichts erkannt: `bb_reverse_grip_bench` (2,5 %),
  `cable_decline_fly` (30,2 %)

## Nachtrag 27.11.2026

- 16 Videos der Koerpergewichtsuebungen fuer den HIIT-Flow nachgerechnet (`bw_*`, die noch
  keine Datei hatten), gleiche Einstellung, macOS 26.7.1 (Build 25G241). `bw_pushup` dabei zur
  Kontrolle neu gerechnet: Datei byte-gleich mit der vorhandenen.
- Anteil erkannter Bilder: `bw_leg_drop_pull` 36,5 %, `bw_crunch_hold` 82,7 %, die uebrigen 100 %.
- `FlowZaehlerAbspielTests` zaehlt damit die Kamera-Schritte des Flows nach
  (Bericht: `docs/flows/hiit-20-min-kamera-bericht.md`).
