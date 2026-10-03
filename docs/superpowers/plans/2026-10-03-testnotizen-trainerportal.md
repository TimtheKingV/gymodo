# Testnotizen 03.10. — Trainerportal

**Quelle:** Testsitzung 2026-10-03 15:48, Safari 26 / iOS, Stand 3100230
(feat/gymtavo-branding, zwei Einträge, beide auf `geraete/neu`).
**Vorgehen:** testgetrieben — je Etappe zuerst ein roter Vitest (Reinfunktion
oder jsdom), dann die Umsetzung, dann Typecheck. Die E2E-Specs werden an den
neuen Zwischenschritt und das entfallene Minimum nachgezogen; sie laufen in
CI gegen Supabase.

---

## Etappe 1 · Kraft oder Cardio als eigene Frage (Notiz #1)

**Ursache:** Die Kategorie war ein Auswahlfeld im Stammdatenformular, die
Belastungseinheiten daneben unabhängig davon — ein Kraftgerät bot Watt und
km/h an, ein Laufband kg.

- `/geraete/neu` fragt nach „Nein, ein neuer Gerätetyp“ (bzw. direkt, wenn
  es noch keinen Typ gibt) mit zwei großen Knöpfen **Kraft** / **Cardio**;
  die Wahl steht wie `art` in der Adresse (`?art=typ&kategorie=kraft`),
  gleiche `.wahl`-Kacheln und `<a>` statt `<Link>` wie die Frage davor.
- Das Formular bekommt die Kategorie fest (`ModellBelastungRad
  kategorie=…`): kein Kategorie-Feld mehr, nur ein verstecktes.
- Einheiten je Kategorie (`einheitenFuer`): Kraft → nur kg (das
  Belastungsfeld entfällt, die Nebenbelastung auch); Cardio → Watt, Level,
  km/h, %, U/min, ohne kg — auch in der Nebenbelastung.
- Beim Bearbeiten (Stammdaten-Reiter) und in der Halle bleibt das
  Kategoriefeld; es filtert dort dieselben Einheiten. Ein Bestandswert
  außerhalb der Liste bleibt sichtbar, statt still zu verschwinden.
- Tests (rot zuerst): `assistent.test.ts` — `neuAnsicht` liefert
  `"kategorie"` ohne gültige Kategorie; `einstellungVorschlaege.test.ts` —
  `einheitenFuer`; `ModellBelastungRad.test.tsx` — fest auf Cardio: kein
  Kategoriefeld, kein kg; fest auf Kraft: kein Belastungsfeld.

## Etappe 2 · Schritt links, kein Minimum (Notiz #2)

**Ursache:** Die Spalten standen Minimum · Maximum · Schritt. Seit dem
23.09. bestimmt der Schritt den Takt der anderen Spalten — wer links
anfängt, dreht die Grenzen, bevor der Takt steht.

- Reihenfolge des Rads: **Schritt · Maximum** (Haupt- und Nebenbelastung:
  Schritt zuerst).
- Das Minimum der Hauptbelastung entfällt als Spalte. Es ist der kleinste
  Wert über null im Takt, also der Schritt selbst (2,5 kg bei 2,5 kg).
  Beim Bearbeiten bleibt ein Bestandsminimum stehen, wenn es über null
  liegt und im Takt ist; sonst gilt der Schritt (`belastungMinimum`).
- Das Maximum beginnt beim Minimum — 0 wäre jetzt kleiner als das Minimum.
- Die Nebenbelastung behält ihr „ab“: 0 % Neigung ist ein echter Wert.
- Tests (rot zuerst): `einstellungVorschlaege.test.ts` —
  `belastungMinimum`; `ModellBelastungRad.test.tsx` — keine Spalte
  „Minimum“, `loadMin` folgt dem Schritt, Schritt ist die erste Spalte.
- E2E: `radWaehlen(page, "Minimum", …)` entfällt in `trainerportal.spec.ts`
  und `einrichten.spec.ts`; die Zusammenfassung zeigt „ab 2,5 kg“.

---

## Geprüft

- Vitest: 33 Dateien, 215 Tests grün. Zuerst rot gesehen: 16 Tests in
  `assistent`, `einstellungVorschlaege` und `ModellBelastungRad` (neue und
  an das entfallene Minimum angepasste).
- `pnpm typecheck` (Web) und `tsc --noEmit` an der Wurzel (inkl. E2E) sauber.
- `pnpm build` (Produktionsbau) grün.
- **Nicht lokal gelaufen:** Playwright. `supabase start` braucht
  Docker-Images, die das Netz dieser Umgebung nicht lädt — die angepassten
  Specs (`trainerportal.spec.ts`: Kraft wählen, Schritt 5 statt Minimum,
  „ab 5,0 kg“; `einrichten.spec.ts`: ohne Minimum) laufen in CI.
- **Am Gerät ansehen:** die zwei Kacheln Kraft/Cardio; das Formular für
  Kraft ohne Belastungsfeld (nur Rad Schritt · Maximum); für Cardio die
  Einheitenliste ohne kg und die Nebenbelastung mit Schritt links.
- **Nebenwirkung, gewollt:** Wer ein bestehendes Modell mit Minimum 0
  bearbeitet und speichert, bekommt den Schritt als Minimum (0 liegt nicht
  über null). Bestandsminima über null im Takt bleiben.
