# Testnotizen 25.09. — Trainerportal

**Quelle:** Testsitzung 2026-09-25 19:02, Safari 26 / iOS, Stand a40604c
(sieben Einträge). **Vorgehen:** testgetrieben wie am 23.09. — je Etappe
zuerst ein roter Vitest (jsdom) oder eine rote Reinfunktion, dann die
Umsetzung, dann Typecheck. Die E2E-Specs werden an geänderte Beschriftungen
nachgezogen; sie laufen in CI gegen Supabase.

Notiz #6 ist eine Frage („erst Überblick geben, dann entscheiden wir
gemeinsam“) und wird nicht umgesetzt — die Antwort steht unten unter
**Offen**.

---

## Etappe 1 · Überblick entrümpeln (Notizen #2, #3, #4)

**#2 Gemeldete Probleme zeigen nur die Nummer.** Ursache: `studio_overview`
(0034/0044) liefert als `label` die Spalte `machines.label` — das ist die
Bezeichnung des einzelnen Geräts im Raum („3“), nicht der Gerätetyp. Der
Name des Modells steckt im Katalog, den die Seite ohnehin lädt
(`katalog.models[].machines[]`). → Reinfunktion `geraeteName(katalog,
machineId, label)` in `(schreibtisch)/ueberblick.ts`: „Beinpresse 3“, im
selben Muster wie `einrichten/geraet/[machineId]` (`${modell.name}
${geraet.label}`). Kein RPC-Umbau, keine Migration. „Meistgenutzt“ hat
dieselbe Ursache und bekommt denselben Namen.

- Test (rot zuerst): `ueberblick.test.ts` — Modellname + Nummer; unbekannte
  Maschine → nur die Nummer (der Katalog lädt stillgelegte Modelle nicht
  zwingend mit, ein Loch darf keinen Absturz geben).

**#3 „gymodo misst nichts …“ entfernen**, **#4 Vorspann „Letzte 30 Tage …“
entfernen.** Reine Streichungen. Der Baustein `Produktgrenze` hat danach
keine Verwendung mehr und fällt weg (die Landeseite setzt den Satz selbst).
- E2E `schreibtisch.spec.ts`: die zwei Tests „nennt die Produktgrenze“ und
  „Produktgrenze steht in text-muted“ werden zu einem, der sagt, dass der
  Satz auf dem Überblick nicht mehr steht. Landeseite und Tag-Fallback
  behalten ihn und ihre Tests.

## Etappe 2 · Mitarbeiter: Stift statt Knopf (Notiz #5)

„Zum Mitglied herabstufen“ nahm auf dem Telefon die halbe Zeile ein und
presste E-Mail und Datum zusammen. → `MitarbeiterZeile` trägt rechts oben
den `StiftKnopf` (wie die Übungszeile); ein Druck klappt darunter die
Optionen auf — heute eine: „Zum Mitglied herabstufen“ (zweistufig wie
bisher). Eigene Zeile („Das bist du“) und Inhaber bleiben ohne Stift.

- Test (rot zuerst): `LeuteActions.test.tsx` — Stift „<E-Mail> bearbeiten“
  vorhanden, Herabstufen erst nach dem Druck sichtbar; eigene Zeile und
  Inhaber ohne Stift.
- E2E `schreibtisch.spec.ts` (eigene Zeile ohne Herabstufen) bleibt gültig;
  zusätzlich: eigene Zeile hat keinen Stift.

## Etappe 3 · „Gerät hinzufügen“ fragt zuerst nach einem vorhandenen Gerät (Notiz #7)

**Wie es heute ist (Antwort auf die Frage in #7):** Es wird nichts
dupliziert. Ein *Modell* (`equipment_models`) trägt Stammdaten,
Einstellungen und Übungen; jedes Gerät im Raum ist eine Zeile in `machines`
mit Verweis `equipment_model_id` und eigener Bezeichnung (Nummer) und
Standort. Das zweite gleiche Gerät ist also ein weiterer Verweis auf
denselben Stamm — ändert man Übungen oder Videos am Modell, gilt das für
alle Geräte dieses Typs. Bisher erreichte man das nur über den letzten
Reiter „Einzelne Geräte“ des Modells.

**Umdrehen:** `geraete/neu` fragt zuerst, sofern das Studio schon Modelle
hat: **„Neuer Gerätetyp“** (der bisherige Ablauf, Schritt 1 von 4) oder
**„Weiteres Gerät eines vorhandenen Typs“** (`?art=exemplar`): Gerätetyp aus
der Liste wählen, Nummer und optional Standort eintragen, **Gerät anlegen** →
landet auf „Einzelne Geräte“ dieses Modells, wo es direkt einen Tag
bekommen kann. Ohne Modelle entfällt die Frage.

- Reinfunktion `neuAnsicht(art, modellAnzahl)` in `geraete/assistent.ts` →
  `"frage" | "typ" | "exemplar"`.
- Neue Server-Aktion `exemplarAnlegen` (liest `modelId` aus dem Formular,
  nutzt `createMachine` wie `geraetAnlegen`, leitet dann weiter).
- Tests (rot zuerst): `assistent.test.ts` (neuAnsicht),
  `ExemplarFormular.test.tsx` (Gerätetyp-Auswahl trägt `modelId` ins
  Formular, Knopf „Gerät anlegen“).
- E2E `trainerportal.spec.ts`: legt das erste Modell an — ohne Modell keine
  Frage, der bisherige Test bleibt gültig.

## Etappe 4 · Kurse: Wochenstreifen wie in der App, Monatsansicht (Notiz #1)

In der App steht oben ein Wochenstreifen: sieben Zellen mit
Wochentagsbuchstabe und Tagesnummer, heute mit Ring, ein Punkt an Tagen mit
Kursen (`KurseWochenView.swift`). Das Portal hatte nur „← Vorige Woche“,
den Titel und „Nächste Woche →“ als Textpillen.

- Umschalter **Woche | Monat** über `?ansicht=monat` (Links, kein
  Client-Zustand; `<a>` statt `<Link>` aus dem im Code dokumentierten Grund:
  ein Wechsel nur des Suchparameters läuft im Produktionsbau ins Leere).
- **Woche:** Pfeile ‹ › (aria-label „Vorige Woche“ / „Nächste Woche“, damit
  Screenreader und E2E gleich bleiben), Titel, darunter der Streifen. Jede
  Zelle springt zum Abschnitt des Tages (`#tag-JJJJ-MM-TT`).
- **Monat:** Pfeile ‹ › („Voriger Monat“ / „Nächster Monat“), Titel
  „September 2026“, Raster Mo–So mit Nummer und Anzahl der Kurse je Tag.
  Ein Tipp auf einen Tag öffnet dessen Woche, gesprungen auf den Tag.
  Geladen wird das Raster (Montag vor dem 1. bis Sonntag nach dem Letzten)
  mit derselben `course_week`-Abfrage.
- Reinfunktionen in `kurse/woche.ts`: `monatsFenster(anker, zeitzone)`,
  `kalenderTage(vonIso, anzahl, heuteIso, sessions, monat?)`.
- Tests (rot zuerst): `woche.test.ts` (Monatsfenster: Raster, Titel,
  Nachbarmonate, Zeitumstellung; Kalendertage: heute, Kursanzahl ohne
  abgesagte, außerhalb des Monats) und `Kalender.test.tsx` (Umschalter
  markiert die aktive Ansicht, Wochenstreifen verlinkt Tagesanker).
- E2E `kurse.spec.ts`: Wochenwechsel läuft weiter über die Namen
  „Vorige/Nächste Woche“; neu: Monatsansicht zeigt den Monat und führt per
  Tipp in die Woche.

---

## Geprüft

- Vitest: 29 Dateien, 181 Tests grün. Neu und zuerst rot gesehen:
  `ueberblick.test.ts`, `LeuteActions.test.tsx`, `neuAnsicht` in
  `assistent.test.ts`, `ExemplarFormular.test.tsx`, die Kalender-Fälle in
  `woche.test.ts` und `Kalender.test.tsx`.
- `pnpm typecheck` (Web) und `tsc --noEmit` an der Wurzel (inkl. E2E) sauber.
- `pnpm build` (Produktionsbau) grün.
- **Nicht lokal gelaufen:** Playwright. `supabase start` braucht
  Docker-Images, die das Netz dieser Umgebung nicht lädt — die E2E-Specs
  (neu: Monatsansicht in `kurse.spec.ts`, weiteres Gerät und Stift-Zeile in
  `schreibtisch.spec.ts`, Überblick ohne Produktgrenze) laufen in CI.
- **Am iPhone anzusehen:** Wochenstreifen und Monatsraster auf 390 px
  (Siebtelspalten ~50 px), Umschalter Woche | Monat, die aufgeklappte
  Mitarbeiterzeile, die Wahlflächen unter „Gerät hinzufügen“.
- Entscheidung: der Akzent-Punkt der App ist im Portal grau
  (`--text-muted`) — ein grüner Punkt zählte als zweite Akzentfläche neben
  „Termin anlegen“. Der Ring um heute bleibt grün.
- Entscheidung: „Meistgenutzt“ trägt denselben Gerätenamen wie „Gemeldete
  Probleme“ — dieselbe Ursache.

## Offen

**#6 Mitarbeiter einladen — wie es heute ist:** Es gibt keinen eigenen
Einladungsweg für Personal. Jeder tritt über den Studio-Code bei
(`join_studio_by_code`, 0030; Code unter Einstellungen) und ist dann
Mitglied; ein Inhaber oder Trainer stuft ihn unter Leute → Mitarbeiter hoch.
Siehe Antwort im Chat für die Optionen.

---

## Nachtrag · Etappe 5 · Mitarbeiter einladen per Link (Notiz #6, Möglichkeit 2)

Entschieden am 26.09.: ein einmal gültiger Einladungslink mit Ablauf, kein
Mailversand.

**Ablauf.** Unter Leute → Mitarbeiter erzeugt ein Trainer oder Inhaber
„Einladungslink erstellen“. Der Link (`/einladung/<token>`) wird genau dann
angezeigt, zum Kopieren oder Teilen (iOS-Teilen-Blatt über
`navigator.share`). Er gilt 7 Tage und für eine Person. Offene Einladungen
stehen darunter mit Ablaufdatum und lassen sich zurückziehen.
Wer den Link öffnet:
- nicht angemeldet → „Du bist eingeladen, bei <Studio> als Trainer
  mitzuarbeiten“ mit **Konto anlegen** / **Anmelden**; beide führen nach
  dem Anmelden (auch nach dem Bestätigungscode) zurück auf den Link
  (`?weiter=`),
- angemeldet → **Einladung annehmen** → Trainer im Studio → Portal.
- abgelaufen, benutzt, zurückgezogen oder unbekannt → ein Satz, alle gleich
  (sonst ließen sich gültige Links erraten).

**Datenbank (0045_mitarbeiter_einladung.sql).** Tabelle `staff_invites`;
gespeichert wird nur der SHA-256 des Tokens, nie der Token selbst — eine
gelesene Zeile ist kein Link. Lesen per RLS nur Personal des Studios,
Schreiben nur über SECURITY-DEFINER-Funktionen:
`create_staff_invite`, `staff_invite_info` (auch für `anon`: Name des
Studios vor der Anmeldung), `accept_staff_invite` (einmalig, sperrt die
Zeile `for update`; aus einem Mitglied wird Trainer, ein Inhaber bleibt
Inhaber), `revoke_staff_invite`.

**Tests.**
- Integration (rot zuerst, laufen in CI gegen Supabase):
  `tests/integration/staff-invites.test.ts` — nur Personal erzeugt; der
  Token liegt nicht in der Tabelle; anonym liest man den Studionamen;
  Annehmen macht Trainer, ein zweites Annehmen scheitert; abgelaufen und
  zurückgezogen gelten nicht; Inhaber wird nicht herabgestuft; ein Mitglied
  sieht keine Einladungen.
- Vitest: `weiter.test.ts` (nur eigene Pfade als Rücksprung, kein
  `//evil.example`), `EinladungErstellen.test.tsx` (Link erscheint nach dem
  Erzeugen, Kopieren schreibt ihn in die Zwischenablage).
- E2E `leute.spec.ts`: Trainer erzeugt Link, ein anderes Konto öffnet ihn,
  meldet sich an, nimmt an und steht im Portal.

**Eine Akzentfläche.** „Einladungslink erstellen“ wird die Hauptaktion des
Reiters, „Zum Trainer machen“ wird Nebenaktion — der Weg über das
Hochstufen bleibt, ist aber nicht mehr der erste.

### Geprüft (Etappe 5)

- Vitest Web: 31 Dateien, 187 Tests grün; Domäne: 17 Dateien, 169 Tests.
  Zuerst rot gesehen: `weiter.test.ts`, `EinladungErstellen.test.tsx`,
  `einladungen.test.ts` (Domäne).
- Migration 0045 gegen ein lokales PostgreSQL 16 mit nachgebauten
  Supabase-Grundlagen (`auth.uid()`, Rollen `anon`/`authenticated`,
  `studios`, `studio_memberships`, `is_studio_staff`) eingespielt und von
  Hand durchgespielt: Trainer erzeugt, Mitglied darf nicht; anonym liest
  den Studionamen, darf nicht annehmen; Annehmen macht aus Mitglied und
  neuem Konto Trainer, genau einmal; Inhaber bleibt Inhaber; abgelaufen und
  zurückgezogen gelten nicht; im Speicher steht kein Klartext-Token; direkt
  in die Tabelle schreiben scheitert an RLS.
- **Nicht lokal gelaufen:** `tests/integration/staff-invites.test.ts` und
  der E2E-Fall in `leute.spec.ts` — beide brauchen `supabase start`, laufen
  in CI.
- `pnpm typecheck`, `tsc --noEmit` (Wurzel), `pnpm build` grün;
  `/einladung/[token]` steht als Route.
- **Vor dem Ausrollen:** Migration 0045 muss in die Produktionsdatenbank
  (`pnpm smoke:migrations` meldet den Rückstand), sonst scheitert
  „Einladungslink erstellen“ mit einem Datenbankfehler.
- **Am iPhone anzusehen:** „Teilen“ öffnet das Teilen-Blatt; Kopieren;
  der Weg Link → Konto anlegen → Code aus der Mail → zurück auf der
  Einladung.
