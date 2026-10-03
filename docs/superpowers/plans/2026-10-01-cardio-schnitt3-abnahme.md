# Cardio Schnitt 3 (iOS) — Abnahme

Manuelle Abnahme gegen das **lokale** Backend (`supabase db reset` auf dem Branch-Stand mit `0045_belastung_umfang.sql`, `pnpm --filter @fitretro/web dev`, App mit `SUPABASE_URL`/`API_BASE_URL` auf `127.0.0.1` als Build-Einstellung überschrieben — `Config.xcconfig` blieb unangetastet). Gegen Produktion lief nichts.

Gefahren wurde die App im Simulator (iPhone 17 Pro, iPhone SE 3. Generation, iOS 26.3, Standard-Schriftgröße) über einen Wegwerf-UI-Test, der tippt, wischt, Screenshots und den Accessibility-Baum ablegt. Der Treiber liegt nicht im Repository. „Scan" heißt hier immer „Suchen": der Simulator hat keine Kamera und keinen NFC-Leser.

## Testdaten

Studio „Kraftwerk Nord" mit Beinpresse (kg, 5–200, Schritt 2,5, Einstellwert Sitz, Beidbeinig 8–12), Latzug (kg, ohne Historie), Laufband (kmh 0–20/0,5, Nebenbelastung pct 0–15/0,5, Dauerlauf 15–20 min, Intervall 2.000–5.000 m), Ergometer (watt 25–400/5), Rudergerät (level 1–10, „2 km" 2.000–2.000 m). Historie vor 8 Tagen: Beinpresse 3 × 77,5 kg × 11, Laufband 8,5 km/h bei 6 % × 20:00.

## Beinpresse vorher/nachher

Derselbe Ablauf (Training → Suchen → Beinpresse → Beidbeinig → Training starten → Rückblick → Weiter) einmal mit `master` (alte Migrationen, alte API, alte App) und einmal mit diesem Stand, beide Geräte, Statusleiste auf 9:41 fixiert, Pixelvergleich:

| Screen | iPhone 17 Pro | iPhone SE |
|---|---|---|
| Gerät erkannt / Übungswahl | identisch | identisch |
| „Training starten" | identisch | identisch |
| Satzpfad (Räder, Sitz 4, Satz 1 sichern) | identisch bis auf die laufende Trainingsuhr | identisch bis auf die laufende Trainingsuhr |
| Rückblick-Drawer | identisch (SE); auf dem 17 Pro war der Kontext im Nachher-Lauf beim Screenshot noch nicht da — Timing, nicht Layout | identisch |

Bewusste Abweichungen außerhalb des Satzpfads (in den Commits begründet): „Vorschlag · +2,5 kg" statt „+2,5" im Rückblick, „−2,5 kg" mit U+2212 im Abschluss, Überschrift „KRAFT · A–Z" statt „ALLE GERÄTE · A–Z" in der Gerätesuche.

## Laufband

| Schritt | Befund |
|---|---|
| Gerätesuche | „ZULETZT BEI DIR", „KRAFT · A–Z", „CARDIO · A–Z"; Zuletzt-Zeile „vor 1 Minute · 8,5 km/h" |
| Satzpfad (SE) | 8,5 km/h · 20:00 min · Neigung 6,0 % vorbelegt; passt ohne Scrollen. Kontextzeilen „Schritt 0,5 km/h · 0,0 – 20,0", „Ziel 15 – 20 min" |
| Rückblick (SE) | „8,5 km/h · 6,0 % × 20:00 min" war abgeschnitten → bricht jetzt um (`76f9430`) |
| Satz sichern | Server hat `load 8.5, secondary_load 6.00, volume 1200` |
| Nach dem Satz | keine Pause, sondern „1 SATZ GESCHAFFT" / Gerät abschließen / Weiterer Satz |
| TrainingLäuft | „Laufband · Dauerlauf — 1 Satz · 8,5 km/h · 6,0 %" |
| Abschluss | „+0,5 km/h bei 6,0 %" — brach in einer Zeile mitten in „6,0 %" um → jetzt Zahl groß, „bei 6,0 %" darunter (`18a731e`); VoiceOver „Vorschlag plus 0,5 Kilometer pro Stunde bei 6,0 Prozent" |
| Home | Fortschrittskarte „Laufband 2 · Dauerlauf 8,5 km/h" |
| Übungsfortschritt | „8,5 km/h", Rohwerte „8,5 km/h × 20:00 min" |
| Session-Detail | „8,5 km/h · 6,0 % × 20:00 min", VoiceOver „Satz 1, 8,5 Kilometer pro Stunde bei 6,0 Prozent, 20 Minuten" |

## Beinpresse im selben Training

Satz 1 sichern → Pause (01:29) → Gerät abschließen → Training beenden → Abschluss „77,5 kg · 1 Satz — Gewicht halten". Session-Detail „77,5 kg × 11".

## Rudergerät (SE, Erstkontakt)

Erste Werte: „Level" 1, Umfangsrad „2.000" in der breiten Spalte ohne Schrumpfen, „Schritt 1 Level · 1 – 10". Das feste Ziel hieß „Ziel 2.000 – 2.000 m" → jetzt „Ziel 2.000 m" (`18a731e`).

## Nicht geprüft

- Echter QR-/NFC-Scan (Simulator).
- „Weiter" in der Pause per UI-Test-Tipp löste im Lauf nicht aus; der Pausen-Screen ist in diesem Schnitt unverändert, der Ablauf ging über „Gerät abschließen" weiter.
- Ergometer (watt) und Intervall (Meter) nur über Unit-Tests, nicht im Simulator.
- Dynamic-Type-Stufen über Standard.

## Nebenbefund (nicht dieser Schnitt)

Das Rudergerät hat keine Einstelldefinitionen, der Erstkontakt zeigt trotzdem „SCHRITT 1 VON 3" und „Einstellungen erfassen". Daran arbeitet offenbar der Worktree `fix-kalibrierung-ohne-einstellwerte`.
