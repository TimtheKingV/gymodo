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

Zweiundvierzig Abweichungen zwischen Entwurf und laufender Oberfläche — fünfzehn beim Lesen gefunden, drei beim Schreiben des Umsetzungsplans, sechs beim Bauen und beim Vorabgleich der noch offenen Aufgaben. Keine wird still aufgelöst.

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

    **Entschieden am 5. September (Aufgabe 21): der Balken behält den Akzent, und die Regel bekommt ihre Grenze gesagt.** Drei Gründe, in dieser Reihenfolge:

    1. **Der Entwurf sagt es selbst.** `TelefonVideo.dc.html` zeichnet den Balken in `#d4ff3f` — und `TelefonUploads.dc.html` zeigt **drei** solche Balken gleichzeitig, die Warteschlange. Das ist kein Versehen an einer Stelle, sondern eine bewusste, wiederholte Setzung. Artboard und Code sind sich einig; es gibt hier keinen Streit zu schlichten.
    2. **Die Regel nennt ihren eigenen Zweck, und er trifft nicht zu.** Designsystem §5.1: *„Der Akzent markiert die eine Hauptaktion und den aktiven Wert. […] der Nutzer verliert die Fähigkeit, im Halbdunkel in einer Sekunde zu erkennen, wo er hinfassen muss."* Ein Fortschrittsbalken ist nichts, wohin man fasst. Er konkurriert nicht mit der Hauptaktion um den Griff, sondern sagt, dass gerade etwas läuft.
    3. **Der Widerspruch ist ohnehin nur einen Moment lang sichtbar.** Der Balken rendert nur während eines laufenden Uploads; im Ruhezustand steht er nicht im Dokument. Die maschinelle Abnahme (`akzentflaechen()` in `e2e/helpers/abnahme.ts`) sieht ihn deshalb nie — nicht weil sie ihn übersieht, sondern weil es ihn dann nicht gibt.

    **Die Regel liest sich ab jetzt so:** genau eine Akzent*fläche* je Bildschirm unter den **bedienbaren** Flächen. Ränder zählten schon vorher nicht (aktive Rail-Zeile, Fokusring, Sucherecken); Fortschritt zählt ebenso wenig. Kein Codewechsel, kein Testwechsel — nur eine benannte Ausnahme statt einer stillen.

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

    **Nachtrag vom 5. September: nur die Hälfte war behoben.** Der neue `Zustand`-Baustein wurde von Anfang an ohne die Fläche gebaut, und damit galt der Befund als erledigt. Er war es nicht — `portal.module.css:389` trägt sie weiter, und `.error` hängt an **acht** Stellen, darunter `Form.tsx` (Zeile 36 und 85), also an **jeder Formularfehlermeldung des Portals**. Der `Zustand`-Baustein deckt die Zustandsflächen ab, nicht die Fehlermeldung unter einem Feld.

    **Die Halle macht es bereits richtig:** `halle.module.css:275` setzt für `.fehler` nur `color: var(--danger)`, keine Fläche. Derselbe Fehlerzustand, zwei Behandlungen, und das Designsystem nennt die der Halle als die richtige. **Fällig in Aufgabe 21** — eine Zeile, danach die Stellen sichtprüfen. `.destructive:hover` benutzt dasselbe `rgba` und **bleibt**: ein Interaktionszustand ist kein Statusfeld.

    **✅ Behoben in Aufgabe 21** (`a23926d`). Zwei Korrekturen dabei: es sind **sieben** Aufrufer, nicht acht (`Form.tsx` 36 und 85, `VideoUpload.tsx:171`, `EinstellungenActions.tsx:88`, `einstellungen/page.tsx:69`, `LeuteActions.tsx:162`, `TagBinden.tsx:38`) — die Acht war ungezählt. Und *keine Tönung* heißt nicht *keine Fläche*: der erste Eingriff strich die Zeile und erzeugte `transparent`. Richtig ist `background: var(--surface)`, wie `Zustaende.dc.html` die Fehlerkarte auf `#14161a` zeichnet und wie die beiden Geschwister `.fehler` und `.fehlermeldung` es längst tun. Der Test in `einstellungen.spec.ts` hat es gefangen.

    Zwei von drei Quellen sind sich also einig, und die dritte ist der laufende Code. Der neue Baustein folgt Spec und Artboard: `danger`-Rand auf `surface`, keine Tönung. `.error` bleibt vorerst, wie es ist — es wird von `Form.tsx` und mehreren Seiten benutzt und löst sich auf, wenn diese Seiten in den Aufgaben 5 und 14–20 auf den Baustein wechseln. **Bis dahin zeigt das Portal zwei verschiedene Fehlerflächen.**

19. **Die Produktgrenze steht in einem Kontrast, den das Designsystem für sie verbietet.** Designsystem §2: *„`text-faint` ist damit nur für Text ≥ 15 pt oder nicht-tragende Information zulässig — **nie für etwas, das gelesen werden muss**."* Designsystem §10 erklärt genau diesen Satz für verbindlich und sichtbar. Gemessen an drei Stellen, alle in `text-faint` (3,6 : 1):

    | Ort | Wie | Stand |
    | --- | --- | --- |
    | `Start.dc.html`, Fußzeile | `13px`, `#5c636e` | Artboard, bleibt |
    | `(schreibtisch)/page.tsx` über `.hint` | `12px`, `var(--text-faint)` | ✅ behoben in Aufgabe 14 (Baustein `Produktgrenze`) |
    | `t/[token]/page.tsx` über `.grenze` | `13px`, `var(--text-faint)` | ✅ behoben in Aufgabe 21 (`a23926d`) |
    | `app/page.tsx` (Landeseite) über `.fuss` | `13px`, `var(--text-faint)` | ✅ behoben in Aufgabe 21 (`a23926d`) |

    **Nachtrag vom 5. September: es waren nie drei Orte, es sind vier.** Die Landeseite kam in Aufgabe 10 dazu und trägt die Produktgrenze ebenfalls in `text-faint`. Der Implementierer hat das damals **nicht übersehen**, sondern bewusst so gebaut und in einem sieben Zeilen langen Kommentar begründet: das Artboard setze es so, und er übernehme es wörtlich, statt eigenmächtig aufzuhellen. Das war die richtige Haltung an der falschen Stelle — die Schlichtungsregel greift hier ja gerade nicht, weil Artboard und Code gemeinsam abweichen. **Beide offenen Orte fällig in Aufgabe 21.**

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

27. **Neun Revalidierungspfade zeigten seit Aufgabe 16 auf eine Weiterleitung — und die Korrektur ist Lesbarkeit, nicht Verhalten.** `portal/actions.ts` revalidierte in neun Aktionen `/portal/<id>/modelle/<modelId>`, eine Route, die seit Aufgabe 16 nur noch ein `redirect` ist. Umgestellt auf `/portal/<id>/geraete/<modelId>` als `"layout"` (Aufgabe 18, `e12aebd`); `fuehreAus` nimmt dafür einen dritten Parameter mit Standardwert `"page"`, die acht übrigen Aufrufer bleiben unverändert.

    **Die ursprüngliche Fassung dieses Befunds behauptete mehr, als stimmt.** Sie sagte, der Standardtyp `page` träfe nur die Stammdaten, und verlangte einen Test, der ohne die Layout-Angabe rot ist. Der Implementierer hat es dreimal gemessen: toter Pfad → grün, `revalidatePath("/voellig-woanders")` → grün, **gar kein `revalidatePath`** → rot. Next frischt den ganzen angezeigten Baum auf, sobald eine Aktion *irgendeine* Revalidierung meldet — `createServerSupabaseClient` liest Cookies, damit ist jede beteiligte Route dynamisch (kein Full Route Cache), und `staleTimes.dynamic` ist in Next 15 null. Vom Prüfer am Code bestätigt.

    Der Test ist geblieben (er sichert die Frische von Liste **und** Reiterzahl), aber sein Kommentar sagt jetzt, dass es für die Pfadwahl keinen Zeugen gibt. **Die Umstellung bleibt richtig** — ein Pfad, der auf eine Weiterleitung zeigt, ist irreführend für jeden, der ihn liest — aber sie behebt keinen Fehler, und der Commit nennt sie deshalb `refactor`, nicht `fix`.

28. **Zwei Aktionsdateien mit identischen Exportnamen und teils anderen Signaturen.** `apps/web/app/portal/actions.ts` (Schreibtisch) und `apps/web/app/portal/[studioId]/einrichten/actions.ts` (Halle) exportieren beide `parameterAnlegen`, `parameterLoeschen`, `uebungAnlegen`, `uebungVerschieben` — getrennt implementiert, und `uebungVerschieben` nimmt in der Halle eine andere Parameterliste (`studioId, machineId, modelId, reihenfolge`). Gefunden vom Implementierer der Aufgabe 17, nachdem **mein** Brief behauptet hatte, `einrichten.spec.ts` sei ein Netz für die Schreibtisch-Aktionen. Ist es nicht: kein Testlauf deckt heute beide Fassungen, und ein Import aus der falschen Datei ist ein Tippfehler ohne Typfehler. **Vertagt** — eine Zusammenlegung ist ein Umbau der Aktionsschicht, keine Gestaltungsfrage, und Phase 5 fasst die Aktionen nicht an.

29. **`.sectionNote` trägt denselben verbotenen Kontrast wie die Produktgrenze.** Die Klasse setzt `font-size: 12px` mit `color: var(--text-faint)` (`portal.module.css:193`) und trägt die erklärenden Sätze unter den Abschnittsüberschriften — *„Was ein Mitglied am Gerät einstellt und sich merken soll."*, *„Die Reihenfolge bestimmt, was am Gerät zuerst vorgeschlagen wird."* Das sind tragende Sätze, keine Nebeninformation; Designsystem §2 verbietet `text-faint` dafür (siehe Befund 19). Der Implementierer der Aufgabe 17 ist der Falle ausgewichen, indem er für die neuen Reiter `.pageLead` (`--text-muted`) genommen hat — die **Klasse** bleibt aber unrepariert und wird beim nächsten Bildschirm wieder gegriffen. **Fällig in Aufgabe 21**, zusammen mit den beiden restlichen Orten aus Befund 19.

### Aus dem Abgleich der Halle und des Fallbacks (Aufgabe 21)

Verfahren: aus jedem der 16 `Telefon*`-Artboards und den drei `Fallback*`-Artboards die Textknoten ab 35 Zeichen gezogen und gegen den gesamten `apps/web/app`-Baum gesucht. Der Großteil der Treffer war Beispieldatenmaterial (*„Technogym · 2 Geräte · 2 Übungen"*, *„Charge 7 · geliefert Mi., 12. August 2026"*) oder Umformulierung — beides kein Befund. Übrig bleiben fünf.

**Die 16 Telefon-Bildschirme werden nicht angefasst.** Sie sind in Phase 3 gebaut und gestaltet; 30 bis 32 sind aufgeschrieben, nicht behoben.

30. **`TelefonUebungNeu` erklärt die Reichweite einer Übung, der Code nicht.** Fehlender Satz: *„Die Übung steht danach dem ganzen Studio zur Verfügung und lässt sich an weitere Modelle hängen."* Das ist keine Verzierung: `createExercise` nimmt eine `studioId`, `attachExerciseToModel` hängt sie danach an ein Modell — die Übung gehört dem Studio, nicht dem Gerät, an dem sie entstand. Wer das nicht weiß, legt sie ein zweites Mal an. **Aufgeschrieben, nicht behoben.**

31. **`TelefonUebungen` verspricht die Wiederaufnahme des Uploads, und der Code hält sie — sagt es aber nicht.** Fehlender Satz: *„Bricht die Verbindung ab, setzt der nächste Versuch hier fort — er fängt nicht von vorn an."* `VideoUpload.tsx:89` ruft `resumeFromPreviousUpload`, die Zusage stimmt also. In einer Halle mit schlechtem Empfang ist das genau der Satz, der einen Trainer nicht abbrechen lässt. **Aufgeschrieben, nicht behoben.**

32. **`TelefonUploads` beschreibt eine Warteschlange, die es so nicht gibt.** Der Satz *„Fotos gehen vor den Videos: sie sind klein, und ohne Foto erkennt niemand das Gerät"* setzt eine gemeinsame Schlange voraus. Die gibt es nicht: `Uploads.tsx` führt eine reine Videoschlange (`Auftrag` trägt `modelId`, `linkId`, bestätigt über `videoBestaetigen`), Fotos laufen über die Server-Aktion `fotoHochladen` und stehen nie darin. Der Effekt stimmt zufällig — ein Foto ist synchron und klein und damit faktisch zuerst durch — aber der Mechanismus, den der Satz erklärt, existiert nicht. **Hier ist der Entwurf falsch, nicht der Code.** Aufgeschrieben, nicht behoben.

*Nicht neu:* `TelefonFertig` zeichnet den Probe-Scan (*„Zeigt dir, was ein Mitglied sieht, wenn es hier ankommt."*), und der fehlt im Code. Das steht bereits als offener Punkt im Gesamtfahrplan Abschnitt 6 — er bräuchte den Klartext-Token, den `0026` dem Portal entzieht.

**`/t/<token>` gehört anders als die Telefon-Bildschirme zum Auftrag dieser Phase** (der Auftrag nennt die Fallback-Seite ausdrücklich unter dem, was zu gestalten ist). Beide folgenden Befunde sind Halbsätze, und in beiden Fällen fehlt die Hälfte, die trägt.

33. **`FallbackInaktiv`: der Satz sagt, wohin man sich wendet, aber nicht wozu.** Code (`t/[token]/page.tsx:71`): *„Bitte wende dich an dein Studio."* Artboard: *„Wende dich an dein Studio — dort kann der Aufkleber neu vergeben werden."* Der zweite Halbsatz sagt, dass das Problem lösbar ist und wie. Ohne ihn liest sich die Seite wie eine Sackgasse.

    **✅ Behoben in Aufgabe 21** (`a23926d`), Wortlaut zeichengenau nach `FallbackInaktiv.dc.html`.

34. **`FallbackGeraet`: der Android-Nutzer erfährt nicht, dass er nichts verpasst.** Artboard: *„Zurzeit nur für iPhone. Die Einweisung oben funktioniert auf jedem Gerät und ohne App.“* Der Satz ist der wichtigere von beiden: die Seite ist genau für den Fall gebaut, dass jemand ohne App vor dem Gerät steht — der Kommentar im Kopf der Datei sagt es selbst (*„Der Nutzen kommt vor der Installationsaufforderung — auch auf Android, wo es die App nicht gibt“*). Der Code hält sich an diese Absicht in der Anordnung und widerspricht ihr im Wortlaut.

    **Korrektur vom 6. September (Aufgabe 21): der Ortsverweis war falsch, und damit auch der Eingriff.** Der Befund nannte Zeile 146 als die halbierte Stelle. Zeile 146 steht aber im **Aushang**-Zweig, und `FallbackAushang.dc.html` zeichnet dort genau *„Zurzeit nur für iPhone.“* — ohne Zusatz, und aus gutem Grund: über einem Aushang steht keine Einweisung, auf die sich *„oben“* beziehen könnte. **Dort ist der Code richtig und bleibt unverändert.**

    Der Satz gehört in den **Geräte**-Zweig, unter `.zweiterScan` — dieselbe Stelle, an der `FallbackGeraet.dc.html` ihn zeichnet. Und dort fehlt er nicht zur Hälfte, sondern **ganz**: der Gerätebildschirm trägt überhaupt keine Fußnote. Aus einem halben Satz wird damit ein neuer Absatz.

    Derselbe Fehler wie bei Ruling 29, nur spiegelverkehrt: dort wurde *fehlt* behauptet, wo etwas in falscher Form vorhanden war; hier wurde *halbiert* behauptet, wo an der genannten Stelle nichts fehlt und an einer ungenannten alles. Beide Male hätte ein Blick ins **Markup** des Artboards statt in seinen Fließtext es gezeigt — die Lektion aus Ruling 27, hier zum zweiten Mal fällig.

    **Folge für den Kontrast:** `.fussnote` steht auf `11px` in `--text-faint`. Für *„Zurzeit nur für iPhone.“* allein ließe sich das noch als nicht-tragende Nebeninformation lesen; den neuen Satz — den dieser Befund selbst *„den wichtigeren“* nennt — in den verbotenen Kontrast zu setzen, wäre absurd. `.fussnote` wandert deshalb mit auf `--text-muted`, als vierte Stelle zu Befund 19. Die Größe bleibt bei `11px`: so zeichnet es das Artboard, und die Größe ist hier nicht der Streitpunkt.

### Aus dem Bau der Rechteverwaltung (Aufgabe 19)

35. **Der Riegel gegen die Selbstherabstufung fehlt in der Richtlinie, nicht nur in der Oberfläche — und die Schwesterrichtlinie hat ihn.** Befund 22 ist in Aufgabe 19 **verdeckt**, nicht behoben: die eigene Zeile trägt jetzt *Das bist du* statt eines Knopfes. Ein direkter Aufruf kommt weiterhin durch. Die Ursache liegt in `0031`:

    | Richtlinie | Bedingung |
    | --- | --- |
    | `memberships_delete_staff` | `is_studio_staff(...)` **und** `role <> 'owner'` **und** `user_id <> auth.uid()` |
    | `memberships_update_staff` | `is_studio_staff(...)` **und** `role <> 'owner'` — die dritte Klausel fehlt |

    Ein Trainer kann sich also nicht selbst *entfernen*, aber sehr wohl selbst *herabstufen*. Dass die beiden Richtlinien direkt untereinander stehen und sich in genau dieser einen Zeile unterscheiden, spricht für ein Versehen, nicht für eine Absicht. In `e2e/leute.spec.ts` steht seit `65eb8b5` ein Test, der es über den anon-Client nachweist; er wird rot, sobald der Riegel kommt.

    **Der Riegel ist eine Migration, und Phase 5 baut keine.** Die Nummern laufen nach `0038` (Phase 4) bei `0039`. Das ist der Befund, nicht die stille Nebenbaustelle.

36. **`.sectionNote` hat einen Zwilling.** `bausteine.module.css:123` setzt für `.abschnittNotiz` dieselben `12px` in `--text-faint` wie `portal.module.css:193` für `.sectionNote` — derselbe verbotene Kontrast aus Befund 29, an einer zweiten Stelle. Wer die eine heilt und die andere übersieht, hat die Falle nur verschoben. **Fällig in Aufgabe 21, zusammen mit Befund 19 und 29.**

37. **Kein Link in dieser Anwendung ist als Link erkennbar.** `globals.css:97` setzt `a { color: inherit; text-decoration: none; }`, und in der ganzen Anwendung kommt `underline` **kein einziges Mal** vor. Für Rail, Reiter und Knopf-Links ist das richtig — sie tragen eigene Klassen und sehen aus wie Bedienelemente. Für einen Link **im Fließtext** bleibt dagegen null Unterschied zum Text daneben: weder Farbe noch Unterstreichung. Betroffen sind **16 Stellen**, davon **15 in den Kurse-Routen** (die ungestaltete Phase-4-Fläche, fällig in Aufgabe 22) und eine im Reiter *Mitglieder* (*„Mitglieder treten über den Studio-Code bei — Einstellungen"*, fällig in Aufgabe 21).

    **✅ Behoben.** Die fünfzehn sind in 22a und 22b zu Reitern und Zeilen-Links geworden, die ihre eigene Klasse tragen; die sechzehnte hat in Aufgabe 21 (`a23926d`) eine Unterstreichung bekommen — `.erlaeuterung a` in `bausteine.module.css`. Der Akzent schied als Mittel aus: er markiert die eine Hauptaktion, und ein Hinweissatz ist keine. Die Unterstreichung baut zudem nicht auf Farbe allein.

38. **`AktionsKnopf` hält seinen Bestätigungszustand je Knopf.** Auf einer Zeile mit zwei Aktionen — etwa *Tag scannen* und *Stilllegen* im Reiter *Einzelne Geräte* — können beide gleichzeitig in der zweiten Stufe stehen und warten. Wer die falsche trifft, hat sie nicht versehentlich ausgelöst, aber der Bildschirm zeigt zwei offene Rückfragen nebeneinander, und keine sagt, welche zu welcher Zeile gehört. **Vertagt** — der Eingriff wäre ein gemeinsamer Zustand über die Zeile, und das ist ein Umbau von `Form.tsx`, nicht Gestaltung.

39. **`?alle=1` trägt keinen Namen je Liste.** Die Kürzung im Reiter *Mitglieder* klappt über einen Suchparameter auf — richtig serverseitig, ohne Client-Rand. Der Parameter benennt aber nicht, **welche** Liste er meint. Solange ein Reiter höchstens eine kürzbare Liste hat, trägt das; der Reiter *Mitarbeiter* hat schon zwei Abschnitte, und sobald einer davon ebenfalls kürzt, klappen beide zugleich auf. **Vertagt**, mit der Notiz: der nächste, der eine zweite Kürzung anlegt, benennt den Parameter.

40. **`StudioMember` hat kein Namensfeld.** `LeuteMitarbeiter.dc.html` zeichnet Anzeigenamen über den E-Mail-Adressen (*„Inhaber · Tim"*, *„Trainer · Marek T."*). `packages/domain/src/people.ts:25` trägt `userId`, `email`, `role`, `joinedAt` — keinen Namen. Die Liste zeigt deshalb E-Mail-Adressen, die im Testbetrieb UUIDs enthalten und im Studiobetrieb immerhin lesbar sind. Ein Namensfeld ist eine Migration. **Vertagt.**

### Aus der Strukturaufnahme der Kurse-Bildschirme (Vorbereitung Aufgabe 22)

41. **Die fünf Kurse-Routen tragen alle eine zweite `<main>`-Landmarke — Befund 1, an der einen Stelle, die ihn nicht mitbekommen hat.** Aufgabe 4 hat `<main>` aus den Schreibtischseiten entfernt und in `(schreibtisch)/layout.tsx` gezogen. Die Kurse-Seiten entstanden zur selben Zeit auf `phase4-kurse`, gegen das **alte** Layout, und kamen mit dem Merge herein: **acht `<main className={styles.content}>` in fünf Dateien**, jede davon im `<main>` des Layouts.

    Zwei Folgen, und die zweite ist die sichtbare: ein Screenreader zählt zwei Hauptbereiche und kann bei *„zum Hauptteil springen"* nicht sagen, welcher gemeint ist — und `.content` trägt `padding: var(--s32) var(--s40) var(--s48)`, das damit **doppelt** liegt. Der Kursplan steht heute um 40 px weiter innen als jede andere Seite des Portals.

    Kein Test schlägt an, weil `hauptlandmarken()` (`e2e/helpers/abnahme.ts`) auf keiner Kurse-Route läuft. **Fällig in Aufgabe 22**, zusammen mit einem Test je Route.

42. **`.hint` ist der dritte Zwilling.** Nach `.sectionNote` (Befund 29) und `.abschnittNotiz` (Befund 36) setzt auch `portal.module.css:291` `12px` in `--text-faint` — und trägt damit unter anderem die Passwortregel (*„Mindestens zehn Zeichen …"*) und die Bedeutung der Stornofrist. Beides ist Pflichttext, den jemand lesen muss, und damit genau der Fall, den Designsystem §2 für `text-faint` ausschließt. In Aufgabe 20 **bewusst stehengelassen**, weil der Brief den Umfang auf die beiden benannten Klassen begrenzt hatte und ein stiller dritter Griff dieselbe Sorte Überraschung wäre wie die halbe Heilung bei Befund 18. **Fällig in Aufgabe 21.**

    **✅ Behoben in Aufgabe 21** (`a23926d`). `.hint` hängt an acht Stellen und per `aria-describedby` am Eingabefeld — der Hinweis ist damit auch das, was ein Screenreader zum Feld vorliest.

    Nicht zu verwechseln mit der `.hint`-Zeile aus Befund 19: die betraf die Produktgrenze im Überblick und ist über den Baustein `Produktgrenze` erledigt. Die **Klasse** blieb dabei, wie sie war.

### Aus dem Abgleich selbst (Aufgabe 21, 6. September)

45. **Zwoelf der siebzehn `Telefon*`-Artboards zeichnen eine Chipnavigation, die es im Code nicht gibt — und Phase 3 hat sie ausdruecklich dieser Phase versprochen.** `TelefonStart.dc.html` und elf weitere setzen ueber den Inhalt einen Kopf mit Studioname und einer seitlich scrollenden Pillenreihe (*Überblick, Kurse, Geräte, Tags, Leute, Einstellungen*), die aktive Pille markiert durch `box-shadow: inset 0 0 0 1px #d4ff3f` — ein Ring, keine Fläche, die Akzentregel bleibt also unberührt. Ohne die Reihe kommen genau die vier Vollbildschirme aus: `TelefonFoto`, `TelefonScan`, `TelefonUebungWaehlen`, `TelefonVideo`.

    Der Code hat es gewusst und aufgeschrieben. `einrichten/layout.tsx` sagt im Dateikopf: *„Der Gang durch die Halle hat keine Rail … Die Chipnavigation der Artboards gehört zur Telefonfassung des ganzen Portals und **kommt mit Phase 5** — hier steht nur der Weg zurück an den Schreibtisch."*

    **Phase 5 hat das Versprechen halb eingelöst.** Die Telefonfassung des Schreibtischs steht: `portal.module.css` legt unter `@media (max-width: 900px)` die Rail flach, macht aus den Gruppen eine seitlich scrollende Reihe und blendet die Gruppenbeschriftungen aus. Die **Halle** hat sie nicht bekommen — sie liegt ausserhalb von `(schreibtisch)` und damit ausserhalb dieser Schale.

    **Das ist eine Entscheidung, kein Fehler, und sie wird hier nicht getroffen.** Beide Lesarten sind vertretbar:

    - *Der Code hat recht.* Der Gang durch die Halle ist einhändig, neben einem Gerät, und seine ganze Prämisse lautet: ein Gerät ist fertig, sobald sein Tag klebt. Sechs Fluchtwege mitten im Gang laden dazu ein, ihn halb zu verlassen. Die Navigation dort ist die Schrittleiste, nicht die Rail.
    - *Das Artboard hat recht.* Wer in der Halle steht, muss vielleicht kurz zu *Tags* oder *Leute*, und der Umweg über *Schreibtisch* ist einer zu viel.

    **Empfehlung:** so lassen und die Zeile im Layout-Kommentar berichtigen — sie verspricht etwas für eine Phase, die vorbei ist. Wer die Chips in der Halle will, entscheidet zuerst, was mit der Schrittleiste geschieht; zwei Navigationen übereinander auf 390 px sind schlechter als eine.

    **Wie dieser Befund entstanden ist, und was daran fehlt:** durch Vergleich von **Artboard-Markup gegen Quelltext**, nicht durch Bilder. Der Bildvergleich, den Schritt 1 dieser Aufgabe verlangt, liess sich auf dieser Maschine **nicht durchführen** — siehe Befund 46. Von den vierzehn geplanten Aufnahmen ist eine brauchbar geworden (`/einrichten`, leerer Bestand); sie zeigt Kopf, Kennzahlenband, Zustandskarte, Hauptaktion und Fussnote an ihren Plätzen, und eben keine Chipreihe.

46. **Der Dev-Server bricht auf dieser Maschine mitten im Lauf zusammen, und die Seite zeigt danach eine Fehlerkarte statt des Bildschirms.** Beim Aufnahmelauf für Befund 45 lieferte Next nach wenigen übersetzten Routen:

    ```
    Failed to generate static paths for /portal/[studioId]:
    [Error: Jest worker encountered 2 child process exceptions, exceeding retry limit] { type: 'WorkerError' }
    ```

    Die Route antwortet danach weiter mit `200`, rendert aber die Entwickler-Fehlerkarte. **Eine Bildabnahme, die das nicht bemerkt, hält eine Absturzmeldung für einen Bildschirm** — genau das ist hier zweimal passiert, bis der Vergleich mit einer gültigen Aufnahme es zeigte.

    Drei Anläufe, jedes Mal nach vier bis sechs Aufnahmen abgebrochen; zwischendurch hat das Betriebssystem Dev-Server und Testlauf wegen Speichermangels beendet (freier Speicher unter 700 MB von 15 GB, siebzehn Node-Prozesse). Das ist derselbe Blocker, den Fahrplan Abschnitt 6 als *„die E2E-Suite ist auf dieser Maschine nicht vollständig lauffähig"* führt — hier mit einer neuen, schaerferen Auspraegung: **er fälscht nicht nur Testläufe, er fälscht Screenshots**, und ein Screenshot beschwert sich nicht.

    Es ist ein reines Entwicklungsproblem: `generateStaticParams` läuft nur unter `next dev` über diesen Worker-Pool, und die CI prüft gegen `next start`. **Betroffen ist die Abnahme, nicht das Erzeugnis.** Wer den Bildvergleich nachholt, tut es gegen einen Produktionsbau — `pnpm --filter @fitretro/web build && start` — und prüft jede Aufnahme darauf, dass sie kein `Runtime Error` zeigt.

43. **Die Installationskarte auf dem Gerätebildschirm weicht in vier von fünf Zeilen vom Artboard ab — aufgeschrieben, nicht behoben.** `FallbackGeraet.dc.html` zeichnet eine Karte mit Überschrift und Fließtext; der Code trägt einen einzelnen Satz.

    | | Artboard | Code (`t/[token]/page.tsx`) |
    | --- | --- | --- |
    | Überschrift | *„Deine Einstellungen jedes Mal wiederfinden"* (17 px, 800) | — |
    | Fließtext | *„Die App merkt sich Sitzhöhe, Gewicht und deine letzten Sätze — an jedem Gerät im Studio."* | *„Installiere die App, um deine Einstellungen und deinen Verlauf zu speichern."* |
    | Hauptaktion | *App laden* | *App installieren* |
    | Zweiter Scan | gleich | gleich |

    **Warum das nicht in dieser Aufgabe behoben wird, obwohl die Halbsätze aus Befund 33 und 34 es wurden:** jene beiden waren **aufgeschriebene Befunde**, die diese Aufgabe abzuarbeiten hatte. Dies hier ist ein **Fund während des Abgleichs**, und für solche sagt der Plan ausdrücklich: *„Abweichungen als Zeile notieren — nicht beheben."*

    Dazu ein sachlicher Grund: nur die Hauptaktion zu ändern, wäre genau die halbe Heilung, die Befund 18 und 42 dieser Phase schon gekostet haben. *App laden* neben einem Satz, der *„Installiere die App"* sagt, ist schlechter als beides konsistent falsch. Die ganze Karte ist eine Textentscheidung auf einer öffentlichen, nicht angemeldeten Seite — sie gehört in einen Bauabschnitt mit eigener Abnahme, nicht in einen Nebenzug.

    Der Artboard-Fließtext streift zudem die Datenschutzgrenze (*„deine letzten Sätze"*): `tag-fallback.spec.ts` verbietet auf dieser Seite die sichtbaren Zeichenfolgen `kg`, `Satz` und `Wiederholung`. *„Sätze"* geht am Verbot vorbei, weil `ä ≠ a` — aber wer die Karte nachzieht, muss diesen Test mitlesen, sonst fällt er über eine Zusicherung, die älter ist als der Entwurf.

44. **`.mitgliedshinweis` und `.ohneVideo` sind die vierte und fünfte Stelle zu Befund 19 — und die vierte stand vierzehn Zeilen über der dritten.** Beide `13px` in `--text-faint`:

    | Klasse | Was sie trägt | Warum das gelesen werden muss |
    | --- | --- | --- |
    | `landeseite.module.css` `.mitgliedshinweis` | *„Du bist Mitglied? … im Web gibt es nichts für dich zu tun."* | Es ist die **ganze** Antwort für ein Mitglied, das hier landet. Wer sie nicht liest, sucht weiter |
    | `fallback.module.css` `.ohneVideo` | *„Für diese Übung gibt es kein Video."* | Erklärt eine Abwesenheit — ohne sie sucht jemand nach etwas, das es nicht gibt |

    Der erste Durchgang der Aufgabe hat `.fuss` geheilt und `.mitgliedshinweis` in derselben Datei stehengelassen; der Code-Review hat es gefangen. Das ist dieselbe halbe Heilung, vor der Befund 42 warnt — diesmal nicht über Dateigrenzen hinweg, sondern **innerhalb einer Datei**, was es schlechter macht, nicht besser. Beide sind jetzt `--text-muted`; `.mitgliedshinweis` hat in `wurzel.spec.ts` eine Farbzusicherung bekommen.

    **Die Zählung ist damit endgültig:** Produktgrenze an drei Orten (Überblick, `/t/<token>`, Landeseite), plus `.fussnote`, `.mitgliedshinweis` und `.ohneVideo` als eigene Sätze mit derselben Begründung. Was `--text-faint` behält, ist in jedem Fall benannt: `.reiterZusatz` und `.navItemMeta` — Zählstände, die man streift, nicht liest.

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
