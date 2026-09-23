# Testnotizen 23.09. (zweite Sitzung) — Trainerportal, Ablauf „Gerät hinzufügen“

**Quelle:** Testsitzung 2026-09-23 15:25, Safari 26 / iOS, Stand 3eb0093
(fünf Einträge, alle im Ablauf „Gerät hinzufügen“ `?neu=1`).
**Vorgehen:** wie beim Lauf vom Vormittag
(`2026-09-23-testnotizen-trainerportal.md`): je Etappe zuerst ein roter
Vitest (jsdom) oder eine rote Reinfunktion, dann die Umsetzung, dann
Typecheck. Die E2E-Specs werden an geänderte Beschriftungen und den neuen
Ablauf nachgezogen. Sie laufen in CI gegen Supabase.

---

## Etappe 1 · Weiter erst, wenn etwas gespeichert ist (Notizen #1, #5)

**#1 Einstellungen:** Die Liste der gespeicherten Einstellungen steht über
dem Formular. Solange noch keine gespeichert ist oder das Formular offen
steht, gibt es unten kein „Weiter zu den Übungen“. Nach dem Speichern klappt
das Formular zu, darüber steht dann der Knopf „Weitere Einstellung
hinzufügen“. Offen trägt das Formular unten **Einstellung speichern** und
**Abbrechen**.

**#5 Übungen:** Weiter erst ab einer angelegten Übung.

Ursache: `ModellRahmen` zeigte „Weiter“ in jedem Schritt bedingungslos. Er
kannte weder die Anzahl der Einstellungen/Übungen noch den Zustand des
Formulars auf der Seite darunter. `Hinzufuegen` ließ das Formular nach dem
Anlegen mit Absicht offen (Testnotiz 22.09., #10). Für den Ablauf ist das jetzt
falsch.

Änderung:
- Reinfunktion `weiterSperre(segment, { einstellungen, uebungen,
  formularOffen })` in `geraete/assistent.ts`. Sie liefert `null` (Weiter
  frei) oder den Satz, der statt „Weiter“ unten steht.
- Das Layout reicht die Anzahlen an `ModellRahmen`. Das Revalidieren nach dem
  Anlegen (`revalidatePath(…, "layout")`) liefert sie neu.
- Neuer Kontext `bausteine/FormularOffen.tsx`: `ModellRahmen` stellt ihn
  bereit, `Hinzufuegen` meldet darüber, ob es offen ist. Die Reiterseiten
  bleiben Server-Komponenten.
- `Hinzufuegen` mit `abbrechenImFormular`: Es gibt kein „Schließen“ im Kopf.
  Stattdessen gibt ein Kontext `schliessen` an das Formular weiter.
  `AktionsFormular` bekommt dafür den Platz `nebenAktion` neben dem
  Absendeknopf. `EinstellungFormular` schließt nach Erfolg.
- Einstellungen-Seite: zuerst die Liste, dann `Hinzufuegen`.
- Tests (rot zuerst): `assistent.test.ts` (Sperre je Schritt),
  `ModellRahmen.test.tsx` (kein Weiter-Link, Hinweis sichtbar; Weiter nach
  Speichern, offenes Formular sperrt), `Hinzufuegen.test.tsx`
  (Abbrechen im Formular, meldet offen/zu).

## Etappe 2 · Name aus dem Rad, Vorauswahl der Parameter (Notiz #2)

- Zuerst steht nur das Rad **Einstellung** mit den Vorschlägen und
  „Sonstiges …“ am Ende. Erst bei „Sonstiges …“ erscheint das Textfeld
  **Beschriftung**. Sonst ist der gewählte Vorschlag die Beschriftung
  (verstecktes Feld `label`).
- Die Wahl setzt Minimum, Maximum, Schritt und Einheit vor. Die Werte liefert
  die Reinfunktion `vorgabeFuer(name)` in `einstellungVorschlaege.ts`, z. B.
  Winkel → 0–90, Schritt 5, „°“. Das Zahlenrad wird dafür per `key` neu
  eingehängt. Das ist gewollt: Die Vorauswahl gilt nur beim Wechsel des
  Namens.
- Das Halle-Formular (`EinstellungSheet`, `NameFeld`) bleibt unverändert,
  die Notiz betrifft den Schreibtisch.
- Tests (rot zuerst): `einstellungVorschlaege.test.ts` (`vorgabeFuer`),
  `EinstellungFormular.test.tsx` (kein Textfeld zu Beginn, „Sonstiges …“
  zeigt es, Winkel stellt „°“ und Schritt 5 ein).

## Etappe 3 · Minimum/Maximum im Takt des Schritts (Notiz #3)

- `minMaxWerte(schritt)` und `maxGewichtWerte(schritt)` zählen im
  gewählten Schritt (0, 5, 10 …). Ohne Argument bleibt es bei Schritt 1.
- `RadSpalte` nimmt neue `werte` an: Sie bleibt auf dem nächstliegenden
  Wert stehen und scrollt dorthin, statt auf einen Index zu zeigen, den es
  nicht mehr gibt.
- `EinstellungFormular` und `ModellGewichtRad` (Stammdaten, Anlegen und die
  Halle) führen den Schritt als State und reichen ihn an Minimum/Maximum
  weiter.
- Tests (rot zuerst): `einstellungVorschlaege.test.ts` (Takt),
  `EinstellungRad.test.tsx` (neue Werte → nächster Wert),
  `EinstellungFormular.test.tsx` (Schritt 5 → Minimum 0, 5, 10 …).

## Etappe 4 · Videofeld in voller Breite (Notiz #4)

- Ohne Video steht statt der 96-px-Kachel eine Fläche in voller Breite
  (16:9). Ein Tipp öffnet die Auswahl des Systems („Video aufnehmen“ oder
  „Mediathek“, weil `capture` fehlt). Mit Video steht `VideoAbspieler` in
  voller Breite, darunter „Anderes Video wählen“ bzw. „Video ersetzen“.
- `DateiKnopf` bekommt `art="flaeche"`, damit das versteckte Dateifeld und
  seine Beschriftung nicht doppelt gebaut werden. Gilt im Anlegeformular
  (`UebungFormular`) und an der Zeile (`VideoUpload`).
- Tests (rot zuerst): `DateiKnopf.test.tsx` (Fläche öffnet das Dateifeld),
  `UebungFormular.test.tsx` (Fläche statt „Kein Video“-Kachel, nach der Wahl
  der Abspieler).

---

## Geprüft

- Vitest: 25 Dateien, 158 Tests grün. Die neuen Tests standen alle zuerst
  auf Rot: `assistent` (weiterSperre), `ModellRahmen`, `Hinzufuegen`,
  `EinstellungFormular`, `einstellungVorschlaege`, `EinstellungRad`,
  `ModellGewichtRad`, `DateiKnopf`, `UebungFormular`. „Fläche öffnet das
  Dateifeld“ in `DateiKnopf` ist ein Charakterisierungstest. Das Öffnen
  konnte der Knopf schon, neu ist die Fläche.
- `pnpm typecheck` (Web) und `tsc --noEmit` an der Wurzel (inkl. E2E) laufen
  sauber.
- `pnpm build` (Produktionsbau) ist grün.
- E2E `trainerportal.spec.ts` nachgezogen: Schritt 2 zeigt zuerst kein
  „Weiter“. Die Einstellung wird im Ablauf über „Sonstiges …“ und
  „Einstellung speichern“ angelegt. Danach ist „Weiter zu den Übungen“ frei,
  Schritt 3 sperrt bis zur ersten Übung.
- **Nicht lokal gelaufen:** Playwright. `supabase start` braucht
  Docker-Images, die das Netz dieser Umgebung nicht lädt. Die E2E-Specs
  laufen in CI.
- **Am iPhone noch ansehen:** das Namensrad als erstes Feld, das Nachspringen
  von Minimum/Maximum beim Wechsel des Schritts, die Videofläche (16:9) und
  die Systemauswahl „Aufnehmen/Mediathek“ beim Tippen darauf.
- Bewusst nicht geändert: Das Halle-Formular (`EinstellungSheet`) behält
  `NameFeld` und den festen 0–200-Bereich, weil die Notizen nur den
  Schreibtisch betreffen. `ModellGewichtRad` gilt dagegen überall (Anlegen,
  Stammdaten, Halle): Ein Gewicht im Takt des Schritts ist dort genauso
  richtig.
