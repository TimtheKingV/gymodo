# QR/NFC: Designstand und Druck

Stand 6. Oktober 2026. Die finale Gestaltung liegt im GYMTAVO-Gesamtpaket
und ist unveraendert in `assets/branding/sticker/` abgelegt
(`GYMTAVO-NFC-QR-Tag-50x50mm-MUSTER.svg` ist die Vorlage, siehe README dort).

## Gestaltung

- Abgerundeter Aufkleber 50 x 50 mm, Eckenradius 4 mm.
- QR links mit G.-Logo in der Mitte, NFC-Symbol mit Schriftzug rechts,
  gruenes Hinweisband "Scannen oder Handy hier halten" unten.
- Der QR der Vorlage ist ein Muster ("GYMTAVO DESIGNMUSTER") und oeffnet nichts.

## Sticker je Charge erzeugen

    pnpm tags charge:sticker --code <charge> --basis <https://domain> [--ordner <pfad>]

Schreibt je Tag ein SVG und fuer die Charge eine PDF (eine Seite je Sticker,
50 x 50 mm). Der QR traegt exakt die URL, die `charge:csv` fuer denselben Tag
ausgibt; dieselbe URL kommt auf den NFC-Chip. Fehlerkorrektur H, Ruhezone
4 Module. Unter 0,4 mm Modulgroesse bricht der Befehl ab (bei
`https://gymtavo.de` sind es 0,54 mm, bei `https://gymodo-web.vercel.app`
0,50 mm). Verschrottete Chargen lehnt er ab.

Die Umsetzung (`packages/domain/src/sticker.ts`) ersetzt nur den Muster-QR
der Vorlage. Das gruene Band wird dabei ein eigener Pfad, weil der
PDF-Renderer `clip-path` nicht auswertet.

## Vor dem ersten echten Druck

1. Endgueltige Domain festlegen. Gedruckte Codes und beschriebene Chips
   lassen sich nicht mehr aendern.
2. Probedruck in Originalgroesse (PDF bei 100 %) mit iPhone-Kamera und
   App-Scanner pruefen.
3. Beschnitt, Stanzkontur und Farbprofil nach Vorgabe des Tag-Herstellers
   ergaenzen; die Dateien sind RGB ohne Beschnitt.
