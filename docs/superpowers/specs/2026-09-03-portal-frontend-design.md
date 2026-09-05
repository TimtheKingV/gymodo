# Portal-Frontend — Bausteine, Schnitt und Abnahme

**Stand:** 3. September 2026
**Status:** Entwurf, abgestimmt. Noch keine Umsetzung.
**Vorgänger:** `2026-08-30-designsystem.md` (Tokens und Regeln), `2026-08-31-trainerportal-struktur-design.md` (Informationsarchitektur, Zustände, Bildschirmverzeichnis), `../plans/2026-08-31-designplan-trainerportal.md` (Global Constraints, wörtlich aus dem Code)
**Artboards:** `docs/superpowers/design/portal/` — 39 Stück
**Fahrplan:** Phase 5 in `../plans/2026-09-01-gesamtfahrplan.md`

---

## Warum dieses Dokument existiert

Das Trainerportal ist funktional vollständig und ungestaltet. Die 39 Artboards sagen, wie jeder einzelne Bildschirm aussieht; sie sagen nicht, in welcher Reihenfolge gebaut wird, was sich die Bildschirme teilen, und woran einer als fertig gilt.

Genau diese drei Fragen beantwortet dieses Dokument. Es zeichnet nichts nach — für das Aussehen ist das jeweilige Artboard die Wahrheit, und wo Artboard und laufende Oberfläche sich widersprechen, gilt die Regel aus den Global Constraints: **ein Entwurf, der von der laufenden Oberfläche abweicht, ist ein Fehler im Entwurf.** Abschnitt 5 führt Buch über jede solche Abweichung, die beim Lesen aufgefallen ist.

**Es ist nicht die grüne Wiese.** Tokens und Rail stehen im Code, die 16 `Telefon*`-Bildschirme sind in Phase 3 gebaut und gestaltet, und `/t/<token>` trägt seit dem Medienplan ein eigenes Stylesheet nach Member-Maßen. Was fehlt, ist der Schreibtisch und der Einstieg.

---

## Entscheidungen

Vier, alle in dieser Runde getroffen:

1. **Das Beitrittsformular bleibt im Web**, gestaltet, auf `/` für angemeldete Nicht-Mitarbeiter ohne Studio. Die Canvas-Notiz `note-einstieg` will es streichen — aber der Weg, der es ersetzen soll, ist die iOS-App, und die ist Phase 6. Ein Weg wird nicht gestrichen, bevor sein Nachfolger existiert.
2. **Geräte und Modelle werden ein Bereich.** `/geraete` wird die Modellliste, `/modelle` leitet dorthin. Die flache Geräteliste entfällt — und sie kostet dabei nichts: *Stilllegen* und *Wieder in Betrieb* stehen bereits im Modell-Detail, Abschnitt *Geräte im Raum*. Die flache Liste war eine zweite Kopie derselben beiden Aktionen.
3. **„Lädt" heißt Titel sofort, Rumpf still.** Ein `loading.tsx` je Bereich rendert Titel und Vorspann — die stehen in der Route, nicht in der Datenbank — und darunter bleibt es leer. Keine Skelettzeilen: ihre Anzahl wäre geraten und damit eine Aussage über Daten, die noch niemand kennt.
4. **Gemeinsame Bausteine als Komponenten**, nicht als weitere Klassen in einem Stylesheet. Die Regeln dieses Entwurfs sind Text; Text braucht einen Ort.

---

## 1. Die Bausteinschicht

```
apps/web/app/portal/bausteine/
  Seite.tsx          Titel, Vorspann, Rumpf — rendert KEIN <main>
  Abschnitt.tsx      Karte: Kopf, Notiz, Rumpf
  Zeile.tsx          Listenzeile: Haupt, Meta, Aktionen
  Reiter.tsx         Reiterleiste als Links auf eigene Routen
  Kachel.tsx         Kennzahl des Überblicks
  Zustand.tsx        art="leer" | "fehler" | "keinRecht" | "deaktiviert"
  bausteine.module.css
apps/web/app/einstieg/
  Einstieg.tsx       Wortmarke, zentrierte Karte, 28 px Rand
  einstieg.module.css
```

Drei Regeln trägt diese Schicht, statt sie zu wiederholen:

**`Seite` rendert kein `<main>`.** Das Layout tut es, genau einmal. Heute rendert das Layout `<main>{children}</main>` und jede Seite darin noch ein eigenes `<main className={styles.content}>` — jede Schreibtischseite hat damit zwei verschachtelte Hauptbereiche. Ein Baustein, der die Landmarke nicht mitbringt, macht den Fehler unmöglich, statt ihn achtmal zu reparieren.

**`Zustand` ist ein Baustein mit vier Spielarten, nicht vier Bausteine.** Die Regeln des Designsystems stehen in seinem Kommentar und damit an genau einer Stelle: *Leer* nennt den nächsten Schritt und nie eine Statistik aus Nullen. *Fehler* sagt, was falsch ist **und** was gilt. *Deaktiviert* ist nie stumm — daneben steht, was fehlt. `art="keinRecht"` ersetzt vier wörtlich gleiche Blöcke, die heute in `portal/page.tsx`, `leute/page.tsx`, `einstellungen/page.tsx` und dem Überblick stehen.

**`loading.tsx`, `error.tsx` und `not-found.tsx` je Bereich.** `not-found.tsx` schließt eine offene Flanke: `ladeKatalog` ruft bei einem `DomainError` `notFound()` auf, und das landet heute auf Nexts weißer Standardseite — mitten in einem Portal, das sonst durchgehend `#0a0b0d` ist.

**Was kein Baustein wird:** einmaliges Layout. Die Kachelreihe des Überblicks, die Sucherecken, die Anordnung der Reiter im Modell — das bleibt lokales CSS. Ein Baustein entsteht aus Wiederholung plus Regel, nicht aus Wiederholung allein.

---

## 2. Der Schnitt: acht Bauabschnitte

| | Abschnitt | Inhalt | Warum an dieser Stelle |
| --- | --- | --- | --- |
| **0** | Bausteine und Zustände | die Schicht aus Abschnitt 1, bewiesen an **einer** Seite (Tags) | alles sitzt darauf; eine Referenzseite statt acht Umschreibungen auf einmal |
| **1** | Einstieg | Anmelden, Registrieren, Verifizieren, Passwort vergessen, Passwort neu, Kein Studio | heute null Gestaltung, null Berührung mit Phase 4 — die Bausteine werden auf grüner Wiese hart |
| **2** | Wurzelseite `/` | Landeseite anonym, Mitgliedsbildschirm, gestaltetes Beitrittsformular | nutzt die Einstieg-Hülle aus 1; hier fällt der offene Punkt aus Fahrplan Abschnitt 6 |
| **3** | Rail und Zusammenlegung | sechs feste Einträge, drei Gruppen, Zahlen, Fußzeile; `/geraete` wird Modellliste, `/modelle` leitet, Stilllegen zieht in den Reiter | **die Kollisionsstelle mit Phase 4** — als ein Commit, damit der Rebase einen Konflikt hat statt acht |
| **4** | Listen | Überblick, Geräte, Tags | rendern in der Rail aus 3 |
| **5** | Detail und Reiter | Modell (4 Reiter), Leute (2), Einstellungen (2) | braucht die Reiterschicht aus 3; acht Bildschirme, parallelisierbar |
| **6** | Abgleich | 16 `Telefon*` gegen `halle.module.css`, `/t/<token>` gegen `fallback.module.css` | nur lesen und Befunde schreiben, kein Neubau |
| **7** | Kurse | nach Rebase auf gemergtes Phase 4 — sonst entfällt es mit Vermerk | Phase 4 baut sie parallel funktional auf |

### Warum Einstieg vor Rail

Naheliegend wäre, mit der Rail anzufangen: sie ist der größte Brocken und alles hängt darin. Dagegen steht der Rebase. Phase 4 fasst dieselbe Rail und dieselbe Route-Gruppe an — alles, was **vor** Abschnitt 3 entsteht, ist rebase-neutral, alles danach nicht. Einstieg und Wurzelseite sind acht Bildschirme, die Phase 4 nie berührt. Sie zuerst zu bauen kostet keine Reihenfolge und macht die Bausteine hart, bevor sie an der Kollisionsstelle ankommen.

### Die Zählung

Phase 5 gestaltet **neunzehn Bildschirme**, ohne Kurse:

| Abschnitt | Bildschirme | |
| --- | --- | --- |
| 1 | Anmelden, Registrieren, Verifizieren, Passwort vergessen, Passwort neu | 5 |
| 1 | Kein Studio — als Leer-Zustand von `/portal`, nicht als neue Route | 1 |
| 2 | Wurzelseite `/` — anonym, Mitglied, Mitglied ohne Studio | 1 |
| 2 | `/portal` Studiowahl bei mehreren Studios | 1 |
| 4 | Überblick, Geräte, Tags | 3 |
| 5 | Modell — vier Reiter | 4 |
| 5 | Leute — zwei Reiter | 2 |
| 5 | Einstellungen — zwei Reiter | 2 |

Abschnitt 7 brächte fünf weitere (Kurse, Kursvorlagen, Kursvorlage, Termin anlegen, Termin).

**`KeinStudio.dc.html` ist keine neue Route.** Das Artboard zerfällt sauber in zwei Hälften, die an zwei bestehende Stellen gehören: die obere — *„Dein Konto steht. Ein Studio muss dich noch als Mitarbeiter hinzufügen"* — ist der Leer-Zustand von `/portal`, der heute schon dort steht („Du pflegst noch keinen Katalog"). Die untere — *„Du wolltest trainieren? Trainieren läuft in der App"* — ist der Mitgliedsbildschirm auf `/`. Beide Hälften werden umgehängt, keine wird erfunden.

### Die Rail trägt keinen Kurse-Eintrag

Bis Abschnitt 7 läuft, fehlt er. Das ist keine Bequemlichkeit, sondern Designsystem §11: *„Ein leerer Tab ist ein Versprechen ohne Gegenwert."* Die Regel steht dort für den Plan-Tab der Member-App; sie gilt hier wörtlich genauso. Ein Eintrag *Kurse*, der auf eine 404 zeigt, ist schlechter als kein Eintrag — und ein deaktivierter Eintrag wäre nach derselben Regel ein Versprechen mit Datum, das niemand gegeben hat.

---

## 3. Zustände je Bildschirm

Struktur-Spec §5 lässt im Portal drei Zustände gelten — Leer, Fehler, Deaktiviert — plus Skelett für Medien; *Offline* gilt hier nicht. Dazu kommen zwei, die die Spec nicht nennt, weil sie beim Zeichnen nicht sichtbar waren:

| Zustand | Gilt wo | Form |
| --- | --- | --- |
| **Leer** | jede Liste | Überschrift plus nächster Schritt, nie eine Statistik aus Nullen |
| **Fehler** | jede Seite mit Abfrage | sagt, was falsch ist und was trotzdem gilt |
| **Deaktiviert** | jede Aktion mit Vorbedingung | nie stumm; daneben steht, was fehlt |
| **Medien laden** | Foto, Video | `surface-raised`-Block, das einzige Skelett |
| **Kein Recht** | jede Trainerseite | ein einfaches Mitglied sieht einen Satz, keinen Absturz |
| **Lädt** | jede Route | Titel und Vorspann sofort, Rumpf still |

*Kein Recht* ist kein neuer Zustand, sondern die benannte Fassung von etwas, das heute schon vier Mal ad hoc im Code steht. *Lädt* ist neu und ist Entscheidung 3.

**Die Rail selbst braucht einen Kein-Recht-Fall.** Ihre Zahl „24 Mitglieder · 4 Mitarbeiter" kommt aus `listStudioMembers`, und das wirft für ein einfaches Mitglied `unauthorized`. Ohne Abfangen zerbricht die gemeinsame Navigation an der Rolle — auf jeder Seite gleichzeitig. Die Rail zeigt die Zahl dann nicht, statt zu scheitern.

---

## 4. Fertig-Kriterium

Ein Bildschirm gilt als gestaltet, wenn sieben Dinge gelten. Sechs prüft eine Maschine, eines ein Auge.

**1. Der Weg dorthin ist gegangen, nicht gesprungen.** Je Bauabschnitt ein E2E-Gang von der Anmeldung bis zur Eingangsroute des Abschnitts, ohne `page.goto` auf das Ziel. Innerhalb eines Abschnitts darf ein Test springen.

Das ist die ehrliche Lesart der Lehre vom 3. September: die Lücke war, dass **kein** Test den menschlichen Weg ging — nicht, dass jeder ihn gehen muss. Verlangte man ihn von allen neunzehn Bildschirmen, kostete jeder eine volle Anmeldung, und die Suite würde so langsam, dass sie niemand mehr vor dem Commit laufen lässt. Eine Suite, die nicht läuft, findet nichts.

**2. Die Zustände stehen, bevor das Aussehen steht** — auf der Ebene, auf der sie ehrlich prüfbar sind. Vier gelten je Seite und werden hier geprüft; *Deaktiviert* und *Medien laden* gelten je Element und werden dort geprüft, wo das Element steht:

| Zustand | Ebene | Wie |
| --- | --- | --- |
| leer | E2E | Studio ohne Gerät, ohne Mitglied, ohne Tag |
| kein Recht | E2E | Mitgliedskonto auf einer Trainerseite; das Muster steht in `e2e/leute.spec.ts` |
| Fehler | Unit, plus ein echter Pfad | `Zustand art="fehler"`; echt beim Überblick, dessen `getStudioOverview` schon fehlschlagen kann |
| lädt | Unit | `loading.tsx` rendert den Titel |

*Lädt* bleibt bewusst aus dem E2E: ein Ladezustand im Browser ist ein Wettlauf gegen die Abfrage, und ein Test, der mal grün und mal rot ist, ist schlimmer als keiner. Das Repo hat mit `rls-workout-sessions` bereits einen davon.

**3. Rollen und Beschriftungen.** Genau eine `<main>`-Landmarke je Seite, die Rail mit Namen, jede Reiterleiste eine benannte `navigation`, jedes Feld mit Label. Der erste Punkt fällt heute auf jeder Schreibtischseite durch.

**4. Trefferflächen ≥ 44 px.** Ein Helfer misst per `boundingBox` alle bedienbaren Elemente einer Seite. Einmal geschrieben, überall benutzt.

**5. Genau eine Akzentfläche — gezählt, nicht beteuert.** Der Designplan nennt die Regel nicht verhandelbar, und sie ist zählbar: Elemente mit berechneter `background-color` gleich `#d4ff3f`. Erwartungswert je Seite, meist eins.

Für **Tags ist er null.** Die Canvas-Notiz `note-akzent` sagt es ausdrücklich: *„Die Tags-Seite hat seit dieser Runde gar keine mehr. Sie legt nichts an; sie gibt Auskunft. Null ist so richtig wie eins."*

Randfälle zählen nicht mit: die aktive Rail-Zeile ist eine 2-px-Kante, der Fokusring ein `outline`, die Sucherecken sind Ränder. Fläche ist Fläche.

**6. Sichtprüfung.** `run`-Skill, echte Seite im Browser, Screenshot gegen das Artboard. Nicht „sieht sicher gut aus".

**7. Die Suiten bleiben auf ihrem Stand:** 85 Unit, 460 von 461 Integration, 30 E2E im warmen Lauf. Wird einer rot, ist das eine Verhaltensänderung — und dann wird entschieden, welche Seite recht hat, statt den Test anzupassen.

### Was die Tests nicht tun

**Aussehen testet kein Test.** Keine Farbwerte, keine Pixelpositionen, keine Schriftgrößen in Zusicherungen. Geprüft werden Struktur, Zustände, Rollen, Maße und Zählungen. Ob ein Bildschirm gut aussieht, entscheidet der Vergleich mit dem Artboard — dafür gibt es kein `expect`, und der Versuch, eines zu schreiben, erzeugt nur eine Suite, die bei jeder Verschiebung um zwei Pixel rot wird.

---

## 5. Befunde

Neunundzwanzig Abweichungen zwischen Entwurf und laufender Oberfläche — fünfzehn beim Lesen gefunden, drei beim Schreiben des Umsetzungsplans, sechs beim Bauen und beim Vorabgleich der noch offenen Aufgaben. Keine wird still aufgelöst.

### Fehler im Code, hier zu heilen

1. **Doppelte `<main>`-Landmarke** auf jeder Schreibtischseite. Ausnahme ist `geraete/page.tsx` mit einem `<div>` — ausgerechnet die Datei, die nach Entscheidung 2 verschwindet.
2. **`notFound()` landet auf Nexts weißer Standardseite.** Es gibt nirgends im Web ein `not-found.tsx`.
3. **Die Rail zerbricht an der Rolle.** `listStudioMembers` wirft für ein Mitglied `unauthorized`; die Rail-Zahl braucht es.

### Fehler im Entwurf

Nach der Regel der Global Constraints. Alle vier betreffen den Einstieg — den Teil, der beim Zeichnen am weitesten vom Code entfernt war.

4. **`PasswortVergessen` zeichnet „Link anfordern".** Der Code schickt einen sechsstelligen Code. Der Code gewinnt, der Knopf heißt „Code anfordern".
5. **`PasswortNeu` fehlt das Codefeld.** Das Artboard zeigt *Neues Passwort* und *Wiederholen*; ohne den Code aus der Mail funktioniert der laufende Weg nicht. Umgekehrt hat der Code heute kein *Wiederholen* — das kommt vom Artboard dazu und ist eine Verbesserung, kein Fehler.
6. **`Verifizieren` zeichnet „Neuen Code anfordern".** Diesen Weg gibt es im Code nicht.
7. **Für *Stilllegen* zeichnet kein Artboard einen Ort.** `Modell.dc.html` zeigt unter *Einzelne Geräte* nur *Tag scannen* und *Tag ersetzen*, obwohl Struktur-Spec §1 das Stilllegen verlangt („ein Gerät wird stillgelegt, einzeln, mit Namen"). Im Code steht es bereits an der richtigen Stelle — Modell-Detail, Abschnitt *Geräte im Raum*. Der Entwurf ist unvollständig, nicht der Code; das Artboard wird beim Bauen um die Aktion ergänzt.
8. **Die flache Geräteliste hat kein Artboard.** Entfällt nach Entscheidung 2.

    **Korrektur vom 5. September — sie kostet doch etwas, und beim Bauen ist es aufgefallen.** Die ursprüngliche Fassung dieses Befunds sagte, die Löschung sei kostenlos, weil ihre beiden Aktionen — *Stilllegen* und *Wieder in Betrieb* — im Modell-Detail schon stehen. Das stimmt und wurde vor dem Löschen geprüft. Die Liste bot aber **zwei** Dinge, nicht eines: zusätzlich eine **modellübergreifende, nach Erreichbarkeit sortierte** Ansicht — der Rundgang durch den Raum, mit den Geräten ohne Tag zuoberst.

    Die gibt es jetzt nirgends: im Modell-Detail ist die Geräteliste unsortiert und an ein Modell gebunden. **Der Verlust ist gewollt und gedeckt** — Struktur-Spec §1, Entscheidung 5 verschiebt die Navigation ausdrücklich von Objekten auf Listenseiten, und der Überblick beantwortet die Frage „was fehlt noch" über seine Zeile *„N Geräte ohne Tag"*. Aber er ist ein Kompromiss, keine Nulloperation, und wurde als solcher zuerst falsch dargestellt.
9. **Die Wurzelseite behält das Beitrittsformular** gegen `note-einstieg`. Nach Entscheidung 1 — mit dem Auftrag, es zu streichen, sobald die iOS-App den Beitritt trägt.

### Regeln, die kollidieren

10. **Kein Kurse-Eintrag in der Rail** bis Abschnitt 7, nach Designsystem §11.
11. **`.progressBar` ist eine Akzentfläche.** Auf der Upload-Seite stehen damit zwei — Fortschrittsbalken und Hauptaktion. Entweder bekommt die Regel eine benannte Ausnahme, oder der Balken verliert den Akzent. Zu entscheiden in Abschnitt 6, nicht nebenbei.

### Werkzeug und Bestand

12. **Die Uhrendrift trifft eine ganze Testklasse, nicht einen Test.** Fahrplan Abschnitt 6 führt `rls-workout-sessions` als „sporadisch rot". Beides ist zu eng.

    Gemessen am 3. September, drei Messungen in Folge: die Uhr im Datenbankcontainer läuft der Node-Uhr **0,86 bis 0,88 Sekunden voraus** — konstant, nicht schwankend. Betroffen ist jeder Test, der einen Zeitstempel aus der Datenbank (`started_at default now()`) gegen einen aus Node (`new Date()`) setzt und dabei den Check `workout_sessions_completed_after_start` auslöst. Ob er fällt, hängt allein davon ab, ob sein Rundlauf kürzer als 0,87 s ist — also von der Maschinenlast.

    Beobachtet wurden bisher **drei** Tests in zwei Dateien: `rls-workout-sessions` (der bekannte) und zwei in `domain-complete-session`. Alle drei scheitern am **selben** Constraint. Die Zahl schwankt zwischen Läufen zwischen 458 und 460 von 461.

    **Folge für die Abnahme:** „460 von 461" ist kein brauchbares Tor. Bindend ist stattdessen: **jeder rote Integrationstest scheitert an `workout_sessions_completed_after_start`.** Scheitert einer an etwas anderem, ist es ein Regress. Bestand, nicht Phase 5 — dieser Bauabschnitt fasst `workout_sessions` nirgends an.
13. **Der erste E2E-Lauf in einem frischen Worktree kostet zwei Tests** an kaltem `.next`, genau wie der Kommentar in `playwright.config.ts` beschreibt. Er zählt nicht.
14. **Die Rail-Fußzeile bringt einen zweiten Abmelden-Ausgang** neben dem unter *Einstellungen → Konto*. Beide Artboards zeigen beide — Absicht, kein Versehen.
15. **`/portal` hat kein Artboard.** Die Studiowahl bei mehreren Studios ist ungezeichnet; im Normalfall — genau ein Studio — leitet die Route weiter und wird nie gesehen. Sie wird nach Bausteinen gestaltet, nicht nach Vorlage. Ihr Leer-Zustand dagegen ist gezeichnet: das ist die obere Hälfte von `KeinStudio.dc.html`.

20. **Der Gerätekatalog ist für Mitglieder auf Datenbankebene sichtbar — die Seite ist die einzige Sperre.** Am 5. September beim Bauen von Aufgabe 15 aufgefallen, nachdem ich in Plan und Brief das Gegenteil behauptet hatte.

    Ich schrieb, `getStudioCatalog` liefere einem Mitglied „schlicht weniger Zeilen", RLS filtere also still. **Das stimmt nicht.** Nachgesehen in den Migrationen:

    ```sql
    -- 0004_equipment_models.sql:41 und 0007_machines.sql:20
    using (public.is_studio_member(studio_id));
    ```

    `is_studio_member`, nicht `is_studio_staff`. Ein Mitglied bekommt **dieselben** Katalogzeilen wie ein Trainer.

    Die Sperre auf `/geraete` bleibt richtig — Überblick, Leute und Einstellungen sperren sich alle selbst, obwohl RLS weiter zulässt. Aber die Lage ist umgekehrt zu dem, was ich behauptet hatte: **nicht die Datenbank schützt und die Seite ergänzt, sondern die Seite schützt allein.** Wer das falsch im Kopf hat, verlässt sich beim nächsten Bildschirm auf einen Schutz, den es nicht gibt.

    Das ist kein Fehler dieser Phase — der Katalog *soll* für Mitglieder lesbar sein, die Member-App braucht ihn. Es ist ein Fehler in meiner Beschreibung gewesen.

21. **Die Kein-Recht-Weiche auf `/geraete` hängt an einer Abfrage über *Leute*.** `railZahlen().mitglieder === null` bedeutet wörtlich *„`listStudioMembers` hat `unauthorized` geworfen"* — nicht *„darf den Katalog nicht sehen"*. Beides fällt heute zusammen, weil beide an derselben Rolle hängen; das ist Zufall der aktuellen Rollenmatrix, kein erzwungener Zusammenhang. Käme eine feinere Rolle dazu („nur Geräte, nicht Leute"), bräche die Weiche **lautlos** in die falsche Richtung — kein Typfehler, kein roter Test. Im Code als bewusste Zwischenlösung markiert; aufzulösen, sobald sich die Rollen auffächern.

### Drei, die beim Schreiben des Umsetzungsplans dazukamen

16. **Die Global Constraints widersprechen sich bei den Trefferflächen.** Ein Satz sagt *„Trefferflächen ≥ 44 px; Hauptaktion 44 px hoch, **Nebenaktion 40 px**"*. Beides zugleich geht nicht. `portal.module.css` setzt `.secondary` und `.destructive` auf `height: 40px`, und die Artboards zeichnen 40 — Code und Entwurf sind sich also einig, nur der Satz nicht. Die Herkunft ist erkennbar: die 44 stammt aus Designsystem §4, und die gilt für die Member-App, wo einhändig im Halbdunkel bedient wird. Am Schreibtisch liegt eine Maus.

    **Entschieden am 3. September: 40 px gilt am Schreibtisch weiter.** Die Regel lautet damit genauer: **Hauptaktion 44 px, Nebenaktion und zerstörende Aktion 40 px, Eingabefeld 44 px.** Die „≥ 44 px" der Member-App bleibt dort, wo sie hergeleitet ist — in der Halle. Der Prüfhelfer nimmt 40 als Mindesthöhe für Bedienelemente des Portals; die Zahl bleibt ein Parameter, damit die Hallenseiten unter `einrichten/` mit ihrem eigenen, größeren Wert geprüft werden können (`halle.module.css`: Hauptaktion 56, Nebenaktion 48, Feld 52).
17. **Der Satz unter dem Registrierungsformular stimmt für das Web nicht.** `Registrieren.dc.html` sagt *„Ein Konto allein reicht nicht — du brauchst danach den Code deines Studios."* Der Code macht Mitglieder; im Web wird man Mitarbeiter, und Mitarbeiter fügt ein Studio unter *Leute → Mitarbeiter* hinzu. Die Canvas-Notiz `note-einstieg` sagt das selbst — der Artboard-Text ist ihr gegenüber älter.
18. **`portal.module.css` `.error` trägt die Regel des falschen Zustands.** Die Klasse setzt `background: rgba(255, 90, 78, 0.1)` — eine 10-prozentige `danger`-Fläche. Designsystem §5 ordnet die aber **Offline** zu, nicht *Fehler*; *Fehler* ist dort „`danger`-Umriss, **voller Kontrast**". Und Offline gilt im Portal ausdrücklich nicht (Struktur-Spec §5). Das Artboard `Zustaende.dc.html` bestätigt es: die Fehler-Karte steht auf `#14161a`, und in der ganzen Datei kommt kein `rgba` vor.

    Zwei von drei Quellen sind sich also einig, und die dritte ist der laufende Code. Der neue Baustein folgt Spec und Artboard: `danger`-Rand auf `surface`, keine Tönung. `.error` bleibt vorerst, wie es ist — es wird von `Form.tsx` und mehreren Seiten benutzt und löst sich auf, wenn diese Seiten in den Aufgaben 5 und 14–20 auf den Baustein wechseln. **Bis dahin zeigt das Portal zwei verschiedene Fehlerflächen.**

19. **Die Produktgrenze steht in einem Kontrast, den das Designsystem für sie verbietet.** Designsystem §2: *„`text-faint` ist damit nur für Text ≥ 15 pt oder nicht-tragende Information zulässig — **nie für etwas, das gelesen werden muss**."* Designsystem §10 erklärt genau diesen Satz für verbindlich und sichtbar. Gemessen an drei Stellen, alle in `text-faint` (3,6 : 1):

    | Ort | Wie |
    | --- | --- |
    | `Start.dc.html`, Fußzeile | `13px`, `#5c636e` |
    | `(schreibtisch)/page.tsx:304` über `.hint` | `12px`, `var(--text-faint)` |
    | `t/[token]/page.tsx:230` über `.grenze` | `13px`, `var(--text-faint)` |

    **Hier greift die übliche Schlichtungsregel nicht.** Sonst gewinnt bei Streit zwischen Entwurf und laufender Oberfläche der Code — aber hier weichen Artboard **und** Code gemeinsam ab, es gibt kein Korrektiv. Damit ist das Designsystem die einzige normative Quelle, die den Fall regelt, und es ist eindeutig. Es geht dabei um den Satz, der sagt, dass gymodo nichts misst und keine Gesundheitsempfehlung gibt.

    **Kleinster Eingriff:** Token-Tausch `--text-faint` → `--text-muted` (7,4 : 1), Größe und Layout unverändert, eine Zeile je Datei. **Nicht einzeln reparieren** — eine von drei Stellen zu heilen erzeugt Inkonsistenz, ohne den systemischen Fehler zu lösen. Stattdessen ein Baustein `Produktgrenze`, der Wortlaut und Kontrast an einer Stelle trägt: Wiederholung **plus** Regel, das Kriterium aus Abschnitt 1. Fällig in Aufgabe 14 (Überblick); `/t/<token>` zieht Aufgabe 21 nach.

20. **Der Vorbehalt zur Datenschutzgrenze ist seit `0033` überholt — an zwei Stellen, nicht einer.** Beide Artboards tragen ihn:

    | Ort | Wortlaut |
    | --- | --- |
    | `LeuteMitglieder.dc.html`, Fußzeile | *„Heute lassen die Richtlinien der Datenbank Mitarbeiter noch an Sätze, Gewichte und Verläufe heran; das Portal zeigt sie nirgends, verhindert ist es damit aber nicht."* |
    | `LeuteMitarbeiter.dc.html`, Untertitel | *„Zugriff auf alles außer den Trainingsdaten der Mitglieder — so ist es gedacht; die Datenbank setzt diese Grenze noch nicht durch."* |

    `0033_datenschutzgrenze.sql` nimmt vier Policies (aus `0012` bis `0015`) die Klausel `or public.is_studio_staff(...)`; seither gilt `user_id = auth.uid()`. Der Vorbehalt beschreibt etwas, das es nicht mehr gibt, und macht die Zusicherung **schwächer als die Wirklichkeit**. Ersatz für beide: *„Trainingsdaten eines Mitglieds sieht nur das Mitglied selbst. Das Portal legt eine Mitgliedschaft an und beendet sie, sonst nichts."*

    **Nicht absoluter formulieren als das.** `0034` legt `studio_overview` an, die Personal weiterhin **Summen** über das Studio herausgibt — der Überblick lebt davon. Je *Person* sieht Personal nichts; *„das Portal zeigt keine Trainingsdaten"* wäre falsch. **Fällig in Aufgabe 19.**

21. *(steht weiter oben, bei den Befunden aus dem Bauen)*

22. **Ein Trainer kann sich selbst zum Mitglied zurückstufen — und verliert damit das ganze Portal.** `LeuteActions.tsx:44` bietet den Knopf auf jeder Nicht-Inhaber-Zeile an, auch auf der eigenen. Der Inhaber ist doppelt geschützt: `setMembershipRole` nimmt `owner` als Zielrolle gar nicht an, und die Zeile des Inhabers ist von der Richtlinie ausgenommen (`„Diese Mitgliedschaft gibt es nicht, oder sie gehoert dem Inhaber."`). Für die eigene Trainerzeile gibt es keinen solchen Schutz — weder im Web noch in der Domäne. Das Artboard `LeuteMitarbeiter.dc.html` löst es an der Oberfläche: die eigene Zeile trägt *Das bist du* statt eines Knopfes. **Fällig in Aufgabe 19.** Die Seite kennt den eigenen Nutzer heute nicht; sie holt ihn über `client.auth.getUser()` wie `konto/page.tsx:23`. Keine Domain-Änderung, keine Migration.

23. **Die Bestätigung beim Rollenwechsel trägt die Regel nicht, die sie tragen soll.** `LeuteActions.tsx:45` fragt `„Wirklich?"`. Struktur-Spec §2 verlangt für die Mitarbeiterliste ausdrücklich eine *bestätigte Handlung beim Hochstufen* — und das Artboard hat den Satz schon: *„Hochstufen gibt Zugriff auf den ganzen Katalog. Der Studio-Code macht niemanden zum Trainer."* Eine Bestätigung, die nur „Wirklich?" sagt, ist ein Klick mehr ohne eine Information mehr. **Fällig in Aufgabe 19.**

24. **ASCII im sichtbaren deutschen Text, zweimal gefunden.** `LeuteActions.tsx:44` zeigt *„Zu Mitglied zurueckstufen"*; in Aufgabe 16 stand *„unveraendert"* im Hinweis unter dem Fotofeld (behoben in `8d8d976`). Beide Male war die Regel *ASCII nur in Kommentaren* eingehalten worden, wo sie leicht fällt, und übersehen, wo der Text angezeigt wird. Der Rest von `LeuteActions.tsx` ist davon frei — es ist ein einzelnes Wort, nicht ein Muster der Datei. **Fällig in Aufgabe 19.**

25. **Das Zahlenfeld *Anzahl im Studio* beschreibt eine Bedienung, die es nicht gibt.** `Modell.dc.html` zeichnet eine Stückzahl und einen Knopf *Geräte anlegen*: *„Erhöhen legt die fehlenden Geräte an — Nummer, Standort und Tag vergibst du danach am Gerät, mit dem Telefon."* Der Code legt je Gerät einzeln an, mit *Bezeichnung* und *Standort*. **Der Code gewinnt, und nicht aus Bequemlichkeit:** `machines.label` ist `not null` mit `check (length(trim(label)) > 0)` (0007). Ein Massenanlegen ohne Nummer bräuchte ein Nummernschema in der Datenbank — eine Migration, und Phase 5 macht keine. Der zweite Satz des Artboards (*„Verringern gibt es nicht: ein Gerät wird stillgelegt, einzeln, mit Namen."*) gilt dagegen unverändert und steht so im Code. **Vertagt**, kein Gestaltungs-, sondern ein Verhaltensentwurf.

26. **Zwei Wörter für dieselbe Größe.** Der Modell-Reiter *Einzelne Geräte* schreibt heute `Rückwand links · 1 aktiver Tag`, die Modellliste auf `/geraete` schreibt für dieselbe Sache *„1 Gerät, 1 erreichbar"* (`erreichbarkeit()` in `catalog.ts`). Das Artboard hat *erreichbar* an beiden Stellen. Hinzu kommt ein Testproblem: *„1 aktiver Tag"* und *„kein aktiver Tag"* sind für `toContainText("aktiver Tag")* nicht unterscheidbar — genau die stumpfe Zusicherung, die in dieser Phase schon einmal aufgetreten ist. **Fällig in Aufgabe 18.**

27. **Neun Revalidierungspfade zeigen seit Aufgabe 16 auf eine Weiterleitung.** `portal/actions.ts` revalidiert in neun Aktionen `/portal/<id>/modelle/<modelId>` (Zeilen 101, 118, 138, 165, 176, 198, 208, 246, 260). Diese Route ist seit Aufgabe 16 nur noch ein `redirect`. Dass die Bildschirme trotzdem frisch aussehen, liegt daran, dass Next die angezeigte Route ohnehin auffrischt — nicht an dieser Zeile. Richtig ist `/portal/<id>/geraete/<modelId>` **als Layout**: die vier Reiter sind vier Routen unter einem gemeinsamen Layout, und der Standardtyp `page` träfe nur die Stammdaten. **Fällig in Aufgabe 18**, mit einem Test, der an der Reiterzahl im Layout misst, nicht an der Liste.

28. **Zwei Aktionsdateien mit identischen Exportnamen und teils anderen Signaturen.** `apps/web/app/portal/actions.ts` (Schreibtisch) und `apps/web/app/portal/[studioId]/einrichten/actions.ts` (Halle) exportieren beide `parameterAnlegen`, `parameterLoeschen`, `uebungAnlegen`, `uebungVerschieben` — getrennt implementiert, und `uebungVerschieben` nimmt in der Halle eine andere Parameterliste (`studioId, machineId, modelId, reihenfolge`). Gefunden vom Implementierer der Aufgabe 17, nachdem **mein** Brief behauptet hatte, `einrichten.spec.ts` sei ein Netz für die Schreibtisch-Aktionen. Ist es nicht: kein Testlauf deckt heute beide Fassungen, und ein Import aus der falschen Datei ist ein Tippfehler ohne Typfehler. **Vertagt** — eine Zusammenlegung ist ein Umbau der Aktionsschicht, keine Gestaltungsfrage, und Phase 5 fasst die Aktionen nicht an.

29. **`.sectionNote` trägt denselben verbotenen Kontrast wie die Produktgrenze.** Die Klasse setzt `font-size: 12px` mit `color: var(--text-faint)` (`portal.module.css:193`) und trägt die erklärenden Sätze unter den Abschnittsüberschriften — *„Was ein Mitglied am Gerät einstellt und sich merken soll."*, *„Die Reihenfolge bestimmt, was am Gerät zuerst vorgeschlagen wird."* Das sind tragende Sätze, keine Nebeninformation; Designsystem §2 verbietet `text-faint` dafür (siehe Befund 19). Der Implementierer der Aufgabe 17 ist der Falle ausgewichen, indem er für die neuen Reiter `.pageLead` (`--text-muted`) genommen hat — die **Klasse** bleibt aber unrepariert und wird beim nächsten Bildschirm wieder gegriffen. **Fällig in Aufgabe 21**, zusammen mit den beiden restlichen Orten aus Befund 19.

---

## 6. Was der Entwurf schon beantwortet

**Der Mitgliedsbildschirm auf `/` ist nicht ungezeichnet** — er ist die untere Hälfte von `KeinStudio.dc.html`. Die Aufteilung dieses Artboards steht in Abschnitt 2 unter *Die Zählung*.

**Phase 5 braucht keine Migration.** Alle Rail-Zahlen kommen aus `getStudioCatalog` und `listStudioMembers`, `abmelden` steht in `portal/actions.ts:473`. Die Nummern bleiben bei `0034`; Session 1 behält `0035ff`.

---

## 7. Was Phase 5 nicht anfasst

- **Die Kurse-Routen.** Phase 4 baut sie parallel funktional auf `phase4-kurse`. Abschnitt 7 gestaltet sie nach einem Rebase auf den dann gemergten Stand — oder er entfällt, und der Plan schreibt auf, was offen bleibt.
- **Die 16 `Telefon*`-Bildschirme.** Gebaut und gestaltet in Phase 3. Abschnitt 6 gleicht ab und hält Abweichungen als Befund fest; er baut nicht neu.
- **`/t/<token>`.** Trägt seit dem Medienplan ein eigenes Stylesheet nach Member-Maßen. Ebenfalls nur Abgleich.
- **Die Member-App.** Phase 6, eigener Strang.

---

## 8. Offene Punkte

- **Die Akzentregel gegen den Fortschrittsbalken** (Befund 11). Braucht eine Entscheidung, bevor Abschnitt 6 abgenommen wird.
- **„Neuen Code anfordern" auf `Verifizieren`** (Befund 6). Entweder der Weg wird gebaut — das Backend trägt ihn — oder der Link fällt und der Befund bleibt stehen. Eine Registrierung ohne zweiten Code ist eine Falle derselben Art wie ein Passwortlogin ohne Zurücksetzen.
- **Wann das Beitrittsformular aus dem Web verschwindet** (Befund 9). Auslöser ist die iOS-App, nicht ein Datum.
- **Die Uhrendrift im Container** (Befund 12). Verrauscht jede Abnahme, gehört aber nicht Phase 5. Der Plan nennt sie, damit sie beim nächsten grünen Anspruch nicht als neu gilt.
- ~~**Trefferfläche 44 oder 40**~~ (Befund 16) — **entschieden am 3. September:** 40 px am Schreibtisch, 44 px für die Hauptaktion. Die Begründung steht beim Befund.

---

## 9. Der Umsetzungsplan

`../plans/2026-09-03-portal-frontend.md` — 23 Aufgaben in acht Bauabschnitten. Er trägt die Zuordnung, welcher Befund in welcher Aufgabe landet.
