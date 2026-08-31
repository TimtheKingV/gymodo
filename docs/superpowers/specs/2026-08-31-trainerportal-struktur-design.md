# Trainerportal — Struktur, Anmeldung und Kurse

**Stand:** 31. August 2026
**Status:** Entwurf, abgestimmt. Noch keine Umsetzung.
**Vorgänger:** `2026-08-28-fitness-retrofit-m1-design.md` (M1-Spec), `2026-08-30-designsystem.md` (Tokens), `../plans/2026-08-30-kurse-datenmodell.md` (Kurse-Datenmodell)
**Canvases:** Member-App `4f6035c6-7612-42ed-9791-cf0794713bdd` · Trainerportal `fa12ef14-ca77-4fcc-a034-886a38914984`

---

## Warum dieses Dokument existiert

Das Trainerportal ist gebaut, aber nur der Gerätekatalog. Der Einstieg — Wurzelseite, Anmeldung — ist der Stub aus M0. Kurse gibt es nirgends. Und beim ersten Blick auf die laufende Oberfläche fiel auf, dass die Navigation mit jedem Gerätemodell wächst und bei fünfzig Geräten unbrauchbar wird.

Dieses Dokument legt die Struktur fest, bevor weiter gezeichnet oder gebaut wird, und führt Buch darüber, **welcher Entwurf ein Scheck ist, den das Backend noch nicht einlösen kann.** Genau das ist beim Betreiber-Dashboard schon einmal schiefgegangen: es stand als Option im Raum und wurde für gebaut gehalten.

**Wofür es der Eingang ist.** Als Nächstes entsteht daraus ein **Plan für die Designarbeit** — welche Artboards auf welcher Canvas, in welcher Reihenfolge. Die Umsetzung dahinter zerfällt in eigene Pläne mit sehr ungleichem Gewicht: die Navigation ist ein Tag Arbeit, Kurse sind ein Subsystem. Abschnitt 7 ist der Eingang für diese Pläne, nicht für den Designplan.

---

## Entscheidungen

Sieben, alle in dieser Runde getroffen:

1. **Passwort statt Code, auf beiden Oberflächen.** E-Mail und Passwort; ein sechsstelliger Code nur einmal, zur Verifikation der Adresse.
2. **Selbstregistrierung.** Jeder legt ein Konto an. Das widerspricht dem heutigen `shouldCreateUser: false`.
3. **Beitritt über einen Studio-Code.** Das Studio gibt ihn aus; wer ihn eintippt, wird **Mitglied**, nie Trainer.
4. **Ein Studio gründet sich nicht selbst.** Studio und erstes Inhaber-Konto entstehen beim Onboarding durch den Betreiber. Bewusste Lücke, kein Versehen.
5. **Gerätemodelle und Geräte werden ein Bereich** namens *Geräte*. Im Modell-Detail heißt der Reiter *Einzelne Geräte*.
6. **Kurse: Wochenliste statt Kalendergitter, Bild ohne Video.**
7. **Trainer verlieren das Leserecht auf einzelne Trainingsdaten.** Die Grenze zieht die Datenbank, nicht die Oberfläche.

---

## 1. Informationsarchitektur

Drei Gruppen zu je zwei Einträgen. Die Rail ist damit stabil — sie wächst nicht mit dem Katalog.

```
STUDIO        Überblick        Kurse
KATALOG       Geräte           Tags
VERWALTUNG    Leute            Einstellungen
```

**Geräte** führt zusammen, was heute zwei Einträge sind. Die Seite listet die Gerätemodelle; das Detail hat vier Reiter: *Stammdaten · Einstellungen · Übungen · Einzelne Geräte*. Jeder Reiter trägt seinen Zustand in der Beschriftung („Übungen 2 · 1 mit Video", „Einzelne Geräte 2 · 1 ohne Tag").

**Ein Reiter je Bildschirm bedeutet ein Formular je Bildschirm** — und damit hält die Regel des Designsystems, dass es genau eine Akzentfläche gibt, wörtlich statt nur dem Sinn nach. Die heutige Modellseite hat fünf.

### Die Anzahl der Geräte

Unter *Einzelne Geräte* steht ein Zählfeld. Erhöhen legt die fehlenden Geräte an — unbeschriftet, danach vergibt der Trainer Nummer und Tag.

**Verringern gibt es nicht.** Ein Gerät, das je einen Tag getragen hat, hat keinen Löschpfad (Fremdschlüssel `on delete restrict` aus `0008`), und das ist Absicht: ein gelöschtes Gerät nimmt die Zuordnungshistorie mit. Ein Gerät wird einzeln stillgelegt, mit Namen. Die Zahl über der Liste zählt danach nur noch die aktiven.

---

## 2. Anmeldung, Registrierung, Beitritt

Derselbe Ablauf auf beiden Oberflächen:

```
E-Mail + Passwort  →  Konto (unverifiziert)  →  Code aus der Mail  →  verifiziert
                                                                          ↓
                                                              kein Studio → Studio-Code
```

### Der Zustand „kein Studio"

Neu, und er trägt den ganzen Beitritt. Er zeigt genau eine Sache: das Feld für den Studio-Code. Nichts anderes ist erreichbar — das ist keine Sperre, sondern die Wahrheit. Ohne Studio gibt es keine Geräte, keine Kurse, nichts.

Die bestehende Architektur trägt das ohne Änderung: RLS läuft über `is_studio_member`, ein Konto ohne Mitgliedschaft sieht schlicht nirgends etwas. Dass sich jeder registrieren kann, ist deshalb unkritisch.

### Der Studio-Code macht zum Mitglied

Nie zum Trainer. Sonst wäre ein weitergegebener Zettel am Tresen ein Weg in den Gerätekatalog. Wer Trainer werden soll, wird unter *Leute → Mitarbeiter* von einem bestehenden Trainer hochgestuft.

**Damit ist die Mitarbeiterliste die Rechteverwaltung und der heikelste Bildschirm des Portals.** Sie braucht die entsprechende Sorgfalt: bestätigte Handlung beim Hochstufen, und niemand kann sich selbst die letzte Inhaberrolle entziehen.

Der Code ist sperrbar und erneuerbar — er macht früher oder später die Runde.

### Passwortpfade

Vergessen, zurücksetzen, ändern. Alle drei, auf beiden Oberflächen. **Ein Passwortlogin ohne Zurücksetzen ist kein Login, sondern eine Falle.**

Folge, die im Plan stehen muss: der ausstehende SMTP-Versand rückt von „Blocker vor dem ersten Betreibertermin" auf **„Blocker für den Regelbetrieb"** — er steht ab jetzt jedem vergessenen Passwort im Weg, nicht nur der Erstanmeldung.

### Passwortregeln

Lokal stehen sie auf sechs Zeichen ohne Anforderungen. Vorschlag: **zehn Zeichen Mindestlänge, keine Zeichenklassenpflicht.** Klassenzwang erzeugt Zettel am Monitor, Länge erzeugt Entropie.

---

## 3. Kurse im Portal

Das Datenmodell steht in `../plans/2026-08-30-kurse-datenmodell.md` und trägt diese Oberfläche. Eine Ergänzung ist nötig: **`course_templates` braucht ein Feld für den Standard-Trainer.** Der Plan kennt `instructor_user_id` nur am Termin; der Standard an der Vorlage fehlt.

### Drei Bereiche, fünf Bildschirme

**Kurse** ist die Wochenübersicht und der Einstieg — nach Tagen gruppiert, nicht als Gitter. Ein Gitter aus sieben Spalten und Uhrzeit-Zeilen löst das Erkennen von Überschneidungen; ein Studio mit ein bis zwei Räumen hat dieses Problem nicht. Es steht dafür meist leer, und die Zahl, auf die es ankommt, muss man sich aus der Kachel klauben. Eine Zeile „Mo · 18:00 · Kraftzirkel · Jana · 12 von 16" zeigt sie direkt und funktioniert nebenbei auf dem Telefon.

**Kursvorlagen** listet, was das Studio anbietet. Das Detail trägt Beschreibung, Dauer, Kapazität, Foto und Standard-Trainer — und darunter die Termine aus dieser Vorlage.

**Termin-Detail** zeigt Zeit, Raum, Kapazität, Trainer (Standard aus der Vorlage, hier überschreibbar), die Teilnehmerliste und die Absage.

### Serientermine

Werden beim Anlegen ausgeschrieben, nicht als Regel gespeichert — so steht es im Kurse-Plan, und das ist richtig: eine Wiederholungsregel, die man später auflösen muss, ist der klassische Kalendersumpf.

Für die Oberfläche heißt das: der Bildschirm zeigt **vor** dem Anlegen, welche Termine entstehen. Danach ist jeder einzeln änderbar und absagbar. **Eine spätere Änderung an der Vorlage lässt bestehende Termine unangetastet** — das muss dort stehen, sonst erwartet man es anders.

### Foto, kein Video

Die 45-Sekunden-Grenze bei Einweisungsvideos existiert, weil nicht transcodiert wird (Spec 6.8). Ein Kursvideo hat keine solche natürliche Grenze, und ein privater Bucket mit kurzlebiger URL ist die falsche Form für einen Clip, den alle sehen sollen. Ein Foto trägt Raum und Stimmung; mehr braucht eine Kursbeschreibung nicht. Video bleibt eine eigene Formatentscheidung für später.

### Absage statt Löschen

`status = 'abgesagt'` bleibt stehen, damit angemeldete Mitglieder sehen, was passiert ist. Ein verschwundener Termin sieht aus wie ein Fehler in der App.

---

## 4. Die Datenschutzgrenze

**Das Portal sieht Mitgliedschaft und Anwesenheit, aber keine Trainingsdaten.** Kein Satz, kein Gewicht, kein Verlauf, keine Kalibrierung — **je Mitglied nichts.**

Die Grenze verläuft am Personenbezug, nicht am Datentyp:

| Sichtbar | Nicht sichtbar |
| --- | --- |
| Wer im Studio Mitglied ist | Was ein bestimmtes Mitglied trainiert hat |
| Wer für einen Kurstermin angemeldet ist | Sätze, Gewichte, Verlauf, Kalibrierungen einzelner Personen |
| Studioweite Summen: Sätze im Zeitraum, aktive Mitglieder, meistgenutzte Geräte, gemeldete Probleme je Gerät | Jede Aufschlüsselung dieser Summen auf eine Person |

Der Betreiber sieht damit, **ob** sein Studio benutzt wird — das war der Zweck des Überblicks — ohne zu sehen, **von wem wie**.

Die Teilnehmerliste eines Kurstermins ist die eine Stelle, an der Namen erscheinen. Sie ist eine Anwesenheitsliste, sie gehört dem Studio, und für andere Mitglieder ist sie unsichtbar.

**Damit ein Trainer die Mitgliederliste überhaupt sehen kann, braucht `studio_memberships` eine Select-Policy für `trainer`/`owner`.** Heute erlaubt `memberships_select_own` ausschließlich die eigene Zeile — der Bereich *Leute* hat nicht einmal einen Lesepfad.

### Was dafür am Backend zu ändern ist

Heute stimmt das nicht. Vier Policies geben Trainern und Inhabern Leserecht auf die Trainingsdaten jedes Mitglieds ihres Studios:

| Migration | Policy | Klausel |
| --- | --- | --- |
| `0012` | `workout_sessions_select` | `or public.is_studio_staff(...)` |
| `0013` | `workout_sets_select` | `or public.is_studio_staff(...)` |
| `0014` | `member_machine_calibrations_select` | `or public.is_studio_staff(...)` |
| `0015` | `progression_suggestions_select` | `or public.is_studio_staff(...)` |

Alle vier verlieren die Staff-Klausel. Die Grenze liegt danach in der Datenbank und hält auch gegen einen Fehler in der Oberfläche.

**Der Überblick braucht dafür eine `SECURITY DEFINER`-Funktion**, die ausschließlich Summen liefert — aktive Mitglieder, Sätze, meistgenutzte Geräte, gemeldete Probleme je Gerät — und niemals Zeilen. Dieselbe Bauart wie `is_studio_member`: festes `search_path`, Rückgabe ohne Personenbezug.

Diese Funktion ist die einzige Stelle, an der Trainingsdaten für Personal überhaupt noch erreichbar sind. Ihre Signatur ist damit die Datenschutzgrenze in Code-Form — jede spätere Erweiterung um eine Aufschlüsselung ist eine Entscheidung, keine Kleinigkeit.

**Ein Vorbehalt, den der Betreiber kennen sollte:** Bei einem kleinen Studio mit wenigen aktiven Mitgliedern lässt eine Geräterangliste Rückschlüsse zu — wer montags allein da war, hat die 312 Sätze an der Beinpresse gemacht. Summen sind nicht automatisch anonym. Solange nur synthetische Daten im System sind (Spec §9), ist das unkritisch; vor dem ersten echten Mitglied gehört eine Mindestzahl je Kennzahl geprüft.

**Für M3 zurückzunehmen:** Trainerbetreuung braucht den Verlauf. Der Weg dorthin ist eine ausdrückliche Freigabe durch das Mitglied, nicht die pauschale Rolle.

---

## 5. Zustände

Das Designsystem definiert fünf. Im Portal gelten drei:

| Zustand | Gilt | Warum |
| --- | --- | --- |
| **Leer** | ja | Überschrift plus nächster Schritt, nie eine leere Statistik mit Nullen. |
| **Fehler** | ja | Sagt, was falsch ist **und** was gilt. Nie nur „ungültig". |
| **Deaktiviert** | ja | Nie stumm — daneben steht, was fehlt. |
| **Skelett** | nur Medien | Laut Spec ausschließlich für Medien; Katalogwerte sind sofort da. |
| **Offline** | nein | Ein Konzept der Halle, nicht des Schreibtischs. |

Das gehört in den Plan, sonst zeichnet jemand fünf Zustände für einen Bildschirm, der zwei braucht.

---

## 6. Bildschirmverzeichnis

**Portal, 1440 px.** `+` neu, `~` zu ändern, `·` steht schon im Entwurf.

| | Bildschirm |
| --- | --- |
| · | Wurzelseite |
| ~ | Anmelden — Passwort statt Code |
| + | Registrieren |
| + | E-Mail verifizieren |
| + | Passwort vergessen |
| + | Passwort zurücksetzen |
| + | Kein Studio — Studio-Code eingeben |
| ~ | Überblick — ohne individuelle Daten |
| + | Kurse — Wochenübersicht |
| + | Kursvorlagen — Liste |
| + | Kursvorlage — Detail |
| + | Termin anlegen samt Serie |
| + | Termin — Detail mit Teilnehmerliste |
| ~ | Geräte — Modelle und Geräte zusammengelegt |
| ~ | Gerätemodell — vier Reiter, Anzahl |
| · | Tags |
| ~ | Leute — Mitglieder |
| + | Leute — Mitarbeiter |
| + | Einstellungen — Studio |
| + | Einstellungen — Konto |
| · | Videoupload am Telefon |
| + | Zustandsblatt — Leer, Fehler, Deaktiviert, Medienladen |

**Member-App, 390 px, auf der bestehenden Canvas.**

| | Bildschirm |
| --- | --- |
| ~ | Anmelden — Passwort statt Code |
| + | Registrieren |
| + | E-Mail verifizieren |
| + | Passwort vergessen und zurücksetzen |
| + | Kein Studio — Studio-Code eingeben |
| + | Passwort ändern im Profil |

Zusammen **22 Bildschirme im Portal** (13 neu, 6 zu ändern, 3 bestehend) und **6 in der Member-App**.

---

## 7. Was kein Backend hat

Der Kassensturz, am Code geprüft:

| Bereich | Stand |
| --- | --- |
| **Kurse** | Nichts. Drei Tabellen, RLS mit voller Testmatrix, Platzvergabe unter Nebenläufigkeit, Endpoints, Server Actions. |
| **Leute** | Nichts, **nicht einmal Lesen.** `memberships_select_own` erlaubt genau die eigene Mitgliedschaft. Braucht eine Select-Policy für Staff (Mitgliederliste), Insert (Beitritt per Code), Update (hochstufen) und Delete (entfernen) — vier Policies, wo heute eine steht. |
| **Studio-Einstellungen** | `studios` hat nur `studios_select` und keine Spalte für die Stornofrist. Speichern ist nicht möglich. |
| **Registrierung, Passwort, Studio-Code** | Auth-Umstellung, Mail-Templates, neue Spalte am Studio, Beitritts-Action. |
| **Datenschutzgrenze** | Vier Policies zu ändern, eine Aggregatfunktion zu bauen. |
| **Überblick** | Läuft, sobald die Aggregatfunktion steht. |
| **Geräte, Tags, Katalog** | Vollständig vorhanden. |

**Der einzige Bereich, der heute vollständig trägt, ist der Gerätekatalog.**

---

## 8. Offene Punkte

- **SMTP-Versand** ist jetzt Blocker für den Regelbetrieb, nicht mehr nur für die Erstanmeldung. Konto- und Kostenentscheidung, unverändert beim Nutzer.
- **Benachrichtigung beim Nachrücken** von der Warteliste: Der Member-Entwurf verspricht sie auf Artboard 20. Push gibt es nicht, E-Mail bräuchte den SMTP-Fix. Bis das geklärt ist, darf der Satz nicht in die App — unverändert aus dem Kurse-Plan übernommen.
- **Stornofrist** ist eine Studioregel, keine Plattformregel. Sie gehört als Feld ans Studio; der Wert selbst ist offen.
- **Kursvideo** ist vertagt, nicht verworfen.
- **Studiogründung** gibt es bewusst nicht. Sobald ein zweiter Betreiber ohne Begleitung starten soll, wird das zur Lücke.
