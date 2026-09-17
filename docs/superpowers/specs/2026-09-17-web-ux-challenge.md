# gymodo — Web-Portal UX-Challenge

**Stand:** 17. September 2026
**Status:** Befundsammlung (Abschnitte 1–6 unverändert als Nachweis erhalten), Abschnitt 7 schlägt drei Arbeitsblöcke vor, **Abschnitt 8 hält fest, was davon am selben Tag umgesetzt wurde** — und was offen blieb.
**Scope:** Das Trainerportal unter `apps/web/app/portal/**` — Überblick, Geräte/Modelle, die vier Modell-Reiter, der Einrichten-Gang. Nicht geprüft: Kurse, Leute, Einstellungen, Beitritt/Scan.
**Anlass:** Drei Beobachtungen aus dem Betrieb, nach der iOS-Arbeit: (a) der Flow „Gerät anlegen" ist nicht klar, (b) man sieht nicht, was zu welcher Übung gehört und was man wie einstellt, (c) die Oberfläche wirkt grau, unplastisch, ohne Farbakzente und ohne Grafik — besonders auf dem Überblick.

## 0. Methodik und ihre Grenze

Geprüft wurde der Code und die gerenderte Seite — nicht nur gelesen, sondern angesehen.

Die Seite gegen echte Daten zu fahren war in dieser Session **nicht möglich**: `supabase start` zieht seine Container von `ghcr.io`, und die Egress-Policy dieser Umgebung beantwortet die Blob-Downloads mit 403. Ohne lokale Datenbank rendert keine Portalseite.

Ersatz: eine Wegwerf-Route (`/uxreview`, `/uxhalle`) hat die vier Bildschirme mit den **echten Bausteinen und dem echten CSS** nachgebaut — `Seite`, `Abschnitt`, `Zeile`, `Kachel`, `Reiter`, `Schrittleiste`, `portal.module.css`, `halle.module.css` — und nur die Daten durch Festwerte ersetzt. Die Screenshots zeigen also die tatsächliche Optik und das tatsächliche Umbruchverhalten, nicht eine Skizze davon. Was sie **nicht** zeigen: echte Fotolängen, echte Namenslängen, Ladezustände, Fehlerfälle. Die Route ist nach den Aufnahmen wieder entfernt worden.

Screenshots (Belege zu den Befunden): `ueberblick-desktop`, `geraete-desktop`, `uebungen-desktop`, `uebungen-mobil`, `halle-mobil`.

---

## 1. Zusammenfassung — vier Themen

1. **Es gibt zwei Wege, ein Gerät anzulegen, und nur einer davon ist ein Weg.** Der Gang durch die Halle (`einrichten/`) hat Schrittleiste, Pflichtfoto und eine Weiterleitung zum nächsten Schritt. Der Schreibtisch (`geraete/`) hat nichts davon: „Modell anlegen" legt an, sagt nichts, führt nirgendwohin. Beide heißen gleich.
2. **Das Portal verwaltet Bilder und zeigt keine.** Gerätefotos liegen in der Datenbank, `ladeKatalog` liefert `photoUrls` mit — sichtbar sind sie in genau einem Formular. Die Übungsliste, die Modellliste, der Überblick: alles Text.
3. **Der Schreibtisch trägt die Farbregeln der Halle.** Das Designsystem ist für den Keller geschrieben („nahezu schwarz, ein einziger Signalakzent") — das Portal hat diesen Kontext nicht, erbt die Regeln aber vollständig. Auf dem Überblick kommt der Akzent **null Mal** vor; die auffälligste Farbe des Übungs-Reiters ist das Rot von „Entfernen".
4. **Das Handy bekommt den Schreibtisch, nur schmaler.** Für den Einrichten-Gang gibt es eine eigene Telefonebene (390 px, 56-px-Aktionen). Für alles andere gibt es eine Media-Query, die Zeilen stapelt — und dabei aus drei Nebenaktionen drei vollbreite Blöcke macht.

---

## 2. Der Flow „Gerät anlegen"

### Befund 1 — Derselbe Knopf, zwei verschiedene Versprechen

| | Halle (`einrichten/modell/neu`) | Schreibtisch (`geraete`) |
| --- | --- | --- |
| Foto | **Pflicht**, Absenden ist ohne gesperrt | kommt im Formular nicht vor |
| Nach dem Anlegen | `router.push(.../einstellungen)` → Schritt 2 | bleibt auf der Liste stehen |
| Wo bin ich | „Schritt 1 von 6 · Modell" | nichts |
| Rückweg | „← Modell wählen" | nichts |

Beleg: `ModellNeuFormular.tsx` (`router.push`, `disabled={!hatFoto || laeuft}`) gegen `actions.ts:99 modellAnlegen` (kein `redirect`) und `ModellAnlegenFormular.tsx` (Name, Hersteller, Gewichtsrad — kein Foto).

Das ist nicht „zwei Wege für zwei Situationen", sondern ein Widerspruch über dasselbe Objekt: Der Gang sagt „ohne Foto geht es nicht weiter — es ist der einzige Grund, warum jemand vor dem falschen Gerät merkt, dass er falsch steht". Der Schreibtisch legt dasselbe Modell ohne Foto an, und der Überblick meldet es anschließend unter „Was noch fehlt". Das Portal erzeugt sich seine eigene Mängelliste.

**Vorschlag:** Ein Weg, zwei Ebenen. Das Anlegen erzeugt *immer* ein Ziel — die neue Modellseite —, und die Modellseite sagt, was noch fehlt. Das Foto bleibt am Schreibtisch optional (am Rechner liegt selten eins bereit), aber dann steht auf der Zielseite die Zeile „Kein Foto — ohne es steht ein Mitglied nach dem Scan vor dem falschen Gerät", mit Knopf. Pflicht durch Sichtbarkeit statt durch Sperre.

### Befund 2 — Nach dem Anlegen passiert sichtbar nichts

`AktionsFormular` (Form.tsx) zeigt **nur den Fehlerfall** an. Erfolg ist Stille: Das Formular bleibt stehen, irgendwo in der Liste darüber ist eine Zeile dazugekommen. Bei drei Modellen findet man sie; bei dreißig nicht.

Es gibt im ganzen Portal keine Erfolgsrückmeldung — kein Toast, keine markierte neue Zeile, kein Sprung.

**Vorschlag:** Anlegen führt zum angelegten Objekt. Wo das nicht geht (Einstellung, Übung, Gerät — die legt man mehrfach hintereinander an), bleibt das Formular stehen, aber die neue Zeile kommt sichtbar markiert zurück, und der Fokus springt ins erste Feld für den nächsten Eintrag.

### Befund 3 — Der Schreibtisch kennt die Pflichten, zeigt sie aber nicht als Weg

Ein Modell ist erst benutzbar, wenn fünf Dinge existieren: Foto, Einstellungen, mindestens eine Übung, mindestens ein Gerät, ein aktiver Tag. Die Halle nummeriert das (`Schritt n von 6`). Am Schreibtisch steht dieselbe Kette als vier Reiter mit Zählern nebeneinander — „3 Einstellungen", „3 · 2 mit Video", „2 · 0 ohne Tag". Zähler sind kein Weg: Sie sagen, wie viel da ist, nicht was fehlt und schon gar nicht, was als Nächstes dran ist.

Für ein frisch angelegtes Modell heißt die Reiterleiste dann: „0 Einstellungen · 0 · 0 mit Video · 0 · 0 ohne Tag". Vier Nullen und kein Satz.

**Vorschlag:** Auf der Modellseite ein Kopfband „Noch zu tun" mit genau den offenen Punkten in der Reihenfolge, in der sie aufeinander aufbauen, jeder mit seinem Knopf. Verschwindet, wenn nichts mehr offen ist. Das ist die Schrittleiste der Halle, übersetzt in den nicht-linearen Schreibtisch: keine Nummern, sondern eine Restliste.

### Befund 4 — Drei Wörter für zwei Dinge

Rail: **Geräte** → Seite: **Geräte** → Karte: **Alle Gerätemodelle** → Zeilen: Modelle → Reiter: **Einzelne Geräte**. Der Vorspann der Seite muss den Unterschied erklären („Ein Modell beschreibt den Gerätetyp …"), weil die Navigation ihn verwischt. Dazu existiert `/modelle` weiter als Weiterleitung, und der Überblick verlinkt teils dorthin, teils auf `/geraete`.

Ein erklärender Satz an der Stelle, wo die Navigation lügt, ist ein Pflaster. Entweder heißt der Bereich „Geräte" und die Liste zeigt Geräte (mit ihrem Modell als Zusatz), oder er heißt „Gerätemodelle" und „Geräte" ist der Reiter darin.

---

## 3. Der Reiter „Übungen"

### Befund 5 — Liste und Anlegeformular stecken in derselben Karte, ohne Trennung

`uebungen/page.tsx` rendert `<ul className={styles.rows}>` und direkt danach `<UebungFormular>` — innerhalb **einer** `<section className={styles.section}>`, ohne zweiten `sectionHead`. Auf dem Screenshot liest sich das Formular wie eine vierte Zeile der Liste: Es beginnt bündig unter „3. Latzug hinter den Kopf" mit dem Label „NAME".

Die Nachbarseite macht es richtig: `/geraete` setzt „Modell anlegen" in eine **eigene** Karte mit eigenem Kopf. Derselbe Fehler steckt im Reiter „Einstellungen" (`EinstellungFormular` in derselben Section) und in „Einzelne Geräte".

**Vorschlag:** Anlegen ist immer eine eigene Karte mit eigenem Kopf. Drei Dateien, kleine Änderung, sofortiger Gewinn.

### Befund 6 — „Welches Bild gehört zu welcher Übung" ist strukturell unbeantwortbar

Was die Zeile über ihr Medium sagt: `Video 34 s`. Das ist alles. Kein Posterframe, kein Standbild, kein Dateiname, keine Vorschau. Ob im Video die richtige Übung zu sehen ist, ob es hochkant oder quer ist, ob es überhaupt das richtige Gerät zeigt — dafür muss man es herunterladen.

Das Modellfoto wiederum liegt im Reiter **Stammdaten**. Auf dem Übungs-Reiter ist das Gerät, um das es geht, nirgends zu sehen; es steht als Wort in der Überschrift.

Und `MedienVorschau` existiert bereits — sie wird im Anlegeformular für die *noch nicht hochgeladene* Datei benutzt und für die bestehenden Zeilen darüber nicht.

**Vorschlag:** (a) Jede Übungszeile bekommt links eine Medienkachel — Posterframe des Videos, sonst das Modellfoto abgedunkelt, sonst eine gestrichelte Leerfläche „ohne Video". Damit ist die Zuordnung eine Blickzuordnung. (b) Der Modellkopf trägt das Gerätefoto auf allen vier Reitern, klein, links neben Namen und Kennwerten. Das beantwortet „was gehört wozu" ohne einen einzigen zusätzlichen Satz.

### Befund 7 — Die auffälligste Farbe des Bildschirms gehört dem Löschen

Jede Übungszeile trägt drei Textknöpfe: `Hoch`, `Runter`, `Entfernen`. „Entfernen" ist `.destructive` — Umriss und Schrift in `--danger`. Bei sechs Übungen sind das 18 Knöpfe, davon sechs rot umrandet, gleichmäßig über die Karte verteilt. Auf dem Screenshot ist das mit Abstand das Erste, was das Auge findet. Die eine Akzentfläche der Seite („Übung anlegen") steht ganz unten und verliert.

Das Designsystem begründet den Umriss damit, dass Löschen „eine gewollte Handlung des Trainers" ist, kein Systemfehler. Richtig — aber die Häufung war nicht mitgedacht: Die Regel gilt je Knopf, nicht je Bildschirm.

**Vorschlag:** Reihenaktionen wandern in ein Überlaufmenü (⋯) oder erscheinen erst bei Hover/Fokus der Zeile; nur die Umordnung bleibt permanent sichtbar, weil sie beim Sortieren mehrfach hintereinander gebraucht wird. „Entfernen" behält seine Farbe, aber nicht mehr seinen Dauerplatz.

### Befund 8 — Umordnen kostet einen Serverlauf pro Klick

`uebungVerschieben` bekommt die fertige Reihenfolge und revalidiert das ganze Layout. Eine Übung von Platz 5 auf Platz 1 zu holen sind vier Klicks und vier volle Ladevorgänge — mit jedem Mal springt die Zeile eine Position weiter, und der Knopf, den man gerade gedrückt hat, ist danach woanders.

Dazu: Die Bedeutung der Reihenfolge („Übung 1 ist am Gerät die Vorauswahl des Mitglieds") steht in einem Fließtextsatz über der Liste. An der Liste selbst markiert nichts, dass Platz 1 etwas anderes ist als Platz 2.

**Vorschlag:** Ziehen mit der Maus und ⌘↑/⌘↓ auf der Tastatur, optimistisch im Client sortiert, ein Serveraufruf beim Loslassen. Und Platz 1 bekommt eine sichtbare Marke („Vorauswahl am Gerät"), damit der Zweck an der Sache steht statt im Vorspann.

### Befund 9 — „Was stelle ich wie ein?" zeigt die Datenzeile, nicht die Sache

Der Reiter Einstellungen zeigt `Sitzhöhe` / `1 bis 10 in Schritten von 1`. Das ist die Definition, nicht die Erfahrung. Wie es am Gerät aussieht — das Rad, die Rasten, was passiert, wenn das Mitglied zwischen zwei Rasten steht — sieht der Trainer nirgends, obwohl `EinstellungRad` genau dieses Bedienelement im Portal bereits rendert (im Anlegeformular).

Dasselbe gilt für das Gewichtsrad: Schrittweite, Minimum und Maximum stehen als Zahlen im Modellkopf („Schritt 2,5 kg · ab 5,0 kg bis 100,0 kg"). Ob die Kombination am Gerät sinnvoll rastet, zeigt erst das Gerät.

**Vorschlag:** Eine Vorschau „So sieht es am Gerät aus" auf dem Einstellungs-Reiter — dieselbe Radkomponente, nicht bedienbar, mit den echten Werten. Kein neues Konzept, ein bestehender Baustein an einer zweiten Stelle.

### Befund 10 — Nach „Übung anlegen" endet der Weg

Die Übung erscheint in der Liste. Das war's. Kein „Video jetzt hinzufügen", kein „nächste Übung", kein „fertig — weiter zu Einzelne Geräte". Dass der Reiter daneben noch bei null steht, sieht man nur, wenn man hinschaut.

Das ist Befund 3 an einer zweiten Stelle: Der Schreibtisch kennt keine Fortsetzung.

---

## 4. Das Handy

### Befund 11 — Die Reiterleiste bricht

Vier Reiter mit Zusatztext auf 390 px: „Stammdaten", „Einstellungen / 3 Einstellungen", „Übungen / 3 · 2 mit Video", „Einzelne Geräte / 2 · 0 ohne Tag". Der letzte bricht auf drei Zeilen, die Einträge haben unterschiedliche Höhen, und die Aktivmarkierung (Unterstrich) sitzt entsprechend auf halber Höhe der Nachbarn. Siehe `uebungen-mobil`.

### Befund 12 — Gestapelte Zeilen machen aus Nebenaktionen Hauptaktionen

`@media (max-width: 900px)` dreht `.row` auf `column` und gibt `.rowActions` volle Breite. Aus einer Übungszeile werden damit fünf gestapelte Blöcke: Titel, Meta, Video-Knopf, dann Hoch/Runter/Entfernen nebeneinander in voller Breite. Drei Übungen füllen den Bildschirm; die eigentliche Hauptaktion liegt zwei Bildschirmhöhen tiefer.

### Befund 13 — Es gibt keine Telefonsicht des Schreibtischs

Der Einrichten-Gang hat eine eigene Ebene: 390 px Spalte, 56-px-Hauptaktion, 52-px-Felder, eigene CSS-Datei. Der Schreibtisch hat eine Media-Query. Das ist der Unterschied zwischen „für das Telefon gebaut" und „bricht nicht".

Die Frage dahinter ist keine CSS-Frage: **Was macht ein Trainer am Telefon am Schreibtisch?** Wenn die Antwort „nachsehen, nicht pflegen" ist, dann ist die Liste mit allen Aktionen die falsche Mobilansicht — dann gehören dort Zustand und Weg hin, und das Pflegen bleibt am Rechner.

---

## 5. Warum es grau wirkt

### Befund 14 — Das Portal erbt die Farbregeln einer anderen Situation

Designsystem §1 begründet die Richtung wörtlich mit dem Nutzungskontext der Member-App: Keller, schummriges Licht, einhändig, feuchte Hände, drei Sekunden Blick. Daraus folgt „wenig Farbe, keine Dekoration" und die nicht verhandelbare Regel „genau eine Akzentfläche je Screen".

Das Trainerportal hat diesen Kontext nicht: Tageslicht, Maus, zwei Hände, Minuten bis Stunden am Stück, Formulare und Listen. `portal.module.css` sagt das im Kopfkommentar selbst („dort 64-pt-Ziffern, einhändig, im Halbdunkel; hier Formulare, Tabellen und Upload-Fortschritt an einem Rechner") — und zieht daraus zwei zusätzliche **Grau**stufen. Die Farbebene wurde nie übersetzt, nur geerbt.

Ergebnis: sechs Graustufen (`bg`, `well`, `surface`, `surface-raised`, `surface-hover`, `line`), drei Textgraus, drei Signalfarben — und keine einzige Farbe, die etwas *beschreibt* statt zu *warnen*.

### Befund 15 — Auf dem Überblick kommt der Akzent null Mal vor

Nachgezählt in `portal.module.css`: `var(--accent)` erscheint viermal — `.navItemActive` (2-px-Kante), `.primary` (Hauptaktionsfläche), `.progressBar`, `:focus-visible`. Der Überblick hat keine Hauptaktion, keinen laufenden Upload und keinen aktiven Rail-Eintrag außer sich selbst. Er ist damit vollständig grau. Das ist kein Versehen — es ist die Regel, korrekt angewandt.

### Befund 16 — Es gibt keine Datenfarben, also kann es keine Grafik geben

`accent` ist die Hauptaktion. `warn` ist die Problemmeldung, nur als Umriss. `danger` ist Fehler und Löschen. Eine Balkenreihe, ein Verlauf, ein Anteil, eine Auslastung hat damit nur zwei Möglichkeiten: eine Signalfarbe missbrauchen (und die Regel brechen) oder grau sein (und nichts zeigen).

Deshalb ist „Meistgenutzt" eine Rangliste ohne Rang: 212 / 198 / 164 / 140 Sätze als rechtsbündige Zahlen. Der Vergleich, der der ganze Zweck der Liste ist, findet im Kopf des Lesers statt. Dasselbe bei „12 von 14" Plätzen und bei „9 / 12 Geräte erreichbar".

### Befund 17 — Die vier Kacheln sagen alle dasselbe laut

„9 / 12 Geräte erreichbar" ist ein Missstand. „84 Mitglieder aktiv" ist eine gute Nachricht. „1342 Sätze erfasst" ist eine Beobachtung. Alle drei stehen in derselben Größe, demselben Grau, demselben Kasten, nebeneinander, gleich breit. Die Kachel hat keinen Zustand — sie kann nicht sagen, dass drei Geräte fehlen.

`Kachel.tsx` hält das ausdrücklich fest: „bewusst ohne Balken und ohne Ziel — der Überblick sagt, OB das Studio benutzt wird, nicht wie weit es von irgendwas entfernt ist." Das ist eine gute Begründung gegen Fortschrittsbalken auf *Mitglieder* und *Sätze*. Auf „9 von 12 erreichbar" trifft sie nicht zu: Das **ist** ein Anteil mit einem Ziel, und das Ziel ist 12.

### Befund 18 — Das Portal verwaltet Bilder und zeigt keine

Gerätefotos existieren, `ladeKatalog` liefert `photoUrls`, die Halle erzwingt sie. Sichtbar sind sie an genau einer Stelle: im Stammdaten-Formular des Modells. Nicht in der Modellliste, nicht auf dem Überblick, nicht auf den Reitern, nicht in der Rail. Das Portal ist ein Bildarchiv, das aussieht wie eine Tabelle.

### Befund 19 — Nichts bewegt sich, nichts reagiert

Es gibt keinen `:active`-Zustand, keine Transition außer der 120 ms des Fortschrittsbalkens, keinen Hover jenseits eines Flächenwechsels, keine Bewegung beim Öffnen der Schublade, keine beim Erscheinen einer neuen Zeile. `globals.css` trägt einen `prefers-reduced-motion`-Block, der nichts zu reduzieren hat. Alle Ebenen liegen in derselben Höhe: Karten haben Rand und Fläche, aber keinen Schatten, keine Kante, keinen Verlauf — daher „unplastisch".

---

## 6. Was ich dagegen *nicht* sage

Damit der Umbau nicht das Gute mitnimmt:

- **Die Texte sind gut.** „Für Mitglieder nicht auffindbar", „Nutzbar, nur ohne Anleitung", „ohne Standortangabe" — jeder Zustand sagt, was er bedeutet, nicht nur, dass er ist. Das bleibt.
- **Die Leerzustände sind gut.** Überschrift plus nächster Schritt statt vier Nullen — das ist mehr, als die meisten Produkte haben.
- **Die Datenschutzgrenze ist gut und sichtbar.** „Ohne Namen. Wer gemeldet hat, steht hier nicht." Farbe und Grafik dürfen daran nichts ändern.
- **Der Halle-Gang selbst ist richtig gebaut.** Schrittleiste, eine Aktion, große Trefferflächen, Pflichtfoto. Das Problem ist nicht der Gang, sondern dass der Schreibtisch nicht weiß, dass es ihn gibt.
- **„Genau eine Akzentfläche" ist für die Member-App richtig.** Was zur Debatte steht, ist ausschließlich ihre Übertragung auf den Schreibtisch.

---

## 7. Vorschlag: drei Blöcke

### Block A — Der Weg (Befunde 1, 2, 3, 5, 10)

Der größte Gewinn pro Zeile Code, und ohne Designentscheidung machbar.

1. Anlegen führt zum Angelegten: `modellAnlegen` am Schreibtisch leitet auf die neue Modellseite weiter.
2. Modellkopf bekommt ein Band „Noch zu tun" — die offenen Pflichten in Aufbaureihenfolge, jede mit Knopf, weg wenn leer.
3. Anlegeformulare bekommen eine eigene Karte mit eigenem Kopf (Übungen, Einstellungen, Einzelne Geräte).
4. Erfolg wird sichtbar: neue Zeile markiert, Fokus zurück ins erste Feld.

### Block B — Sehen, was gemeint ist (Befunde 6, 9, 7, 8, 18)

1. Medienkachel je Übungszeile (Posterframe → Modellfoto → Leerfläche).
2. Gerätefoto im Modellkopf, auf allen vier Reitern.
3. Fotos in der Modellliste.
4. Vorschau „So sieht es am Gerät aus" auf dem Einstellungs-Reiter.
5. Reihenaktionen aufräumen, Umordnen durch Ziehen.

### Block C — Farbe und Plastik (Befunde 14–17, 19)

Braucht zuerst eine Entscheidung, weil er eine als nicht verhandelbar markierte Regel berührt. Mein Vorschlag:

- Die Regel wird **präzisiert statt gebrochen**: „Genau eine Akzent*aktion* je Screen" — der Akzent als *Aktionsfläche* bleibt einmalig. Der Akzent als *Wertfarbe* (Balken, Anteil, Kurve) ist davon ausgenommen, so wie es die Member-App bei der Verlaufskurve längst tut (`accent` = „Hauptaktion, aktiver Wert, **Verlaufskurve**", Designsystem §2).
- Das Portal bekommt eine **Datenpalette** — drei bis vier gedeckte, untereinander unterscheidbare Farben ohne Signalbedeutung, nur für Diagramme, Anteile, Kategorien. Das ist die eigentliche Lücke: Ohne sie ist jede Grafik entweder falsch eingefärbt oder grau.
- **Plastik**: eine Ebenenregel (Karte hebt sich vom Grund durch eine helle 1-px-Oberkante und einen weichen Schatten, nicht nur durch Fläche), ein `:active`-Press-Feedback, eine Eingangsbewegung für neue Zeilen.
- **Der Überblick bekommt eine Hauptfigur**: „9 von 12 Geräte erreichbar" als Anteil mit Balken statt als Kachel neben drei anderen — die Zahl, die eine Handlung auslöst, oben und groß; die drei Beobachtungszahlen darunter und kleiner.

**Reihenfolge:** A, dann B, dann C. A und B sind unstrittig und machen die Seite sofort benutzbarer; C braucht eine Designsystem-Entscheidung und sollte nicht nebenbei passieren.

---

## 8. Umgesetzt am 17. September

Drei Commits, in der Reihenfolge aus Abschnitt 7.

**Block A — Der Weg.** Befunde 1, 2, 3, 5 und 10 geschlossen. `modellAnlegen` am Schreibtisch leitet auf die neue Modellseite weiter; der Modellkopf trägt das Band „Noch zu tun" mit den offenen Pflichten in Aufbaureihenfolge (`offen.ts`, sechs Testfälle); die Anlege-Formulare der drei Reiter haben eine eigene Karte mit eigenem Kopf; Erfolg ist nicht mehr stumm (Meldung, geleerte Felder, Zeiger zurück ins erste). Das Foto bleibt am Schreibtisch optional — die Pflicht steht jetzt sichtbar im Band, statt den Knopf zu sperren.

**Block B — Sehen, was gemeint ist.** Befunde 6, 7, 8 und 9. Jede Übungszeile zeigt das Einweisungsvideo als Standbild; `VideoUpload` zeigt das gespeicherte Video statt nur die gerade gewählte Datei; die Modellliste trägt Fotos und statt der Punktkette zwei Zeilen (was im Raum steht, ob es fertig ist); der Einstellungs-Reiter zeigt die Rasten statt der Definition (`rasten.ts`, sieben Testfälle). „Entfernen" ist grau, bis es scharf ist; „Hoch"/„Runter" sind am Rand abgeschaltet statt folgenlos; Platz 1 trägt „Vorauswahl am Gerät".

**Block C — Farbe und Plastik.** Befunde 14 bis 17 und 19, dazu 11 und 12 aus dem Mobilteil. Das Designsystem hat einen Abschnitt 15 „Schreibtischebene" mit der präzisierten Akzentregel, den Tokens `daten` / `daten-leise`, der Regel, wo ein Balken erlaubt ist, und der Plastik.

> **Nachtrag, noch am selben Tag:** Befund 16 schlug eine eigene Datenpalette vor, und die erste Umsetzung führte dafür ein geprüftes Blau ein. Das war der falsche Schluss aus dem richtigen Befund — die Lücke war, dass *jede* Farbe ein Signal war, nicht dass eine Farbe fehlte. `daten` zeigt jetzt auf die Primärfarbe, `daten-leise` auf ihre dunklere Stufe. Die Trennung der Namen bleibt, weil sie zwei Rollen trennt (gedrückt gegen gelesen) und Regel 15.1 damit im Code prüfbar bleibt. Das System hat nach dieser Runde genau so viele Farben wie vorher. Der Überblick führt mit „9 von 12 Geräte erreichbar" samt Anteilsbalken; die drei Beobachtungszahlen stehen kleiner darunter; „Meistgenutzt" hat Balken. Karten tragen Oberkante und Schatten, Knöpfe ein Druckgefühl. Die Reiterleiste schiebt sich auf schmalen Schirmen seitlich, statt auf drei Zeilen zu brechen; die Kennzahlen stehen auf dem Telefon zweispaltig.

### Offen geblieben

- **Umordnen durch Ziehen** (Teil von Befund 8). Die Knöpfe sind ehrlicher geworden, aber eine Übung von Platz 5 auf Platz 1 sind weiter vier Klicks.
- **Eine eigene Telefonsicht des Schreibtischs** (Befund 13). Die Seiten brechen jetzt sauber, aber die Frage dahinter — *was macht ein Trainer am Telefon am Schreibtisch?* — ist nicht beantwortet.
- **Die Nomenklatur Geräte/Modelle/Einzelne Geräte** (Befund 4). Unverändert; die Änderung trifft Navigation, Routen und Texte an einem Dutzend Stellen und gehört in einen eigenen Schnitt.
- **Der Einrichten-Gang** ist in dieser Runde nicht angefasst worden. Er war auch nicht der Befund.

### Was die CI danach sagte (Lauf 35259521533)

Drei E2E-Tests rot, 100 grün. Auseinandersortiert:

1. **`schreibtisch.spec.ts` — „Tag scannen" zweimal auf dem Schirm.** Verursacht durch diese Runde und behoben: das Band „Noch zu tun" bietet denselben Weg an wie die Gerätezeile, wenn genau ein Gerät ohne Tag dasteht. Das ist Absicht — das Band nennt den nächsten Schritt, die Zeile gehört dem Gerät —, aber eine ungezielte Frage nach „dem Link mit dem Namen" trifft jetzt zwei. Die Zusicherung zielt auf die benannte Liste, wie die beiden anderen im selben Lauf schon.
2. **`leute.spec.ts` — „Alle anzeigen" ändert die Adresse nicht.** Kein Befund dieser Runde, aber ein bekannter: derselbe Kürzungs-Link im Termindetail musste am 6. September auf ein `<a>` wechseln, weil Nexts Client-Router einen Wechsel, der nur den Suchparameter ändert, im Produktionsbau ins Leere laufen lässt. Der Kommentar an dieser Stelle nahm sie ausdrücklich davon aus („gegen denselben Bau geprüft und geht durch"). Die Annahme ist widerlegt; die Stelle ist jetzt ebenfalls ein `<a>`. Dass es lange gutging, passt zum Zwilling: dort war es allein grün und nur unter Last rot.
3. **`trainerportal.spec.ts` — „Sitzposition" erscheint nicht nach dem Anlegen.** **Älter als diese Runde.** Derselbe Test mit derselben Meldung war schon rot in den Master-Läufen vom 15. September (35003414706), 16. September (35058847408) und 16. September (35059607277) — damals an Zeile 194, heute an 199, weil diese Runde fünf Zeilen darüber ergänzt hat. Dazwischen war er einmal grün (35146547192): er ist unzuverlässig, nicht konstant rot. Hier ist er unangetastet geblieben; die Ursache ist offen und gehört in einen eigenen Schnitt.

Eine Vermutung zu 3, ausdrücklich unbewiesen: sie riecht nach derselben Familie wie 2 — nach dem Anlegen zeigt die Seite die neue Zeile nicht, obwohl die Aktion `revalidatePath` meldet. Beides sind Fälle von „der Produktionsbau frischt clientseitig nicht auf, der Dev-Server schon". Wer das angeht, braucht den Playwright-Bericht des roten Laufs (die `error-context.md` im Artefakt sagt, ob eine Fehlermeldung im Formular stand oder die Liste einfach leer blieb) — raten hilft hier nicht.

### Wie geprüft

`pnpm typecheck` und `pnpm test` nach jedem Block; dreizehn neue Testfälle für die beiden Ableitungen. Die E2E-Zusicherungen wurden an zwei Stellen nachgezogen (der Anlege-Weg und die jetzt benannten Listen), **aber nicht ausgeführt**: `supabase start` scheitert in dieser Umgebung an der Egress-Policy (403 auf die ghcr.io-Blobs), und ohne lokale Datenbank läuft kein E2E-Test. Das ist die offene Flanke dieser Runde — die Oberfläche ist an der gerenderten Seite geprüft, der Datenweg nur am Typ.
