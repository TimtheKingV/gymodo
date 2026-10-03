# GYMTAVO Wortmarke

Quelle: `gymtavo-logo.html`, der vorhandene Logoentwurf vom 9. September 2026.
Die HTML-Datei bleibt unveraendert erhalten und enthaelt die Originalschrift
sowie die SIL-Open-Font-Lizenz (zusaetzlich in `Archivo-OFL.txt`).

- Vollstaendiger Schriftzug **GYMTAVO** mit gruenem Punkt, kein einzelnes Icon.
- Archivo 900, Laufweite -0.05 em, Punktdurchmesser 7/27 em,
  Abstand nach dem Wort 3/27 em, Punktunterkante auf der Grundlinie.
- `gymtavo-wordmark.svg`: helle Buchstaben #F2F4F7 fuer dunklen Hintergrund.
- `gymtavo-wordmark-on-light.svg`: dunkle Buchstaben #0A0B0D fuer hellen Hintergrund.
- Punkt jeweils #D4FF3F; Hintergrund transparent.

Die SVGs enthalten Glyphenumrisse und brauchen weder installierte Schriften
noch externe Requests. Exportiert aus der eingebetteten Archivo-Datei mit
FontTools und Pillow/RAQM (Kerning aktiv), anschliessend CSS-Laufweite und
Punktgeometrie der Vorlage angewandt. Die Vorlage bleibt die Designreferenz.

Web-Kopien: `apps/web/public/branding/`. Der gemeinsame Baustein
`apps/web/app/branding/GymtavoWordmark.tsx` wird auf der Landeseite und in
der Einstiegshuelle verwendet. Die iOS-Kopie liegt in
`apps/ios-member/FitnessMember/Assets.xcassets/GymtavoWordmark.imageset/`
und wird in `LoginMailView.swift` gezeigt. Das Xcode-Projekt wird mit
`xcodegen generate` aus `project.yml` erzeugt; der Katalog liegt unter
`sources: FitnessMember`.

Bei Aenderungen alle SVG-Kopien zusammen aktualisieren. Sichtbare Texte
heissen "Gymtavo"; App-Icon, Bundle-ID (de.gymtaro.*), Domain
(gymodo-web.vercel.app) und Testnotiz-Formatkennungen sind bewusst nicht
umgestellt.

## Abnahme

- [ ] Wortmarke im Browser gegen die HTML-Referenz vergleichen, auch bei 320 px.
- [ ] Xcode-Build und Sichtpruefung auf kleinem iPhone: keine abgeschnittenen
      Felder oder Buttons, Wortmarke korrekt, VoiceOver liest GYMTAVO.
- [ ] CI fuer diesen Commit pruefen.

QR/NFC: siehe `../../docs/branding/qr-nfc-design-status.md`.
