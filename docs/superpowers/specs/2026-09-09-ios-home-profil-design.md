# iOS Member-App — Home & Profil (Sub-Projekt 4 von 4)

**Stand:** 9. September 2026
**Status:** Entschieden, bereit für Umsetzungsplan.
**Vorbedingung:** Sub-Projekte 1–3 sind gebaut und in `master` gemergt. `APIClient`, `CatalogStore`, `WorkoutSessionStore`, `KurseStore`, `ScannerSheet`, `Zahlformat`, `DesignSystem` und die Tab-Hülle stehen. Offen, aber nicht blockierend: die manuellen Abnahmen aus SP2 und SP3.
**Zitierweise:** `§n` ohne Dokumentangabe verweist auf `2026-08-30-designsystem.md`; Verweise innerhalb dieses Dokuments stehen als „Abschnitt n".
**Verhältnis zu anderen Dokumenten:** untergeordnet gegenüber `2026-08-28-fitness-retrofit-m1-design.md` (Produktverhalten) und `2026-08-30-designsystem.md` (Aussehen, Bewegung). Dieses Dokument bestimmt, *wie* Sub-Projekt 4 gebaut wird, und hält fest, wo es von beiden begründet abweicht.

---

## 1. Zwei Hälften in einem Sub-Projekt

**Verlauf** — Home, Session-Detail, Übungsfortschritt. Das, was M1 §5.5 „bewusst mitgekauft" nennt: der größte Einzelposten außerhalb der Kernschleife, gekauft, weil der eigene Fortschritt sowohl Motivation als auch Vorführmaterial ist.

**Profil & Name** — der Vollausbau von `Profil.dc.html`, der Vorname bei der Registrierung, die drei Einstellungen.

Sie hängen an genau einer Stelle zusammen: der Name, mit dem Home grüßt, wird im Profil gepflegt. Deshalb ein Sub-Projekt und nicht zwei.

Mit diesem Sub-Projekt ist die Screenliste aus M1 §5.1 vollständig: Login · Home · Session-Detail · Übungsfortschritt · Training · Gerät · Session-Abschluss · Profil.

---

## 2. Scope

**Enthalten:**

- `Home.dc.html` und `HomeLeer.dc.html` — beide Zustände eines Screens
- `SessionDetail.dc.html` — die Blöcke und Sätze einer Einheit
- `Uebungsfortschritt.dc.html` — Gewichtsverlauf je Übung, Swift Charts
- `Profil.dc.html` — Vollausbau, einschließlich der drei Schalter
- Vorname bei der Registrierung, Nachtragsweg im Profil
- Serveranteil: Kopfzeilen-Kennzahlen, Gerätelabel im Fortschritt, Lese- und Schreibweg des Namens
- Die fehlenden Tests für `getSessions` und `getProgress`

**Nicht enthalten:**

- Der **Plan**-Tab (M3) — er steht laut §11 in der Struktur, aber nicht in der Tab-Leiste, solange er keinen Inhalt hat
- Push-Benachrichtigungen — sie existieren nicht, und kein Text in diesem Sub-Projekt verspricht eine
- Hell-Modus (§14, bewusst nicht gebaut)
- Wortmarke und App-Icon (§14, weiterhin Platzhalter)
- Export der eigenen Daten — in M1 nirgends zugesagt

---

## 3. Server-Anteil

Vier Änderungen, alle in Dateien, die Sub-Projekt 3 nicht angefasst hat.

### 3.1 Zwei Module ohne Tests — und sie tragen dieses Sub-Projekt

`sessions.ts` und `progress.ts` sind die **einzigen beiden Domänenmodule ohne Testdatei**. Aus ihnen kommt alles, was die drei Verlaufs-Screens anzeigen: die Ableitung der Blöcke aus Sätzen, die Vier-Stunden-Regel für vergessene Einheiten, „schwerster bestätigter Satz je Trainingstag".

**Die Tests kommen zuerst, vor jeder Erweiterung.** Sonst prüft der erste Testlauf die neuen Felder und nicht das, worauf sie aufsetzen.

### 3.2 `GET /me/sessions` bekommt eine Kopfzeile

Neu im Antwortkörper:

```
summary: {
  totalCount:     number,        // COUNT, nicht die gedeckelten 50
  thisWeekCount:  number | null, // Wochengrenze in der Studio-Zeitzone
  lastSessionAt:  string | null  // ISO 8601
}
```

`SESSION_LIMIT = 50` bleibt für die Liste. „34 gesamt" darf davon nicht abhängen: ab der 51. Einheit wäre die Zahl still falsch, und zwar genau für die treuesten Mitglieder. Ein `COUNT` ist billiger als ein höheres Limit.

**Die Wochengrenze braucht eine Zeitzone.** Ein Mitglied kann mehreren Studios angehören; welches gerade aktiv ist, weiß nur der Client (`CatalogStore.activeStudioId`, in `UserDefaults`). Der Aufruf bekommt deshalb denselben Parameter, den `/me/courses` schon trägt: `?studio=<uuid>`, als UUID geprüft, bevor er den Router verlässt.

**Ohne den Parameter bleibt `thisWeekCount` `null`, und der Client lässt die Zahl weg** — statt sie in UTC zu raten. Wer sein letztes Studio verlassen hat, behält damit seinen Verlauf und seine Gesamtzahl; nur die Wochenzahl fällt weg, weil es keine Woche gibt, auf die sie sich beziehen könnte.

**Die Liste bleibt studioübergreifend.** Wer in zwei Studios trainiert, hat einen Verlauf, nicht zwei — der Parameter wählt die Zeitzone, nicht den Ausschnitt.

### 3.3 `GET /me/progress` bekommt das Gerätelabel

Je Übung neu: `machineLabel: string` — das Label des Geräts aus dem **jüngsten** Satz dieser Übung, über `workout_sets.machine_id` verbunden.

Gruppiert wird weiterhin nach Übung allein. Hat ein Studio zwei baugleiche Beinpressen, bleibt die Kurve durchgehend: **die Steigerung gehört der Übung, nicht dem Gerätegehäuse.** Der Preis ist ein Label, das wechseln kann, wenn jemand das Gerät wechselt — sichtbar wird das nur als anderer Gerätename über derselben Kurve.

**Bekannte Ungenauigkeit, bewusst nicht behoben:** `getProgress` gruppiert die Tage über `performed_at.slice(0, 10)` — also nach UTC-Tag, nicht nach dem Tag der Studio-Zeitzone. Wer um 01:00 MESZ trainiert, dessen Satz zählt zum Vortag. Der Fall ist selten (Studios schließen), die Korrektur bräuchte auch hier den Zeitzonen-Parameter, und sie verschöbe historische Punkte einer Kurve rückwirkend. Festgehalten, damit es niemand für einen Zufallsfund hält.

`exercises` hängt am Studio, nicht am Gerätemodell (`0005_exercises.sql`); der Name allein („Beidbeinig") trägt keine Bedeutung. Deshalb ist das Label kein Schmuck, sondern die halbe Beschriftung.

### 3.4 Der Name: eine Insert-Policy statt eines Auth-Triggers

**Ausgangslage.** `profiles` existiert seit `0001_tenancy.sql` mit `display_name`, hat `profiles_select_own` und `profiles_update_own` — aber **keine Insert-Policy und keinen Trigger**. `0035_kurse.sql` hält es ausdrücklich fest: „keine Zeile Produktivcode füllt die Spalte". Es gibt für kein Mitglied eine Zeile.

**Entschieden:**

- Migration: `profiles_insert_own` (`with check (id = auth.uid())`)
- `PUT /api/v1/me/profile` mit `{ displayName }` — legt an oder ändert, ein Schreibweg für Registrierung *und* späteres Ändern
- `GET /me/bootstrap` trägt `member: { displayName: string | null }` — der Lesepfad hängt an dem Abruf, der ohnehin bei jedem Start läuft

**Warum kein `SECURITY DEFINER`-Trigger auf `auth.users`.** Er wäre die übliche Supabase-Antwort und würde den Namen atomar bei der Anmeldung setzen. Er deckt aber nur Neuregistrierungen ab — jedes Bestandsmitglied bräuchte trotzdem den Schreibweg aus dem Profil. Ein Mechanismus, der zwei Wege ersetzt, ist besser als ein zweiter neben ihnen.

**Der bekannte Preis:** schlägt der `PUT` direkt nach der Registrierung fehl (kein Netz im Keller), ist der Name weg, bis ihn jemand im Profil setzt. Das ist vertretbar — der Gruß ist Zierde, kein Trageteil. Kein Wiederholungsmechanismus, keine Warteschlange: `PendingWriteStore` ist für Sätze da, und ein Vorname, der sich nachholen lässt, rechtfertigt keinen zweiten.

### 3.5 Korrektur an M1 §6.3

Der Satz „Sechs Endpoints für die gesamte Member-App" stimmt weiterhin nicht: SP1 hat drei Studio-Endpoints ergänzt, SP2 den Tag-Kontext, SP3 die Kurse. `PUT /me/profile` ist der nächste Zusatz. Die Architekturaussage dahinter — screenorientiert statt ressourcenorientiert, keine Fachlogik im Client — bleibt unangetastet und wird von diesem Sub-Projekt an drei Stellen bestätigt: Wochengrenze, Gesamtzahl und Gerätelabel rechnet der Server.

---

## 4. Verlauf

### 4.1 Was ohne Netz noch wahr ist

`KurseHerkunft` (SP3) sagt: eine Belegungszahl veraltet binnen Minuten, ohne dass jemand etwas tut — also fällt sie ohne frischen Abruf weg. **Der Verlauf ist das Gegenteil: er ändert sich ausschließlich durch das eigene Tun.** Ein Training von gestern ist morgen noch genau so gewesen.

Die Fünf-Minuten-Grenze aus SP3 wäre hier deshalb falsch. Sie würde einen zehn Minuten alten Verlauf als „veraltet" etikettieren und ein Datum über etwas setzen, das noch stimmt.

Zwei Zahlen sind trotzdem verderblich — nicht wegen des Servers, sondern wegen der Uhr: **„2 diese Woche" und „3 Tage her"** wandern über Mitternacht und über den Wochenwechsel, während die Liste darunter richtig bleibt.

**Daraus folgt:**

- Der Cache trägt Liste, Fortschritt und Kennzahlen **zusammen**, mit einem Abrufzeitpunkt
- Scheitert der letzte Abruf, steht der `Zahlformat.stand`-Satz **über der Kopfzeile** — der ganze Screen ist dann ehrlich datiert, statt dass eine einzelne Zahl still driftet
- Die Wochengrenze wird **nicht** ein zweites Mal im Client gerechnet

Der letzte Punkt ist die Lehre aus dem Kommentar in `KurseHerkunft`: drei Screens mit drei Antworten auf dieselbe Bedingung, „genau das war M1, M2 und M3".

**`VerlaufHerkunft` statt Erweiterung von `KurseHerkunft`.** Drei Zustände — `frisch`, `ohneEmpfang`, `serverfehler` —, kein `veraltet`, kein `zeigtBelegung`: beide sind für Kurse richtig und für den Verlauf sinnlos. Gemeinsam ist nur der **Satzbau** („Ohne Empfang. Stand: …"), und der zieht in eine Stelle, die beide benutzen, statt abgeschrieben zu werden.

### 4.2 Home: zwei Zustände eines Screens

**Leer** (`HomeLeer.dc.html`): der Gruß, die drei nummerierten Schritte, „Erstes Gerät" — der Knopf öffnet das `ScannerSheet` aus SP3, den dritten Aufrufer derselben Komponente. Kein vierter Scanner.

**Gefüllt** (`Home.dc.html`): Kopfzeile mit den drei Kennzahlen, „Letzte Trainings", „Übungsfortschritt · letzte 3 Monate".

**Die laufende Einheit gehört nicht in die Liste.** `getSessions` liefert auch die Einheit ohne `completedAt`; sie erscheint im Training-Tab, nicht unter „Letzte Trainings". Was heute noch läuft, ist kein Verlauf.

**Selbsttätig beendete Einheiten zeigen keine Dauer.** Sie tragen „AUTO BEENDET" (so das Artboard) und die Zahlen der Geräte und Sätze. `getSessions` setzt ihr `completedAt` auf den letzten Satz — bewusst, damit eine vergessene Einheit nicht rückwirkend Stunden dauert, in denen niemand trainiert hat. Genau deshalb ist die daraus gerechnete Dauer eine Untergrenze und keine Dauer; sie wird nicht gezeigt.

**Die Hinweiszeile** ganz oben („Du gehörst jetzt zu Kraftwerk Nord." / „Südbad Fitness ist jetzt aktiv.") ist die einmalige Folge eines Scans. Sie lebt nur im Speicher, kommt aus dem Beitritts- und Wechselweg und verschwindet beim nächsten Start — deshalb eine Zeile und keine Karte mit Schließen-Kreuz.

### 4.3 Session-Detail

Titelzeile mit Datum, Zeitraum, Dauer, Geräte- und Satzzahl; darunter die Blöcke mit ihren Sätzen, RIR nur, wo einer erfasst wurde.

Es braucht **keinen neuen Endpoint**: `getSessions` liefert die Blöcke bereits mit, abgeleitet aus den Sätzen und gruppiert nach (Gerät, Übung). Ein zweiter Durchgang am selben Gerät trifft denselben Block, statt einen neuen anzulegen.

**Keine Vorschläge auf diesem Screen.** Sie gehören zum Abschluss (SP3). Für selbsttätig beendete Einheiten existiert gar keine Vorschlagszeile — `abschluss.ts` hält ausdrücklich fest, warum das so bleibt. Ein Abschnitt, der bei jeder vergessenen Einheit leer bliebe, gehört nicht auf den Screen.

`Zahlformat.uhrzeit` trägt die Zeitangaben; der Tageswechsel über Mitternacht ist in SP3 bereits gelöst.

### 4.4 Übungsfortschritt

Eine Kurve je Übung, Swift Charts, ohne externe Abhängigkeit. Umgesetzt nach §13:

- Eine Serie, eine Farbe (`accent`), keine Legende — der Titel benennt sie
- Linie 2 pt, Messpunkte ≥ 8 pt, Gitter in `line`, Achsenbeschriftung in `text-faint`
- Direkte Beschriftung nur an Anfang und Ende
- **Die Achse beginnt nicht bei null**, der Bereich wird stattdessen sichtbar beschriftet — Trainingsgewichte bewegen sich in einem schmalen Band, eine Nullachse macht jeden Fortschritt unsichtbar
- **Unter dem Diagramm stehen die Rohwerte** der letzten Einheiten. Die Plattform misst nichts; die Kurve ist eine Zusammenfassung und muss nachprüfbar bleiben

**Der Zeitraum-Umschalter (3 Monate · 6 Monate · Alles) filtert lokal** aus einem Abruf ohne `since`. Drei Umschaltungen wären sonst drei Netzabrufe — und ohne Netz wären zwei der drei Knöpfe tot. Der `since`-Parameter bleibt am Endpoint, ungenutzt vom Client; er kostet nichts und deckelt bei Bedarf den Serveraufwand.

**VoiceOver** (§12): Beschriftung „Gewichtsverlauf Beinpresse, Beidbeinig", Audio Graph oder Wertetabelle als Alternative. Die Rohwerte unter dem Diagramm sind diese Tabelle — sie muss nicht zweimal gebaut werden.

---

## 5. Profil & Name

### 5.1 Der Vorname bei der Registrierung

`MemberRegistrierenView` bekommt ein Feld vor der Mailadresse. Der Screen wurde in SP1 abgenommen und wird damit wieder aufgemacht — das ist der bewusst gezahlte Preis dafür, dass Home und Profil einen Namen haben.

Geschrieben wird nach der Code-Bestätigung, sobald eine Sitzung besteht, über `PUT /me/profile` (Abschnitt 3.4). Kein Signup-Metadatum, kein Trigger.

### 5.2 Das Profil nach Artboard

Kopfkarte (Initialen · Name · Mail), „Beim Training" mit den drei Schaltern, „Deine Daten" mit dem Produktgrenze-Satz, Abmelden, Fußzeile mit Version und aktivem Studio.

**Ohne Namen wird nichts erfunden.** Wer keinen gesetzt hat, sieht die Mailadresse allein — keine Initialen aus dem Mail-Präfix, kein „Hallo" auf Home. Aus `lena.wagner@…` „LW" abzuleiten wäre geraten, und geraten sieht so lange richtig aus, bis es jemanden trifft, dessen Adresse nicht sein Name ist.

**Die Kopfkarte wird antippbar** und öffnet ein Sheet mit einem einzigen Feld — im Artboard ist sie statisch. Begründete Abweichung: die Registrierung erfragt den Vornamen erst ab jetzt, jedes Bestandsmitglied braucht einen Weg dorthin, und ein eigener Screen nur dafür wäre Verschwendung.

### 5.3 Die drei Schalter kommen an eine Stelle

Heute steht `@AppStorage("rirSichtbar")` mitten in `GeraetView` (Zeile 195). Ein `Einstellungen`-Typ hält die Schlüssel, die Screens lesen von dort:

| Schalter | Schlüssel | Zustand heute |
| --- | --- | --- |
| Reserve (RIR) abfragen | `rirSichtbar` | vorhanden, SP2 hat vorgesorgt — **der Schlüsselname bleibt wörtlich**, sonst verlieren Bestandsinstallationen ihre Einstellung |
| Pause zwischen Sätzen | neu | `Resttimer.dauer` ist heute `static let … = 90`; wird zur Vorgabe |
| Vibration beim Sichern | neu | die Haptik selbst gibt es nicht — sie kommt mit |

**Die Haptik wird gebaut, nicht nur geschaltet.** Heute vibriert nur das Rastrad und der Scanner; die Hauptaktion — der meistgetippte Knopf der App, oft mit Blick aufs Gerät statt aufs Telefon bedient — gibt kein Signal. §6 verlangt: „Haptik nie als einzige Rückmeldung"; die sichtbare Bestätigung bleibt daneben bestehen. Ein Schalter für etwas, das es nicht gibt, wäre dieselbe Unwahrheit wie der in SP3 gestrichene Link „Training im Detail ansehen".

### 5.4 Die Datenschutzzeile hängt an einer URL

Die Zeile öffnet eine Adresse, die der Betreiber liefert. Sie liegt als Wert in `AppConfig`; **ist der Wert leer, erscheint die Zeile nicht.** Damit kann sie nie ins Leere führen, und das Bauen wartet nicht auf einen Rechtstext.

Der Produktgrenze-Satz darüber („gymodo misst nichts. Gespeichert wird nur, was du selbst bestätigst …") bleibt unabhängig davon stehen — er ist inhaltlich das Wichtigste an diesem Abschnitt und braucht kein Ziel.

---

## 6. Abweichungen vom Artboard

| Artboard | Element | Entscheidung | Grund |
| --- | --- | --- | --- |
| `Profil` | Kopfkarte statisch | wird antippbar | Bestandsmitglieder brauchen einen Weg zum Namen (5.2) |
| `Profil` | Initialen „LW" | nur mit gesetztem Namen | aus der Mailadresse geraten (5.2) |
| `Profil` | „Datenschutzerklärung" | nur mit hinterlegter URL | kein Bedienelement ohne Ziel (5.4) |
| `Home` | „34 gesamt" | vom Server gezählt | über 50 Einheiten sonst still falsch (3.2) |
| `Home` | „2 diese Woche" | entfällt ohne aktives Studio | keine Woche ohne Zeitzone (3.2) |
| `Home` | Dauer bei „AUTO BEENDET" | nicht gezeigt | Untergrenze, keine Dauer (4.2) |

---

## 7. Tests

**Zuerst, vor jeder Erweiterung** (Abschnitt 3.1):

- `getSessions`: Blöcke aus Sätzen gruppiert nach (Gerät, Übung); zweiter Durchgang trifft denselben Block; Blockreihenfolge nach erstem Satz; Vier-Stunden-Regel setzt `completedAt` auf den letzten Satz und `completedReason` auf `auto`; eine laufende Einheit bleibt offen; `machineCount` zählt Geräte, nicht Sätze
- `getProgress`: schwerster Satz je (Übung, Tag); `changeKg` von erstem zu letztem Punkt; `since` schneidet ab; leere Historie ergibt leere Liste

**Danach zu den Erweiterungen:**

- `summary`: `totalCount` über der Liste von 50; `thisWeekCount` an der Wochengrenze in der Studio-Zeitzone, `null` ohne Parameter; `lastSessionAt` bei leerer Historie `null`
- `machineLabel` kommt vom jüngsten Satz, auch wenn ältere Sätze ein anderes Gerät tragen
- `PUT /me/profile`: legt an, ändert, weist fremde `id` ab; `bootstrap` liest `null` für ein Mitglied ohne Zeile

**iOS, reine Ableitungen ohne UI:** `VerlaufHerkunft`; die Zeitraumfilter des Diagramms; die Auswahl der Kurvenbeschriftung (Anfang/Ende); das Weglassen der Dauer bei `auto`; das Ausblenden der laufenden Einheit; die Initialen aus einem gesetzten Namen (und ihr Ausbleiben ohne).

**Verifikation** — unverändert aus SP2/SP3: Kaltbau mit isoliertem `-derivedDataPath`, Verzeichnisse danach löschen (in SP2 waren es am Ende 5,2 GB und ein Testlauf, der an einer vollen Platte scheiterte). Die vier vorbestehenden Warnungen aus SP1 bleiben; **jede Warnung in einer Datei, die dieses Sub-Projekt schreibt, ist seine eigene.**

---

## 8. Selbstprüfung

- Kein Bedienelement ohne Ziel: die Datenschutzzeile erscheint nur mit URL, der Vibrationsschalter erst mit der Haptik dahinter.
- Keine Zahl ohne Deckung: `totalCount` vom Server, `thisWeekCount` nur mit Zeitzone, keine Dauer bei selbsttätigem Abschluss, keine Initialen ohne Namen.
- Keine zweite Antwort auf eine bestehende Frage: die Wochengrenze rechnet nur der Server, der Satzbau der Herkunft steht an einer Stelle, der Scanner bleibt eine Komponente.
- Zwei ungetestete Module, auf denen dieses Sub-Projekt aufsetzt, werden getestet, bevor sie erweitert werden.
- Der einzige noch fehlende Wert ist die Datenschutz-URL; sie blockiert nichts.

---

## 9. Nächste Schritte

Nach Freigabe: `writing-plans`-Skill für den Umsetzungsplan, danach `subagent-driven-development`.

**Offen aus SP2 und SP3, nicht Teil dieses Dokuments:** die manuellen Abnahmen (`2026-09-08-geraet-kernflow-abnahme.md`, `2026-09-09-training-kurse-abnahme.md`). Keine ihrer Positionen betrifft eine Datei, die dieses Sub-Projekt anfasst; die Arbeiten blockieren einander nicht.
