# Testnotizen 23.09. — Trainerportal

**Quelle:** Testsitzung 2026-09-23 13:00, Safari 26 / iOS, Stand 466ee8a
(sieben Einträge). **Vorgehen:** testgetrieben — je Etappe zuerst ein roter
Vitest (jsdom) oder eine rote Reinfunktion, dann die Umsetzung, dann
Typecheck. Die E2E-Specs werden an geänderte Beschriftungen und das
eingeklappte Band nachgezogen; sie laufen in CI gegen Supabase.

---

## Etappe 1 · Schublade (Notizen #1, #2)

**#1 Studioname schwarz auf schwarz.** Ursache: das native `<dialog>` bringt
aus dem UA-Stylesheet `color: CanvasText` mit, und `.studioName` setzt keine
eigene Farbe — alles in der Schublade erbt Schwarz. Die feste Rail erbt
`--text` vom `body` und war deshalb nie betroffen.
→ `.drawer { color: var(--text); }` (CSS, kein Unit-Test möglich).

**#2 Titel rutscht beim Laden nach unten.** Die Schublade schloss erst, wenn
sich `usePathname()` änderte — also nach dem Laden. Solange stand sie offen
über einer Seite, deren Inhalt gerade wechselt; auf iOS verschiebt sich
dabei der Kopf. → Ein Klick auf einen Link in der Schublade schließt sie
sofort; der Ladezustand der Seite ist dann das, was man sieht.

- Test (rot zuerst): `MobileNav.test.tsx` — öffnen, auf „Geräte“ klicken,
  Schublade ist sofort zu (ohne Pfadwechsel).

## Etappe 2 · Zahl am Stift (Notizen #3, #5)

- Die Marke am Stift wird grün (`--accent` / `--on-accent`) statt `--warn` —
  gilt für Geräteliste und Übungszeilen gleichermaßen.
- Geräteliste: der Stift trägt `offen.length` als Marke; die orange/graue
  Zustandszeile darunter entfällt, sobald etwas offen ist. „Fertig
  eingerichtet“ bleibt.
- Test (rot zuerst): `Stift.test.tsx` — Marke zeigt die Zahl, aria-label
  nennt „(2 Punkte offen)“, ohne offene Punkte keine Marke.

## Etappe 3 · „Noch zu tun“ eingeklappt (Notiz #4)

- `NochZuTun` wird ein `<details>`; die Kopfzeile („Noch zu tun · 2 Punkte
  offen“) ist das `<summary>`. Standard: zu.
- Test (rot zuerst): `NochZuTun.test.tsx` — geschlossen gerendert, Kopf mit
  Anzahl sichtbar, Liste erst nach Aufklappen.
- E2E `trainerportal.spec.ts`: vor dem Blick in die Liste aufklappen.

## Etappe 4 · Video in voller Breite, Abspielen im Vollbild (Notiz #6)

- Neuer Baustein `VideoAbspieler`: ist ein Video da, steht das Standbild in
  voller Breite (16:9) mit Abspiel-Symbol; ein Tipp öffnet einen
  Vollbild-Dialog mit Player (`controls`, `autoPlay`). Ohne `playsInline`,
  damit iOS-Safari beim Start in den nativen Vollbild-Player geht.
- `VideoUpload` nutzt ihn statt der Mini-Vorschau; ohne Video bleibt der
  Platzhalter. Auch das Vorschaubild links in der Übungszeile öffnet den
  Player.
- Test (rot zuerst): `VideoAbspieler.test.tsx` — Knopf „Video abspielen“,
  Klick öffnet Dialog mit `<video controls>`, „Schließen“ schließt.

## Etappe 5 · Gerät hinzufügen als geführter Ablauf (Notiz #7)

Schritte: **1 Stammdaten → 2 Einstellungen → 3 Übungen → 4 Einzelne Geräte**.

- „Gerät hinzufügen“ ist ein Link auf die neue Route `geraete/neu` statt
  eines aufklappenden Formulars über der Liste. Dort: Schrittleiste
  „Schritt 1 von 4“, nur das Stammdatenformular, Knopf **Weiter** — die
  anderen Geräte stehen nicht darunter.
- `modellAnlegen` leitet auf `geraete/<id>/einstellungen?neu=1`.
- Die bestehenden Reiter-Seiten werden wiederverwendet. Mit `?neu=1` zeigt
  das Modell-Layout statt Reiterleiste und „Noch zu tun“ die Schrittleiste
  und unten eine Fußleiste **Zurück / Weiter zu …**; im letzten Schritt
  **Fertig** (zurück zur Geräteliste). Das Layout sieht keine
  Suchparameter, deshalb entscheidet eine Client-Komponente
  (`ModellRahmen`) per `useSearchParams`.
- Die Schrittlogik ist eine Reinfunktion `assistentSchritt()` in
  `geraete/assistent.ts`.
- Test (rot zuerst): `assistent.test.ts` — Nummer, Titel, Zurück- und
  Weiter-Ziel je Segment; unbekanntes Segment → `null`.
- E2E `trainerportal.spec.ts`: Anlegen über „Gerät hinzufügen“ → „Weiter“,
  landet in Schritt 2.

---

## Geprüft

- Vitest: 20 Dateien, 125 Tests grün, darunter die neuen `MobileNav`,
  `Stift`, `NochZuTun`, `VideoAbspieler`, `assistent`, `ModellRahmen` — die
  neuen Verhaltens-Tests zuerst rot gesehen (`Stift` ist ein
  Charakterisierungstest: der Baustein konnte die Zahl schon, neu sind Farbe
  und Verwendung).
- `pnpm typecheck` (Web) und `tsc --noEmit` an der Wurzel (inkl. E2E) sauber.
- `pnpm build` (Produktionsbau) grün, `/portal/[studioId]/geraete/neu`
  steht als eigene Route; `useSearchParams` im Modell-Layout bricht den Bau
  nicht (die Route ist ohnehin dynamisch).
- **Nicht lokal gelaufen:** Playwright. `supabase start` braucht
  Docker-Images, die das Netz dieser Umgebung nicht lädt — die E2E-Specs
  laufen in CI. Ebenfalls offen: der Blick am iPhone auf Farbe der
  Schublade, Vollbild-Player und klebende Fußleiste.
