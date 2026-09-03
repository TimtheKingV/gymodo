# Kurse — Platzvergabe, Warteliste und die fünf Bildschirme

**Stand:** 3. September 2026
**Status:** Entwurf, abgestimmt. Noch keine Umsetzung.
**Vorgänger:** `../plans/2026-08-30-kurse-datenmodell.md` (Vorabnotiz, 30. August), `2026-08-31-trainerportal-struktur-design.md` §3 und §8, `2026-08-28-fitness-retrofit-m1-design.md` §6.3, §6.7 und §10
**Ändert:** die Vorabnotiz an vier Stellen — Enum-Werte, `waitlist_position`, `instructor_name`, und der Satz auf Artboard 20. Jede ist unten einzeln begründet.
**Canvases:** Trainerportal `fa12ef14-ca77-4fcc-a034-886a38914984` (`Kurse`, `Kursvorlagen`, `Kursvorlage`, `TerminAnlegen`, `Termin`) · Member-App `4f6035c6-7612-42ed-9791-cf0794713bdd` (`Kurse`, `KurseMeine`, `KursDetail`)
**Migrationen:** `0035`–`0037`

---

## Warum dieses Dokument existiert

Kurse waren bis heute der einzige Bereich des Produkts **ganz ohne Spec.** Es gab acht Artboards und eine 84-zeilige Vorabnotiz vom 30. August, die ausdrücklich festhält, dass sie eine Lücke sichtbar hält statt sie zu schließen: *„Keine Migration, kein Endpoint, keine Zeile Code."*

Der Fahrplan nennt den Grund, warum die Runde jetzt fällig ist und nicht später: der Abstand zwischen Entwurf und Code war auf 29 Commits gewachsen und ist nach den Phasen 1 bis 3 auf null. Nach der Lehre aus §7 ist genau das der Moment für die nächste Entwurfsrunde.

**Und es gibt einen zweiten Grund, gerade hier sorgfältig zu sein.** Kurse enthalten die einzige Stelle im ganzen Produkt mit einem echten Wettlauf. Überall sonst schreibt jeder auf seine eigenen Zeilen — ein Satz gehört einem Mitglied, eine Kalibrierung gehört einem Mitglied, ein Gerät gehört einem Studio. Ein Kursplatz gehört niemandem, bis ihn jemand nimmt, und zwei Leute können gleichzeitig danach greifen. Das ist keine Fleißarbeit mehr, sondern eine Frage der Richtigkeit, und sie ist nicht nachrüstbar: eine Oberfläche, die auf einer falschen Vergabe steht, ist nicht dadurch zu reparieren, dass man später eine Sperre einzieht.

---

## Entscheidungen

Neun, alle in dieser Runde getroffen:

1. **Die Platzvergabe läuft über eine Zeilensperre in einer `SECURITY DEFINER`-Funktion**, nicht über einen Eindeutigkeitsindex mit Wiederholschleife und nicht über `serializable` mit Wiederholung beim Aufrufer.
2. **`course_bookings` bekommt keine Insert-, Update- oder Delete-Policy.** Die fehlende Policy ist die Bedingung, unter der Entscheidung 1 überhaupt etwas wert ist.
3. **Stornieren und Anmelden nehmen dieselbe Sperre auf denselben Termin.**
4. **`waitlist_position` wird berechnet, nicht gespeichert.** Abweichung von der Vorabnotiz.
5. **Die Enum-Werte sind englisch**, die Oberflächentexte deutsch. Abweichung von der Vorabnotiz.
6. **Der Trainer hat zwei Felder:** `instructor_user_id` ist die Zuordnung, `instructor_name` die Anzeige. Mitglieder sehen nie eine E-Mail-Adresse.
7. **Artboard 20 verliert die drei Worte „und eine Nachricht".** Das automatische Nachrücken bleibt.
8. **`photo_path` wird angelegt, der Upload-Weg vertagt.**
9. **Die Belegungszahl kommt aus einer Aggregatfunktion**, weil ein Mitglied die Buchungen anderer nicht zählen darf.

---

## 1. Was schon steht

Die Vorabnotiz zählt fünf Fachlogik-Risiken auf. **Eines davon ist seit dem 2. September erledigt**, ohne dass eine Zeile für Kurse geschrieben worden wäre:

> **4. Stornofrist.** Das Design nennt zwei Stunden vor Beginn. Das ist eine Studioregel, keine Plattformregel — gehört als Feld ans Studio oder an die Vorlage, nicht als Konstante in den Code.

`0032` hat `studios.cancellation_deadline_hours` angelegt: `not null default 2`, Bereich 0 bis 168, mit `0` als „bis zum Beginn". Die Einstellungsseite speichert den Wert bereits. Dieser Entwurf muss das Feld nur noch **lesen** — und es steht am Studio, genau wie die Notiz es verlangt hat.

Ebenfalls vorhanden und unverändert benutzt: `is_studio_member` und `is_studio_staff` als Träger der RLS, `studios.timezone` für die Anzeige, `set_updated_at` als Trigger.

**Was nicht steht und diesen Entwurf geprägt hat: es gibt keinen lesbaren Namen.**

`profiles.display_name` existiert seit `0001` — die Spalte ist da, nullable. Aber sie ist unbrauchbar für diesen Zweck, und zwar doppelt:

- **Niemand darf sie lesen außer dem Eigentümer.** `0001` legt genau zwei Policies auf `profiles`: `profiles_select_own` und `profiles_update_own`, beide `id = auth.uid()`. Ein Trainer kann den Anzeigenamen seines Mitglieds nicht sehen. Genau daran ist schon `0031` vorbeigegangen — sein Kopfkommentar hält fest, dass `profiles` nur die eigene Zeile freigibt, weshalb `list_studio_members` über `auth.users` gehen musste.
- **Niemand füllt sie.** Kein Formular, keine Server Action, keine Fachschichtfunktion schreibt `display_name`. Der Bezeichner kommt im ganzen Repository außerhalb der Migration nur in zwei Integrationstests vor, die ihn als Beispieldatum setzen.

Die Spalte über einen neuen Lesepfad zu öffnen wäre also erst der halbe Weg; dazu käme die Oberfläche, die sie füllt, und die Frage, wer den Namen eines anderen ändern darf. Das ist ein Profilsystem, und es steht in keiner Spec.

„Marek T." auf `Kurse.dc.html` und „M. Wolf" auf `Termin.dc.html` haben damit heute keine Daten hinter sich — genau die Sorte Scheck, deren Buchführung §Warum der Portalspec eingeführt hat. Abschnitt 4 löst das ein, ohne das Profilsystem zu eröffnen.

---

## 2. Die Platzvergabe

Das ist der Abschnitt, um den herum alles andere gebaut wird.

### Das Problem in einem Satz

Ein Termin hat 16 Plätze, 15 sind belegt, zwei Mitglieder tippen im selben Augenblick auf *Anmelden* — genau eines darf den Platz bekommen, das andere muss auf der Warteliste landen, und keines darf einen Fehler sehen.

### Warum die naheliegende Lösung falsch ist

Zählen, dann schreiben:

```sql
select count(*) from course_bookings where course_session_id = … and status = 'booked';
-- wenn kleiner als capacity:
insert into course_bookings …
```

Zwischen `select` und `insert` liegt ein Fenster. Unter `read committed` — der Vorgabe in Postgres — sehen beide Transaktionen den Stand 15, beide schließen daraus auf einen freien Platz, beide schreiben. Danach sind 17 Leute für 16 Plätze angemeldet, und niemand merkt es, bis der Kurs anfängt. Der Fehler ist **nicht selten**: er tritt genau dann auf, wenn ein Kurs beliebt ist, also genau dann, wenn es darauf ankommt.

Im Client zu zählen ist dieselbe Lücke, nur größer.

### Die Lösung: eine Zeilensperre, gehalten bis zum Commit

```sql
select * into v_session
  from public.course_sessions
 where id = p_session_id
 for update;
```

Die zweite Transaktion blockiert an dieser Zeile, bis die erste committet hat, und sieht danach deren Ergebnis. Gezählt wird also nie gleichzeitig.

Drei Eigenschaften machen das zur richtigen Wahl:

- **Der Rumpf einer plpgsql-Funktion ist eine Transaktion.** Die Sperre wird gefasst, gezählt, geschrieben und freigegeben, ohne dass dazwischen ein Client antwortet. Es gibt kein Netz im kritischen Abschnitt.
- **Gesperrt wird genau die umkämpfte Sache** — der Platzvorrat dieses einen Termins. Zwei verschiedene Kurse behindern sich nie, auch nicht im selben Studio.
- **Es ist die Bauform, die das Projekt schon kennt.** `join_studio_by_code` (`0030`) und `join_studio_by_tag` (`0023`) führen aus demselben Grund über eine Funktion statt über eine Policy: der Schreibvorgang hängt von einer berechneten Tatsache ab, und eine Policy kann nicht rechnen.

### Die beiden verworfenen Wege

**Ein Eindeutigkeitsindex über eine Platznummer.** Jede bestätigte Buchung bekäme `seat_index`, dazu `unique (course_session_id, seat_index) where status = 'booked'`. Der Verlierer prallt an der Verletzung ab und wird auf die Warteliste umgeschrieben. Kommt ohne Sperre aus — aber die Wiederholschleife ist selbst die Stelle, an der man es falsch macht, und bei zwanzig gleichzeitigen Anmeldungen erzeugt sie zwanzig Fehlversuche, um zwanzig Plätze zu vergeben. Ein zusätzlicher Zustand (`seat_index`) müsste beim Nachrücken mitgepflegt werden.

**`serializable` mit Wiederholung beim Aufrufer.** Postgres bricht die kollidierende Transaktion mit `40001` ab, der Aufrufer versucht es erneut. Sauber in der Theorie. Aber die Isolationsstufe lässt sich über PostgREST nicht je RPC sinnvoll setzen, und die Wiederholung landet im Client — womit Fachlogik dorthin wandert, wo Spec §6.1 und §6.2 sie ausdrücklich nicht haben wollen.

### Warum die fehlende Policy dazugehört

`course_bookings` bekommt **keine** Insert-Policy für `authenticated`, und das ist kein Sparen, sondern die Voraussetzung. Mit einer Insert-Policy könnte ein Mitglied per PostgREST direkt `status = 'booked'` schreiben und an der Kapazität vorbeigehen. Die Sperre in der Funktion wäre dann Dekoration: sie schützt einen Weg, an dem ein zweiter, offener vorbeiführt.

Dieselbe Begründung steht wörtlich in `0030`:

> Der Beitritt per Code läuft wie 0023 über eine Funktion, nicht über eine Insert-Policy: ein Insert-Recht auf `studio_memberships` wäre breiter als nötig.

**Das macht die Abwesenheit dieser Policy zu einer Zusicherung — und Zusicherungen werden geprüft.** Die Testmatrix enthält deshalb ausdrücklich den Negativtest, dass ein Mitglied nicht direkt in `course_bookings` schreiben kann, obwohl es dort keine Policy gibt, gegen die man testen könnte. Geprüft wird die Abwesenheit.

### Stornieren nimmt dieselbe Sperre

Das ist der Teil, den man beim ersten Entwurf übersieht — und die erste Fassung dieses Abschnitts hat ihn falsch begründet. Der Fehler ist beim Bauen aufgefallen, an der Gegenprobe, und die Berichtigung steht hier, weil eine falsche Begründung an der tragenden Stelle schlimmer ist als keine.

**Was hier ursprünglich stand:** eine Stornierung und eine Anmeldung könnten gleichzeitig zu dem Schluss kommen, es sei ein Platz frei, und der Platz werde zweimal vergeben.

**Das kann nicht passieren, und der Grund steht im Entwurf selbst.** Stornieren und Nachrücken liegen in *derselben* Transaktion. Der Zustand „Platz frei, noch niemand nachgerückt" wird deshalb nie festgeschrieben — er existiert nur innerhalb der offenen Transaktion, und kein anderer sieht ihn. Ein gleichzeitiger Bucher sieht entweder den Stand davor (Platz belegt, er landet auf der Warteliste) oder den vollständigen Stand danach (Platz schon nachbesetzt, oder wirklich frei). Beides ist richtig.

**Gebraucht wird die Sperre trotzdem — gegen zwei gleichzeitige Stornierungen.**

Ohne sie laufen zwei Stornierungen auf demselben Termin vollständig nebeneinander. Jede storniert ihre eigene Buchung, jede zählt, und jede sucht „die erste Wartende". Keine sieht das Nachrücken der anderen, also **wählen beide dieselbe Person.** Die zweite blockiert an deren Zeilensperre und schreibt danach dieselbe Person ein zweites Mal auf `booked` — der Verweis in ihrer Unterabfrage steht da schon fest.

Das Ergebnis bei zwei Stornierungen und zwei Wartenden: **eine rückt nach, die zweite bleibt liegen, obwohl ein Platz frei ist.**

Der Fehler ist damit Unterbelegung und ein verlorener Platz, nicht Doppelvergabe. Weniger schlimm, als die erste Fassung behauptet hat — aber echt, und für die Person, die zu Unrecht weiter wartet, nicht folgenlos.

`cancel_course_booking` fasst deshalb als Erstes dieselbe Zeile in `course_sessions` mit `for update` an, bevor es irgendetwas liest. Die zweite Stornierung wartet damit auf die vollständige erste und sieht deren Nachrücken, bevor sie ihre eigene Wahl trifft. **Stornieren und Nachrücken passieren im selben gesperrten Abschnitt.**

**Und daraus folgt, wie der Test aussehen muss.** Ein Test, der eine Stornierung gegen eine Anmeldung laufen lässt, kann diese Sperre nicht prüfen — er wird auch ohne sie grün, weil die Atomarität das Ergebnis ohnehin trägt. Geprüft wird mit *mehreren gleichzeitigen Stornierungen* auf einem Termin mit ebenso vielen Wartenden: danach müssen ebenso viele **verschiedene** Personen nachgerückt sein. Genau das hat die Gegenprobe belegt.

---

## 3. Das Datenmodell

Alle drei Tabellen mit `studio_id`, `enable` **und** `force row level security`, Positiv-, Negativ- und Cross-Tenant-Test je Policy (Spec §10, nicht verhandelbar).

### `course_templates`

| Spalte | |
| --- | --- |
| `id` | `uuid primary key default gen_random_uuid()` |
| `studio_id` | `not null references studios on delete cascade` |
| `name` | `not null`, nicht leer |
| `description` | `text` |
| `default_duration_min` | `int not null`, 5 bis 480 |
| `default_capacity` | `int not null`, 1 bis 500 |
| `photo_path` | `text` — siehe Abschnitt 7 |
| `default_instructor_user_id` | `uuid references auth.users on delete set null` |
| `default_instructor_name` | `text` |
| `created_at`, `updated_at` | |

**Kein Raum an der Vorlage.** `Kursvorlage.dc.html` führt unter *Stammdaten* Name, Beschreibung, Dauer, Plätze und Standard-Trainer — keinen Raum. `Kurse.dc.html` zeigt ihn je Termin („Kursraum 2", „Kursraum 1" für dieselbe Vorlage an verschiedenen Tagen). Der Raum ist eine Eigenschaft des Termins, und die Artboards sagen das bereits.

**Kein Löschpfad.** `Kursvorlagen.dc.html` hat keinen. Eine gelöschte Vorlage nähme die Termine mit oder ließe sie verwaist zurück; dieselbe Erwägung wie beim Gerät in §1 der Portalspec.

### `course_sessions`

| Spalte | |
| --- | --- |
| `id` | `uuid primary key default gen_random_uuid()` |
| `studio_id` | `not null references studios on delete cascade` |
| `course_template_id` | `not null references course_templates on delete restrict` |
| `starts_at` | `timestamptz not null` |
| `duration_min` | `int not null`, 5 bis 480 |
| `capacity` | `int not null`, 1 bis 500 |
| `room` | `text` |
| `instructor_user_id` | `uuid references auth.users on delete set null` |
| `instructor_name` | `text` |
| `status` | `course_session_status not null default 'planned'` |
| `cancelled_at` | `timestamptz` |
| `created_at`, `updated_at` | |

```sql
constraint course_sessions_cancellation_consistent
  check ((status = 'cancelled') = (cancelled_at is not null))
```

Dieselbe Bauform wie `workout_sessions_completion_consistent` aus `0012`: es soll keine abgesagten Termine ohne Zeitpunkt geben und keine Zeitpunkte ohne Absage.

Index auf `(studio_id, starts_at)` — die Wochenabfrage ist der einzige Lesepfad, der zählt.

**`capacity` liegt am Termin, nicht an der Vorlage**, und die Werte werden beim Anlegen aus der Vorlage kopiert, nicht verwiesen. Die Vorabnotiz begründet das mit dem kleinen und dem großen Raum; `TerminAnlegen.dc.html` schreibt die Folge selbst hin: *„Änderst du die Vorlage später, bleiben diese 14 Termine unverändert — sie behalten ihre eigenen Werte."*

### `course_bookings`

| Spalte | |
| --- | --- |
| `id` | `uuid primary key` — **ohne Default** |
| `studio_id` | `not null references studios on delete cascade` |
| `course_session_id` | `not null references course_sessions on delete cascade` |
| `user_id` | `not null references auth.users on delete cascade` |
| `status` | `course_booking_status not null` |
| `booked_at` | `timestamptz not null default clock_timestamp()` |
| `promoted_at` | `timestamptz` |
| `cancelled_at` | `timestamptz` |
| `created_at` | |

```sql
constraint course_bookings_cancellation_consistent
  check ((status = 'cancelled') = (cancelled_at is not null))
constraint course_bookings_promotion_consistent
  check (promoted_at is null or status <> 'waitlisted')

create unique index course_bookings_one_per_member
  on public.course_bookings (course_session_id, user_id)
  where status <> 'cancelled';
```

**`id` ohne Default, wie `workout_sessions`.** Die Kennung kommt vom Client, damit derselbe `PUT` zweimal denselben Platz ergibt — Idempotenz strukturell statt als Mechanismus (Spec §6.3). Ein Insert ohne `id` soll auffallen, nicht stillschweigend eine zweite Buchung anlegen.

**Der Teilindex ist die zweite Verteidigungslinie.** Die Funktion gibt eine bestehende Buchung unverändert zurück, statt eine zweite anzulegen; der Index sorgt dafür, dass das auch dann gilt, wenn jemand die Funktion einmal ändert und den Fall vergisst. `status <> 'cancelled'` im `where`: wer storniert hat, darf sich erneut anmelden, und das wird eine **neue Zeile** — die Stornierung bleibt stehen. Historie wird nicht durch ein stilles Update zerstört (Regelwerk §10).

Index auf `(course_session_id, status, booked_at)` — er trägt beides, die Zählung innerhalb der Sperre und die Reihenfolge der Warteliste.

### Abweichung 1: `waitlist_position` gibt es nicht

Die Vorabnotiz führt `waitlist_position int?` als Spalte. Dieser Entwurf berechnet sie stattdessen:

```sql
row_number() over (partition by course_session_id order by booked_at, id)
```

Drei Gründe:

- **Eine gespeicherte Position hat drei Schreiber** — Anmelden, Selbstabmelden, Entfernen durch Personal. Jeder vergessene Pfad verdirbt die Reihenfolge stillschweigend, und ein stiller Fehler in einer Warteliste fällt erst auf, wenn sich jemand beschwert.
- **Keine bezahlbare Constraint verhindert, dass zwei Zeilen die 3 tragen.** Ein `unique (course_session_id, waitlist_position)` müsste beim Nachrücken über die ganze Liste hinweg umnummeriert werden, und Umnummerieren unter einer Unique-Constraint ist genau das Problem, das Kalendersümpfe erzeugt.
- **Berechnet ist sie richtiger.** Storniert jemand vor dir, rückst du tatsächlich auf 2 — ohne dass jemand 200 Zeilen anfassen muss.

Der Preis ist ein Fensterfunktionsaufruf je Anzeige. Bei Wartelisten von unter zwanzig Personen ist das keine Größe.

### Abweichung 2: englische Enum-Werte

Die Vorabnotiz schreibt `status ∈ {geplant, abgesagt}` und `{gebucht, warteliste, storniert}`. Das Schema führt heute sieben Enums — `studio_role`, `tag_status`, `machine_status`, `session_completed_reason`, `problem_reason`, `calibration_source`, `tag_kind` — und **alle sieben tragen englische Werte, ausnahmslos.**

```sql
create type public.course_session_status as enum ('planned', 'cancelled');
create type public.course_booking_status  as enum ('booked', 'waitlisted', 'cancelled');
```

Die Rahmenbedingung des Projekts lautet „deutsche Oberflächentexte, deutsche Bezeichner **im Web-Layer**" — sie trifft die Schicht, die ein Mensch liest, nicht das Schema. Deutsche Werte hier wären das erste Gegenbeispiel im Schema und würden jede spätere `case`-Übersetzung zu einer Frage machen, in welcher Sprache dieser eine Enum wohl geschrieben ist. Die deutschen Wörter stehen in der Oberfläche, an genau einer Stelle je Schicht.

### Warum `booked_at` auf `clock_timestamp()` steht und nicht auf `now()`

*(Keine Abweichung von der Vorabnotiz — sie nennt die Spalte, nicht ihren Vorgabewert. Aber es ist die Sorte Entscheidung, die man später nicht mehr rekonstruiert.)*

`now()` steht innerhalb einer Transaktion still — es liefert deren Startzeitpunkt. Zwei Anmeldungen, die an derselben Zeilensperre anstehen, bekämen damit eine Wartelistenreihenfolge nach Transaktionsbeginn, nicht nach Zuteilung: wer eine Millisekunde früher *begonnen* hat, aber später durch die Sperre kam, stünde vorn.

`clock_timestamp()` läuft innerhalb der Transaktion weiter und wird im gesperrten Abschnitt ausgewertet. **Wer zuerst durch die Sperre geht, steht zuerst auf der Liste** — und das ist die Reihenfolge, die das System tatsächlich entschieden hat.

---

## 4. Der Trainername

Es gibt ein Namensfeld — `profiles.display_name` —, aber es ist für andere unlesbar und wird von nichts gefüllt (Abschnitt 1). Dieser Entwurf rührt es **nicht** an: es zu öffnen hieße, eine Policy und ein Profilsystem mitzubauen, und beides gehört nicht in einen Bauabschnitt über Platzvergabe.

Stattdessen zwei Felder am Kurs selbst, mit getrennten Aufgaben:

| Feld | Aufgabe | Wer sieht es |
| --- | --- | --- |
| `instructor_user_id` | **Zuordnung** — welches Konto ist zuständig | niemand direkt; Personal beim Auswählen als E-Mail-Adresse |
| `instructor_name` | **Anzeige** — was auf dem Bildschirm steht | alle, die den Termin sehen |

Die Regel, die die Mehrdeutigkeit auflöst, gilt an jeder Anzeigestelle und lautet:

> **Angezeigt wird `instructor_name`. Ist er leer, steht dort kein Name — nie die E-Mail-Adresse.**

**Warum nicht die Adresse einsetzen.** Personal sieht Mitglieder-Adressen über `list_studio_members`; das ist die Rechteverwaltung und in §4 der Portalspec gedeckt. Die Adresse eines Trainers an *jedes* Mitglied des Studios auszuliefern wäre eine neue Offenlegung, die dort nicht vorgesehen ist — und `member/Kurse.dc.html` zeigt „Marek T." an ein Mitglied. Ein Anzeigename ist ohnehin das, was das Artboard meint.

**Warum trotzdem der Verweis.** Ohne ihn ließe sich später nicht beantworten, welche Kurse eine Trainerin gibt, und ein externer Kursleiter ohne Konto bliebe ununterscheidbar von einem Tippfehler.

**Was die Datenbank dabei nicht erzwingt:** dass `instructor_user_id` auf Personal *dieses* Studios zeigt. Eine `check`-Constraint kann keine Unterabfrage, und ein Trigger dafür wäre eine fünfte Funktion in einem Projekt, das gerade vier ohne gesetzten `search_path` als offenen Punkt führt. Die Fachschicht prüft es beim Speichern. Der Rest ist Schadensbegrenzung nach Maß: das Feld wird nirgends angezeigt, es verrät nichts, und wer es füllen will, müsste eine fremde Kennung bereits kennen. Das steht als Kommentar in der Migration, damit die Lücke benannt ist statt übersehen.

---

## 5. Die vier Funktionen

Alle vier mit `set search_path = public, pg_temp`. Der Fahrplan führt vier Altfunktionen ohne ihn als offenen Punkt; hier entsteht keine fünfte.

### Eine Regel für alle vier

> **Nicht erlaubt oder gibt es nicht → `null`. Erlaubt, aber die Regel sagt nein → ein Ergebnis mit Grund.**

Die erste Hälfte ist die Orakel-Vermeidung, die `join_studio_by_code`, `list_studio_members` und `studio_overview` schon tragen: ein fremdes Studio und ein nicht existierendes antworten identisch, sonst ließe sich mit der Funktion herausfinden, welche Studios es gibt.

Die zweite Hälfte ist neu und nötig. „Zu spät zum Abmelden" ist kein Fehler, sondern ein erwartetes Ergebnis — der Mensch hat alles richtig gemacht, die Frist ist eben abgelaufen. Als Exception müsste die Fachschicht einen Postgres-Fehlertext abtasten, um daraus einen deutschen Satz zu machen. Als Ergebniswert ist es ein `switch`.

### `book_course_session(p_session_id uuid, p_booking_id uuid) returns jsonb`

```
1  v_user := auth.uid();  ist er null → return null
2  select … from course_sessions where id = p_session_id for update    ← die Sperre
3  nicht gefunden, oder not is_studio_member(studio_id)  → return null
4  status = 'cancelled'                                  → {'result':'session_cancelled'}
5  starts_at <= now()                                    → {'result':'past'}
6  bestehende Buchung (session, user) mit status <> 'cancelled'
                                                          → gib sie zurueck, created = false
7  zaehle status = 'booked'; < capacity ? 'booked' : 'waitlisted'
8  insert
9  return {'result','created','booking_id','waitlist_position','free_seats'}
```

**`result` ist immer der Zustand der Buchung** — `'booked'` oder `'waitlisted'` —, nie der Ausgang des Aufrufs. Ob *dieser* Aufruf sie angelegt hat, sagt `created`. Damit muss der Aufrufer den Wiederholungsfall nicht unterscheiden, um zu wissen, woran er ist: die Antwort auf „habe ich einen Platz?" steht immer an derselben Stelle. `created` ist für die Oberfläche da, die beim ersten Mal „Angemeldet" meldet und beim zweiten nichts.

Schritt 6 ist die Idempotenz: derselbe `PUT` zweimal ergibt denselben Platz, und zwar auch dann, wenn der Client beim zweiten Mal eine andere `p_booking_id` schickt. Der Teilindex hält das zusätzlich.

`free_seats` ist `greatest(capacity - booked_count, 0)` — bei einer nachträglich verkleinerten Kapazität stünden sonst negative freie Plätze auf dem Bildschirm.

Schritt 5 verhindert die Anmeldung zu einem Termin, der schon läuft. Die Grenze ist der Beginn, nicht das Ende — ein Kurs, der um 18:00 anfängt, nimmt um 18:20 niemanden mehr auf.

### `cancel_course_booking(p_session_id uuid, p_user_id uuid default null) returns jsonb`

`null` heißt „ich selbst". Personal übergibt eine Kennung, um jemanden zu entfernen — `Termin.dc.html` hat neben jedem Teilnehmer ein *Abmelden*. **Eine Signatur für beide Aufrufer, eine Sperre.**

```
1  v_user := auth.uid();  ist er null → return null
2  v_ziel := coalesce(p_user_id, v_user)
3  select … from course_sessions where id = p_session_id for update    ← dieselbe Sperre
4  nicht gefunden, oder not is_studio_member(studio_id)  → return null
5  v_ziel <> v_user und not is_studio_staff(studio_id)   → return null
6  keine offene Buchung fuer v_ziel                      → {'result':'not_booked'}
7  Frist: status='booked' und v_ziel = v_user und v_session.status = 'planned'
        und now() > starts_at - make_interval(hours => cancellation_deadline_hours)
                                                          → {'result':'deadline', …}
8  status := 'cancelled', cancelled_at := now()
9  war es 'booked' und status='planned' und starts_at > now():
        die erste Wartende nach (booked_at, id) → 'booked', promoted_at := clock_timestamp()
10 return {'result':'cancelled', 'promoted_user_id', …}
```

**Die Frist trifft nur das Mitglied, nur einen bestätigten Platz und nur einen Termin, der stattfindet** (Schritt 7). Drei Einschränkungen, jede aus ihrem eigenen Grund:

- Von der **Warteliste** zu gehen kostet niemanden einen Platz — dafür eine Frist zu verlangen wäre eine Regel ohne Zweck.
- **Personal**, das seinen eigenen Kurs verwaltet, kann nicht von einer Mitgliederfrist ausgesperrt werden; es entfernt jemanden, weil es einen Grund dazu hat, nicht weil eine Frist es erlaubt.
- Bei einem **abgesagten** Termin schützt die Frist nichts mehr. Sie besteht, damit das Studio einen frei werdenden Platz noch nachbesetzen kann; fällt der Kurs aus, gibt es nichts nachzubesetzen. Jemanden dann in einer Anmeldung festzuhalten, wäre eine Regel, die nur noch sich selbst dient.

**Schritt 9 rückt nicht in einen abgesagten oder vergangenen Termin nach.** Jemanden in einen Kurs zu befördern, der ausfällt, wäre eine Zusage, die das Studio schon zurückgenommen hat.

### `course_week(p_studio_id uuid, p_from timestamptz, p_to timestamptz) returns jsonb`

Diese Funktion löst ein Problem, das ohne sie nicht lösbar ist. `member/Kurse.dc.html` zeigt einem Mitglied **„12 von 16"** — aber die Select-Policy auf `course_bookings` lässt ein Mitglied ausschließlich die eigenen Buchungen sehen. Es kann nicht zählen, was es nicht sieht.

Das ist dieselbe Lage, die `0034` beim Überblick hatte, und dieselbe Antwort: eine Aggregatfunktion liefert, was die Zeilen verwehren. `security definer`, `is_studio_member` im Rumpf, und heraus kommen ausschließlich **Zahlen** — nie eine fremde Buchungszeile.

Je Termin:

| Feld | |
| --- | --- |
| `session_id`, `template_id`, `name`, `description` | |
| `starts_at` | `timestamptz` |
| `local_day` | `(starts_at at time zone s.timezone)::date` — siehe unten |
| `duration_min`, `capacity`, `room`, `instructor_name`, `status` | |
| `booked_count`, `waitlist_count`, `free_seats` | Zahlen, keine Zeilen |
| `own_status`, `own_booking_id`, `own_waitlist_position` | die **eigene** Buchung des Aufrufers |

Damit ist `GET /api/v1/me/courses` im Wesentlichen ein RPC — screenorientiert, wie Spec §6.3 es für jeden Endpoint verlangt. Die Portal-Wochenansicht benutzt dieselbe Funktion; Personal ist Mitglied, die Zahlen sind dieselben.

**Zur Zeitzone (Risiko 5 der Vorabnotiz).** `local_day` wird in der Datenbank aus `studios.timezone` berechnet und mitgeliefert. Die Oberfläche gruppiert danach und leitet den Tag **nie selbst ab.** Täte sie es, gruppierte der Server nach seiner eigenen Zeitzone — und eine Sommerzeitumstellung schöbe einen 18:00-Kurs auf den Vortag. Bei Trainingssätzen fiele das nie auf, bei Kursen sofort.

### `list_course_participants(p_session_id uuid)`

Die wörtliche Entsprechung zu `list_studio_members` aus `0031`: `security definer`, `is_studio_staff` im Rumpf, Verbund auf `auth.users` für die Adresse, die außerhalb der `public`-Policies liegt. Liefert `user_id`, `email`, `status`, `booked_at`, `promoted_at` und die berechnete `waitlist_position`, sortiert nach `(booked_at, id)`.

Nur für Personal. `Termin.dc.html` schreibt es selbst unter die Liste: *„Diese Liste ist eine Anwesenheitsliste. Andere Mitglieder sehen sie nicht."*

---

## 6. Die Aufteilung auf drei Migrationen

| | Inhalt | Was danach prüfbar ist |
| --- | --- | --- |
| `0035` | zwei Enums, drei Tabellen, Indizes, RLS | die volle Policy-Matrix |
| `0036` | `book_course_session`, `cancel_course_booking` | **der Nebenläufigkeitstest** |
| `0037` | `course_week`, `list_course_participants` | die Lesepfade |

Der Schnitt ist die Reihenfolge aus der Vorabnotiz, und er ist nicht kosmetisch: **nach `0036` steht der Nebenläufigkeitstest, und er steht dort vor jeder Oberfläche.** Was in `0037` und darüber entsteht, kann ihn nicht mehr beeinflussen — er misst dann die Vergabe und nicht die Anzeige.

---

## 7. Was in diesem Bauabschnitt nicht entsteht

### Der Foto-Upload

`Kursvorlage.dc.html` trägt eine Foto-Fläche mit *Foto auswählen*. **`photo_path` wird angelegt, der Upload-Weg nicht gebaut.**

`0020` richtet `equipment-photos` und `instruction-videos` als private Buckets ein, mit eigenen Storage-Policies über ein Pfadschema und `storage_studio_id`. Ein Kursfoto bräuchte entweder einen dritten Bucket samt vier Storage-Policies mit voller Testmatrix oder eine Erweiterung des Pfadschemas der bestehenden — beides ein eigener Bauabschnitt, der die Nebenläufigkeit an keiner Stelle berührt und den Umfang der Portalarbeit ungefähr verdoppelt.

Die Spalte kostet nichts und erspart die Migration. Das Artboard zeigt ohnehin den Zustand *„Noch kein Foto"* — die Oberfläche zeigt genau diesen Zustand, ohne einen Knopf, der nichts tut. Ein deaktivierter Knopf sagt daneben, was fehlt (§5 der Portalspec, Zustand *Deaktiviert* — nie stumm).

### Push und Mail

Siehe Abschnitt 8.

### Die Neugliederung der Rail

§1 der Portalspec ordnet die Navigation zu drei Gruppen zu je zwei Einträgen. Die Rail trägt heute noch die Struktur davor. **Dieser Bauabschnitt fügt einen Eintrag hinzu und räumt nicht auf** — die Neugliederung ist Phase 5 und fasst dieselbe Datei an; sie hier vorwegzunehmen hieße, sie zweimal zu machen.

### iOS

Keine Zeile. Die drei Endpoints entstehen, die App, die sie ruft, nicht.

---

## 8. Der Satz auf Artboard 20

`member/KurseMeine.dc.html` verspricht heute:

> Rückt jemand ab, bekommst du den Platz automatisch — **und eine Nachricht.** Bis dahin ist nichts reserviert.

Die Vorabnotiz führt das als Risiko 3 und ist unmissverständlich: *„Bis das geklärt ist, darf dieser Satz nicht in die App."* §8 der Portalspec wiederholt es.

**Geklärt wird es so: die drei Worte fallen, das Nachrücken bleibt.**

Der erste Halbsatz ist wahr und wird gebaut — `cancel_course_booking` rückt im gesperrten Abschnitt nach. Der zweite ist es nicht. Push gibt es nicht (Spec §4.2), und eine Transaktionsmail wäre nicht der kleine Zusatz, nach dem sie klingt:

- SMTP steht seit dem 1. September, aber die Supabase-Vorlagen decken **Auth-Mails** ab. Ein Kursversand bräuchte einen eigenen Weg — SMTP-Client in der Server Action, Edge Function oder `pg_net` — samt Zugangsdaten, Fehlerbehandlung und Rückläufern.
- Er bräche Spec §6.7 („kein Async in M1/M2 — ein Requestpfad, synchron").
- **Und er legte einen Ausfallpunkt in die Stornotransaktion.** Schlägt der Versand fehl, muss entweder die Stornierung zurückrollen — dann kann jemand sich nicht abmelden, weil ein Mailserver nicht antwortet — oder die Mail verschwindet still. Das zweite ist genau die Unehrlichkeit, die der Satz vermeiden sollte.

Neu:

> Rückt jemand ab, bekommst du den Platz automatisch. Du siehst es hier unter *Meine Kurse*. Bis dahin ist nichts reserviert.

**`promoted_at` wird trotzdem geschrieben.** Eine Spalte, die nichts kostet, und sie trägt zweierlei: die Oberfläche kann „Du bist nachgerückt" als Zustand zeigen statt nur den geänderten Status, und eine spätere Benachrichtigung — Mail oder Push, wenn iOS steht — hat einen Zeitpunkt, von dem aus sie senden kann, ohne dass es dafür je eine zweite Migration braucht.

---

## 9. Bildschirme und Endpoints

### Portal, funktional und ungestaltet

Alle unter der Routengruppe `(schreibtisch)`:

| Route | Artboard |
| --- | --- |
| `/portal/[studioId]/kurse` | `Kurse` — Woche nach Tagen, vor/zurück |
| `/portal/[studioId]/kurse/vorlagen` | `Kursvorlagen` |
| `/portal/[studioId]/kurse/vorlagen/[templateId]` | `Kursvorlage` — Stammdaten und Termine |
| `/portal/[studioId]/kurse/termin/neu` | `TerminAnlegen` — samt Vorschau der Serie |
| `/portal/[studioId]/kurse/termin/[sessionId]` | `Termin` — Teilnehmerliste und Absage |

Dazu ein Eintrag in der Rail.

**Die Serie wird ausgeschrieben, nicht als Regel gespeichert** — so steht es in der Vorabnotiz und in §3 der Portalspec. `TerminAnlegen.dc.html` verlangt dafür eine Eigenschaft, die den Bildschirm trägt: **er zeigt die entstehenden Termine, bevor sie entstehen.** Die Liste im Entwurf ist keine Zierde, sie ist die Bestätigung. Und der Satz darunter — *„Änderst du die Vorlage später, bleiben diese 14 Termine unverändert"* — gehört in die Oberfläche, weil man es sonst anders erwartet.

Von den fünf Zuständen des Designsystems gelten hier drei (§5 der Portalspec): **Leer** — eine Woche ohne Kurse sagt „Keine Kurse", wie das Artboard es zeigt, nie eine Tabelle mit Nullen. **Fehler** — sagt, was falsch ist und was gilt. **Deaktiviert** — nie stumm; daneben steht, was fehlt.

### Member-Endpoints

```
GET    /api/v1/me/courses?from=&to=           → course_week
PUT    /api/v1/course-sessions/{id}/booking   → book_course_session
DELETE /api/v1/course-sessions/{id}/booking   → cancel_course_booking
```

`PUT` nimmt die clientseitig erzeugte Buchungs-UUID im Rumpf. `DELETE` braucht keine — die Funktion nimmt die Terminkennung und findet die eigene offene Buchung selbst.

### Fachschicht

`packages/domain/src/courses.ts`: Vorlagen lesen, anlegen, ändern; Termine anlegen samt Serienausschreibung, ändern, absagen; Wochenabfrage; Teilnehmerliste; dazu zwei dünne Hüllen um die RPCs, die deren Ergebniswerte in `DomainError` oder Rückgabe übersetzen. Validierung mit Zod an jeder Systemgrenze (§10).

---

## 10. Tests

| | |
| --- | --- |
| **RLS-Matrix** | je Policy positiv, negativ, cross-tenant — `course_templates` (select/insert/update), `course_sessions` (select/insert/update), `course_bookings` (select) |
| **Die Abwesenheit** | ein Mitglied kann nicht direkt in `course_bookings` schreiben, ändern oder löschen |
| **Nebenläufigkeit, Anmelden** | mehrere gleichzeitige `book_course_session` auf den letzten Platz → genau eine `booked`, die übrigen `waitlisted` mit lückenloser Reihenfolge |
| **Nebenläufigkeit, Stornieren** | *n* gleichzeitige `cancel_course_booking` bei *n* Wartenden → *n* **verschiedene** Personen nachgerückt. Das ist der Test, der die Sperre im Stornieren prüft; siehe §2 |
| **Idempotenz** | derselbe `PUT` zweimal → eine Buchung; andere `p_booking_id`, gleicher Nutzer → dieselbe Buchung |
| **Frist** | Mitglied nach Frist abgewiesen, vor Frist durchgelassen; Warteliste ohne Frist; Personal ohne Frist |
| **Nachrücken** | die erste Wartende rückt nach und bekommt `promoted_at`; nicht in einen abgesagten, nicht in einen vergangenen Termin |
| **Zeitzone** | ein Termin nahe Mitternacht liegt in `local_day` des Studios, nicht des Servers |
| **Serie** | *n* Termine mit den Werten der Vorlage; eine spätere Änderung der Vorlage lässt sie unberührt |
| **E2E** | ein Gang durch das Portal: Vorlage anlegen, Serie anlegen, Termin öffnen, absagen |

**Die Nebenläufigkeitstests laufen über echte parallele Verbindungen**, nicht über nacheinander abgesetzte Aufrufe. Nacheinander abgesetzt prüfen sie nichts — sie bestätigen dann nur, dass Zählen und Schreiben in Reihe funktioniert, und das war nie die Frage. Es sind die einzigen Tests dieses Bauabschnitts, die bei falscher Bauweise trotzdem grün werden, und deshalb steht ihre Bauart hier und nicht nur im Plan.

**Und deshalb gehört zu jedem von beiden eine Gegenprobe:** die Sperre wird vorübergehend entfernt, der Test läuft, und er muss rot werden. Ein Nebenläufigkeitstest, den niemand je hat scheitern sehen, ist eine Behauptung. Beim Anmelden hat die Gegenprobe beim ersten Anlauf gegriffen — ohne `for update` bekamen drei von zehn gleichzeitigen Anmeldungen einen Platz. Beim Stornieren hat sie den ersten Testentwurf widerlegt und damit den Fehler in §2 aufgedeckt; das ist der Ertrag, den ein Schritt bringt, der keinen bleibenden Code schreibt.

---

## 11. Offene Punkte

- **Benachrichtigung beim Nachrücken.** Vertagt, nicht verworfen — `promoted_at` hält den Zeitpunkt bereit. Fällig, sobald iOS steht (dann Push) oder ein eigener Mailweg entsteht. Bis dahin gilt der Text aus Abschnitt 8.
- **Kursfoto.** Spalte da, Weg offen. Braucht die Bucket-Entscheidung aus Abschnitt 7.
- **Kursvideo.** Unverändert vertagt (§8 der Portalspec).
- **`profiles.display_name` bleibt tot.** Die Spalte steht seit `0001`, ist nur vom Eigentümer lesbar und wird von keiner Zeile Produktivcode geschrieben. Dieser Bauabschnitt weckt sie nicht auf und legt mit `instructor_name` bewusst einen zweiten, engeren Namensweg daneben. Sobald ein echtes Profil entsteht — spätestens, wenn die Teilnehmerliste Namen statt Adressen zeigen soll —, ist zu entscheiden, ob `instructor_name` darin aufgeht oder als freier Text daneben bestehen bleibt (für den externen Kursleiter ohne Konto spricht das Zweite).
- **Ob Kursteilnahmen im Trainingsverlauf auftauchen.** Die Vorabnotiz hält getrennt für die ehrlichere Variante: die Plattform weiß nicht, ob jemand da war, sie kennt nur die Anmeldung. Dieser Entwurf ändert daran nichts und baut keine Verbindung.
- **`instructor_user_id` zeigt nicht erzwungen auf Personal des Studios.** Von der Fachschicht geprüft, von der Datenbank nicht. Begründung in Abschnitt 4.
- **Wiederholungsregeln über „wöchentlich bis" hinaus** — jeden zweiten Dienstag, monatlich, Ausnahmen. `TerminAnlegen.dc.html` zeigt nur „Wöchentlich". Kommt, wenn ein Studio es braucht; die materialisierten Termine machen jede spätere Regel zu einer reinen Eingabehilfe statt zu einer Datenmodelländerung.
- **Ratenbegrenzung auf `book_course_session`.** Dieselbe offene Frage wie bei `join_studio_by_tag` (Fahrplan §6). Blockiert nichts, ist aber vor dem ersten echten Studio fällig — ein Skript, das im Sekundentakt an- und abmeldet, erzeugt sonst beliebig viele Wartelistenbewegungen.
