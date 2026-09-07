# gymodo — Member-App Design-Challenge (M1-Canvas)

**Stand:** 7. September 2026
**Status:** Entschieden und umgesetzt. Ursprünglich als reine Kritik-/Befund-Sammlung angelegt (Abschnitte 1–4 unverändert als Nachweis erhalten); Abschnitt 5 dokumentiert die am selben Tag getroffenen Entscheidungen und die daraufhin an Artboards und Designsystem-Spec vorgenommenen Änderungen.
**Scope:** Alle 33 Artboards der Member-App-Canvas (`docs/superpowers/design/member/`) plus `Fundament.dc.html`, geprüft gegen `2026-08-30-designsystem.md`.
**Methodik:** Vier unabhängige Reviews (Flow-Gruppen Zugang/Einstieg, Gerät-Kernflow, Training/Kurse, Home/Profil/Web-Fallback), jeweils gegen zwei externe Kritik-Linsen geprüft — **apple-design** (Apples Fluid-Interfaces-/Motion-Prinzipien, Response, Interruptibility, Spatial Consistency, Materials, Typografie) und **emil-design-eng** (Animation-Decision-Framework, Craft-Checkliste, Before/After-Format) — sowie gegen die projekteigenen, teils als "nicht verhandelbar" markierten Regeln aus dem Designsystem selbst.

---

## 1. Zusammenfassung — sechs projektweite Themen

### 1.1 Die "genau eine Akzentfläche je Screen"-Regel ist die am häufigsten gebrochene Regel der ganzen Canvas

Das ist der mit Abstand wichtigste Einzelbefund. §2 der Designsystem-Spec markiert die Regel ausdrücklich als *nicht verhandelbar* — begründet damit, dass der Akzent im Halbdunkel in einer Sekunde erkennbar bleiben muss. In der Praxis wird sie in **allen vier** geprüften Flow-Gruppen wiederholt verletzt, teils mehrfach auf demselben Screen:

| Screen | Zahl gleichzeitiger Akzentflächen | Flow-Gruppe |
| --- | --- | --- |
| `Uebungsfortschritt.dc.html` | 5 (Delta-Wert, Zeitraum-Chip, 3× Rohwert-Delta) — zusätzlich zur legitimen Kurve | Home/Profil |
| `FallbackAushang.dc.html` | 6 (3 Häkchen-Icons, 2 Schrittnummern, CTA) | Web-Fallback |
| `Kurse.dc.html` | 4 (Tageschip, 2 Fortschrittsbalken, Statuschip) | Training/Kurse |
| `Home.dc.html` | 4 (Banner, Stat-Zahl, 2 Deltas) | Home/Profil |
| `LoginMail.dc.html` | 2 (Pending-Route-Banner + Button) | Zugang |
| `MemberPasswort.dc.html` | 2 (nicht überschriebener Link-Default + Button) | Zugang |
| `HomeLeer.dc.html` | 2 (Wechsel-Banner + CTA) | Home/Profil |
| `GeraetWertRad.dc.html` | 2 (gefüllter Reserve-Chip + Button) | Gerät |
| `KursDetail.dc.html` | 2 (Fortschrittsbalken + Button) | Training/Kurse |

Positiv-Gegenbeispiele, die zeigen, dass die Regel im Prinzip funktioniert: `SessionDetail.dc.html`, `MemberKeinStudio.dc.html`, `MemberScanner.dc.html`, `KurseMeine.dc.html`, `FallbackInaktiv.dc.html`, die vier Training-Screens (13–16) — halten die Regel diszipliniert ein. Der Bruch ist also kein systematisches Missverständnis der Bausteine, sondern eine Screen-für-Screen-Entscheidung, meist an Stellen, wo ein zweiter Wert (Delta, Fortschritt, Status) "auch irgendwie wichtig" wirkte.

**Konsequenz:** Vor der Swift-Implementierung muss entweder (a) jeder der oben gelisteten Screens bereinigt werden, oder (b) die Regel bekommt eine eng gefasste, explizit dokumentierte Ausnahme (z. B. "positive/negative Delta-Farbe ist erlaubt, zählt aber nicht als Akzentfläche"). Der aktuelle Zustand — Regel "nicht verhandelbar", aber in der Hälfte der Screens verhandelt — ist die schlechteste Option.

### 1.2 Dieselbe Kategorie: "warn nur als Umriss, nie als Fläche" — zweimal exakt an den heikelsten Stellen gebrochen

Zweite nicht-verhandelbare Farbregel aus §2, verletzt in:
- `GeraetProblem.dc.html` — gefüllter `#FFB020`-Kreis als Auswahl-Badge für den Grund einer Problemmeldung.
- `Kurse.dc.html` — zu 100 % mit `#FFB020` gefüllter Fortschrittsbalken beim Warteliste-Kurs "Spinning".

Beide Fälle sitzen an inhaltlich sensiblen Stellen (Problemmeldung/Gesundheit bzw. der einzige "etwas läuft nicht ideal"-Zustand im Kurse-Flow) — genau dort, wo die Spec selbst warnt: "Eine warngelbe Fläche würde sie als Fehlverhalten lesen lassen."

### 1.3 Die zentrale, am häufigsten ausgelöste Geste der ganzen App hat keine Bewegungs-Spezifikation

Das Öffnen beider Werte-Räder per Tap (`Main` → `GeraetWertRad`) ist laut Canvas-Annotation "das Herzstück" und wird laut Interaktionsbudget (§9) mehrfach pro Satz, also dutzende Male pro Trainingseinheit ausgelöst. Für genau diese Geste fehlt vollständig: Spring-/Dämpfungswerte, Momentum-Projektion beim Loslassen, Velocity-Handoff, Interruptibility-Verhalten, Rubber-Banding am Gerätemaximum/-minimum. §7 beschreibt in Prosa *was* passieren soll ("Bewegung statt Aufbau", "gleiche Silhouette"), aber nicht *wie*. Dieselbe Lücke zieht sich weiter: kein Feedback-Timing für "Satz sichern", kein Erfolgs-Feedback beim Scan (NFC/QR), keine Spec für den Reconnect-Moment nach Offline, kein `:active`-Press-Feedback für einen einzigen Button in der gesamten Canvas.

### 1.4 Die "gleiche Silhouette" wird durch die Typografie selbst gebrochen

§7 verspricht wörtlich, dass der gewählte Wert beim Öffnen des Rads Größe und Akzentlinie behält. Gemessen an den tatsächlichen `font-size`-Werten stimmt das nicht:

| Screen | Gewicht-Held-Wert | Wdh.-Held-Wert |
| --- | --- | --- |
| `Main.dc.html` (Ruhe) | 64px | 44px |
| `GeraetWertRad.dc.html` (Offen) | 64px | **50px** |
| `GeraetErsteWerte.dc.html` (Erstkontakt) | **58px** | 44px |
| `Uebungsfortschritt.dc.html` (Verlauf-Hero) | **52px** (statt der für "Wert (Held)" vorgeschriebenen 64–72px, dazu fehlt die 4pt-Akzentlinie) | — |

Kein Geschmacksurteil — direkt mit Zahlen aus der eigenen Spec widerlegbar, und ausgerechnet auf dem Screen, der die Rad-Geste zum ersten Mal einführt (`GeraetErsteWerte`).

### 1.5 Fehler-, Sicherheits- und Edge-Zustände fehlen systematisch, gerade dort wo die Spec sie am dringendsten verlangt

- **Zugang/Login:** Kein einziger der 8 Screens zeigt falsches Passwort, gesperrtes/unbekanntes Konto, bereits vergebene E-Mail oder Netzwerkausfall — obwohl §5 exakt vorschreibt, wie Fehler aussehen müssen ("was ist falsch UND was gilt"), und die Sicherheitsanforderung "unbekannt/ungültig/gesperrt = gleiche Antwort" hier ihren wichtigsten Anwendungsfall hat.
- **Kurse:** Kein Skelett-, Leer-, Offline- oder Fehlerzustand über alle drei Screens; `KursDetail.dc.html` zeigt nur "Plätze frei, nicht angemeldet" — nicht "Kurs voll", "bereits angemeldet" oder "Kurs vorbei", obwohl der Screen laut Titel explizit "Detail und Anmeldung" leistet.
- **Training:** Der in der Annotation geforderte "auto beendet"-Zustand (Session endet träge nach vier Stunden ohne Satz) fehlt in beiden Kandidaten-Screens (`TrainingLaeuft`, `TrainingAbschluss`).
- **Gerät:** Positiv-Ausnahme — `GeraetOffline.dc.html` setzt §5 vorbildlich um; einzige Lücke dort ist der fehlende Reconnect-Moment.
- **Scanner/Kaltstart:** Der von der Canvas-Annotation selbst als härtester Fall benannte Zustand ("App fehlt, iPhone, Universal Link landet in Safari, App startet nach Installation bei null") hat in keinem der Zugangs-Screens eine visuelle Entsprechung — die Web-Fallback-Screens lösen einen verwandten, aber nicht identischen Fall.

### 1.6 Baustein-Bibliothek (`build.py`) wird nicht konsequent verwendet

`PRIMARY` (64px/radius 16) und `NEBEN` (46–52px, Umriss) sind als gemeinsame Konstanten dokumentiert, weichen aber wiederholt ab: `GeraetProblem`-Hauptaktion 60px statt 64px, `FallbackGeraet`/`FallbackAushang`-CTA 54px statt 64px, `TrainingLaeuft`-Nebenaktion in Farbe/Höhe abweichend von der `NEBEN`-Konstante. Zusätzlich nutzen die drei Web-Fallback-Screens drei verschiedene technische Grundlagen (zwei verschiedene Frame-Maße 390×844 vs. 393×852, zwei verschiedene Schriftstacks System vs. Archivo/Google-Fonts) für dieselbe Funktion — obwohl `build.py` für die nativen Screens genau das verhindern soll.

---

## 2. Priorisierte Klärliste vor Swift-Start

Diese Punkte blockieren aus Sicht der Reviews am ehesten eine widerspruchsfreie Implementierung:

1. **Entscheidung zur Akzentflächen-Regel treffen** (§1.1/1.2) — bereinigen oder Ausnahme dokumentieren, bevor der erste SwiftUI-Screen gebaut wird. Sonst entscheidet jeder Screen das für sich.
2. **Spring-/Motion-Spec für die Rad-Geste ergänzen** (§1.3) — konkrete `damping`/`response`-Werte, Momentum-Projektionsformel, Rubber-Banding an den Grenzen. Höchste Priorität, weil am häufigsten benutzt.
3. **Held-Wert-Größen vereinheitlichen** (§1.4) — 64px Gewicht / 44px Wiederholungen als einzig gültige Werte für die Satz-Wertzeile in jedem Zustand (Ruhe, Offen, Erstkontakt) festschreiben.
4. **Scanner-Navigationsmodell klären** — Designsystem §11 nennt "Scan-Sheet", `MemberScanner.dc.html` zeigt Push-Navigation (Zurück-Chevron). `.sheet()` vs. `NavigationStack` entscheidet über Wisch-Geste, Eck-Radius, Dismiss-Verhalten und muss vor dem Bau feststehen.
5. **NFC/QR-Gleichwertigkeit vereinheitlichen** — `TrainingLeer` (NFC-lastig) und `TrainingScan` (QR-lastig) widersprechen sich in genau entgegengesetzte Richtungen; das unterläuft die Annahme, ein A/B-Test-Schwenk koste "nur Text".
6. **Fehlerzustände für Login/Registrierung mindestens einmal durchspielen** — die Sicherheitsanforderung "unbekannt/ungültig/gesperrt = gleiche Antwort" braucht einen sichtbaren Referenzzustand, sonst entscheidet die Implementierung uneinheitlich.
7. **Web-Fallback-Screens auf eine gemeinsame technische Basis heben** (Frame, Schrift, CTA-Höhe) und Sticky-CTA für kleine Viewports (iPhone SE) prüfen — der Funnel kann sonst genau an der Konversionsstelle unter die Sichtgrenze rutschen.
8. **Zwei Formulierungs-Widersprüche klären:** ob `HomeLeer`/`Home`-Wechselbanner-Texte vertauscht sind (Beitritt vs. Wechsel), und ob "Rückt jemand ab, bekommst du den Platz automatisch" (`KurseMeine.dc.html`) zum aktuellen Planungsstand von `2026-08-30-kurse-datenmodell.md` passt (Nebenläufigkeit bei Platzvergabe ist dort offen).

---

## 3. Detailbefunde je Flow-Gruppe

### 3.1 Zugang & Einstieg — LoginMail, LoginCode, MemberRegistrieren, MemberPasswort, MemberPasswortAendern, MemberKeinStudio, MemberScanner, MemberStudios

**Gruppen-Fazit:** Titel-Abstände liegen screenübergreifend fast durchweg außerhalb der dokumentierten Skala (34/26/40/20px statt 16/24/32) — selbst strukturell identische Wurzel-Screens (`LoginMail`, `MemberKeinStudio`) weichen ohne erkennbaren Grund voneinander ab, weil der `titel()`-Baustein seinen `top`-Wert frei statt aus einem festen Satz erhält. Fehler-/Sicherheitszustände fehlen praktisch komplett (siehe §1.5). Das Scan-Sheet-Navigationsmodell ist unklar (siehe §2.4).

Wichtigste Einzelbefunde:
- **LoginMail:** Pending-Route-Banner in Akzentfarbe neben Akzent-Button (Regel-Bruch §1.1); kein Fehlerzustand für Login überhaupt gezeigt.
- **LoginCode:** "Noch zwei Ziffern" (die einzige Erklärung für den deaktivierten Zustand) steht bei 12px in `text-faint` — unterschreitet die für tragende Information vorgeschriebene Kontraststufe; kein Auto-Submit-Verhalten bei 6. Ziffer spezifiziert.
- **MemberRegistrieren:** Passwort-Mindestlänge ohne Live-Validierung (apple-design fordert "validate inline"); Hinweistext ebenfalls zu blass; ungeklärt, ob bereits vergebene E-Mail offen gemeldet wird (Informationsleck) oder neutral bleibt.
- **MemberPasswort:** globaler Link-Default (`a { color: accent }`) nicht überschrieben → zweite Akzentfläche; der sicherheitskritische neutrale Satz ("Wenn es zu dieser Adresse ein Konto gibt…") steht in `text-faint`; zwei Zustände (Anfordern/Zurücksetzen) unklar gleichzeitig oder nacheinander dargestellt.
- **MemberPasswortAendern:** kein Fehlerzustand für "aktuelles Passwort falsch" — der wahrscheinlichste Fehlerfall des Screens.
- **MemberKeinStudio:** Studio-Code-Feld optisch nicht von echter Eingabe unterscheidbar (kein Placeholder-Dimming wie bei `MemberRegistrieren`); kein deaktivierter Zustand für "Beitreten" in `build.py` vorgesehen.
- **MemberScanner:** Widerspruch Sheet (Spec) vs. Push (Artboard); kein sichtbares Erfolgs-Feedback nach Scan — verstößt gegen die explizite Regel "Haptik nie als einzige Rückmeldung" (§6); der von der Annotation benannte Kaltstart-Fall fehlt als Screen komplett.
- **MemberStudios:** "Verlassen" und "Studio wechseln" liegen ohne Pufferzone in einer Zeile; kein Bestätigungsdialog für eine laut apple-design (Agency-Prinzip) klar destruktive, irreversible Aktion; Konsequenz-Satz dazu in `text-faint`.

### 3.2 Gerät-Kernflow — GeraetErkannt, Main, GeraetWertRad, GeraetResttimer, GeraetEinweisung, GeraetKalibrierung, GeraetErsteWerte, GeraetUebungWechseln, GeraetProblem, GeraetOffline

**Gruppen-Fazit:** Die insgesamt handwerklich stärkste Gruppe (u. a. `GeraetOffline` und `GeraetProblem`-Textarbeit als Bestwerte der ganzen Canvas), aber mit den schwerwiegendsten Einzelverstößen: beide nicht-verhandelbaren Farbregeln brechen hier je einmal exakt an der heikelsten Stelle (§1.2), und der zentralen Geste fehlt die Bewegungs-Spec komplett (§1.3, §1.4).

Wichtigste Einzelbefunde:
- **GeraetErkannt:** "Erkannt"-Badge trägt unnötig Akzentfarbe neben der aktiven Übungszeile; kein VoiceOver-Label für die Übungsliste in §12 definiert.
- **Main:** "andere Übung"-Link in Akzentfarbe (dritte Akzentquelle neben Wertlinie/Vorschlag); Button-Text ("Satz 1 sichern") divergiert vom vorgeschriebenen VO-Label (inkl. Gewicht) ohne Hinweis auf nötiges manuelles Label; Skelett-Einsatz für Video-Metadaten (Titel/Dauer) fraglich nach §5 ("nur für Medien").
- **GeraetWertRad:** gefüllter Reserve-Chip verletzt §1.1; keine Scroll-Physik/Momentum-Spec; Wdh.-Wert 50px statt 44px (§1.4); kein Anschlag-Feedback für sehende Nutzer (nur VO-Ansage in §12 vorgesehen).
- **GeraetResttimer:** Reduce-Motion-Fallback ("springt sekundenweise") nicht als umsetzbare Spec präzisiert; "+30s"-Trefferfläche im Mockup ohne erkennbares Padding; Live-Region-Drosselung (§12: max. alle 15s) nicht am Screen vermerkt, Risiko einer naiven 1:1-Kopplung an die sekündliche Anzeige.
- **GeraetEinweisung:** die in der Annotation versprochene "ohne Video"-Variante fehlt unter den 33 Screens; "Kenne ich schon"-Link könnte laut Beschriftung den gesamten Dreischritt überspringen, was der "kein Vorschlag beim ersten Mal"-Regel widerspricht, falls dabei kein Startwert existiert.
- **GeraetKalibrierung:** deaktivierter Stepper nutzt falsches Elevation-Token (`surface` statt `surface-raised`, §5).
- **GeraetErsteWerte:** Gewicht-Held-Wert 58px statt 64px (§1.4) — ausgerechnet beim ersten Kontakt mit der Rad-Geste.
- **GeraetProblem:** gefülltes Warn-Badge verletzt §1.2; Hauptaktion 60px statt 64px (`build.py`-Abweichung).
- **GeraetOffline:** kein Zustand für den Reconnect-Moment (Warteschlange synct) spezifiziert — sonst die sauberste Umsetzung von §5 im ganzen Satz.

### 3.3 Training & Kurse — TrainingLeer, TrainingLaeuft, TrainingScan, TrainingAbschluss, Kurse, KursDetail, KurseMeine

**Gruppen-Fazit:** Klarste Zweiteilung der ganzen Canvas: Training (13–16) hält die Akzentregel diszipliniert ein, Kurse (17–19) bricht sie mehrfach gleichzeitig plus die Warn-Regel (§1.1/1.2) — deckungsgleich mit dem in den Annotationen selbst benannten Reifegradunterschied ("gestaltet, aber nicht gebaut"). NFC/QR-Bias läuft in den beiden Einstiegsscreens in entgegengesetzte Richtungen.

Wichtigste Einzelbefunde:
- **TrainingLeer:** NFC bekommt Hero-Illustration + eigene Headline, QR nur einen Textbutton — widerspricht "gleichwertig nebeneinander" (§11) stärker als von der Annotation ("kostet nur Text") behauptet.
- **TrainingLaeuft:** "auto beendet"-Kennzeichnung fehlt (Annotation verlangt sie explizit); kein Übergangs-Feedback für "erster Satz gesichert → Training läuft" (kein Startknopf, also braucht der implizite Start eine State-Indication).
- **TrainingScan:** umgekehrter Bias — QR dominant, NFC klein; Close-Button 34px statt 44pt (§4); kein Erfolgs-/Fehlerzustand für den Scan selbst; keine Taschenlampe trotz "schummriges Kellerlicht" als explizit genanntem Nutzungskontext (§1).
- **TrainingAbschluss:** "auto beendet" fehlt wiederholt; dieselbe Problemmeldungs-Semantik sieht hier anders aus als auf `TrainingLaeuft` (Rahmen vs. reines Text+Icon).
- **Kurse.dc.html:** Warteliste-Fortschrittsbalken zu 100% mit Warnfarbe gefüllt (§1.2); vier gleichzeitige Akzentflächen (§1.1); Chip-Radius 6px liegt außerhalb der Radius-Skala; uneinheitliche Tap-Affordance (nur eine von vier Zeilen mit Chevron).
- **KursDetail:** zwei Akzentflächen; zeigt nur einen von mehreren nötigen Zuständen (voll/angemeldet/vorbei fehlen), obwohl der Screen laut Titel "Detail und Anmeldung" leistet; keine Bestätigungsanimation für den Anmelden-Tap.
- **KurseMeine:** einziger der drei Kurse-Screens, der die Akzentregel einhält; Warteliste-Text vermeidet korrekt jede Benachrichtigungs-Zusage (positiv geprüft), "automatisch" beim Nachrücken sollte trotzdem gegen den offenen Nebenläufigkeits-Punkt im Datenmodell-Plan geprüft werden; der wichtigste Satz des Screens steht in `text-faint`.

### 3.4 Home, Profil, Web-Fallback — HomeLeer, Home, SessionDetail, Uebungsfortschritt, Profil, FallbackGeraet, FallbackInaktiv, FallbackAushang

**Gruppen-Fazit:** `SessionDetail` und `FallbackInaktiv` sind die sauberste Umsetzung ihrer jeweiligen Kategorie in der ganzen Canvas (Akzentdisziplin bzw. Sicherheitsneutralität); `Home`, `Uebungsfortschritt` und `FallbackAushang` liefern dagegen die höchste Akzentflächen-Dichte aller 33 Screens. Die drei Web-Fallback-Screens sind trotz identischer Funktion technisch uneinheitlich gebaut.

Wichtigste Einzelbefunde:
- **HomeLeer:** Wechsel-Banner in Akzentfarbe neben CTA; Produktgrenze-Kurzform lässt den zentralen Haftungssatz zu Einweisungsvideos weg; Banner-Text könnte mit dem von `Home` vertauscht sein (Beitritt vs. Wechsel, siehe §2.8).
- **Home:** vier Akzentflächen (§1.1) — ausgerechnet auf dem laut Annotation als "Vorführmaterial für den Betreibertermin" bezeichneten Screen; Datum als ausgeschriebener Wochentag, obwohl §10 und `SessionDetail` die Kurzform verlangen bzw. zeigen; ein Delta ohne die vorgeschriebene Nachkommastelle.
- **SessionDetail:** keine funktionalen Mängel gefunden; eine zweite, im Designsystem nicht dokumentierte Titelrolle (28px) taucht konsistent mit `Uebungsfortschritt` auf — sollte in §3 nachgetragen werden, damit sie nicht als Fehler gilt.
- **Uebungsfortschritt:** fünf Akzentanwendungen außerhalb der legitimen Kurve (§1.1); Hero-Wert 52px statt der vorgeschriebenen 64–72px inkl. fehlender Akzentlinie (§1.4); kein "kein Reveal beim Mount"-Hinweis für den Graphen (Banking-Graph-Prinzip aus emil-design-eng).
- **Profil:** zwei Zeilen mit inline überschriebenem Padding unterschreiten die 44pt-Trefferfläche; Produktgrenze-Text lässt den zweiten, haftungsrelevanten Satz weg — genau an der Stelle, die §10 explizit als Pflichtort nennt.
- **FallbackGeraet:** CTA 54px statt 64px Hauptaktion; "Nutzen-dann-Aufforderung"-Funnel ist reine Dokumentreihenfolge ohne Sticky-Absicherung — kann auf kleinen Viewports (iPhone SE) unter die Sichtgrenze rutschen, genau an der Konversionsstelle.
- **FallbackInaktiv:** Sicherheitsneutralität korrekt eingehalten (positiv geprüft); Fußnotentext erklärt dem Endnutzer die interne Sicherheitslogik ("sonst ließe sich durch Ausprobieren…") — liest sich wie eine Entwickler-Notiz im Produkttext statt wie eine Handlungsanweisung.
- **FallbackAushang:** einziger Screen mit sechs gleichzeitigen Akzentanwendungen; nutzt als einziger der drei Fallback-Screens `build.py`-Konvention (Archivo/393×852), während die anderen beiden System-Schrift/390×844 nutzen — trotz identischem Zweck; "nur für iPhone" ohne die abmildernde Android-Zusage, die `FallbackGeraet` bietet.

---

## 4. Offene Entscheidungen (Produkt, nicht nur Design)

- Sheet vs. Push für den Scan-Einstieg (Zugang §2.4).
- Ob bereits vergebene E-Mail bei der Registrierung offen gemeldet wird oder neutral bleibt wie beim Login.
- Ob "Verlassen" eines Studios eine Bestätigung braucht (Agency-Prinzip legt es nahe).
- Ob die Wechsel-/Beitritts-Bannertexte auf `HomeLeer`/`Home` vertauscht sind.
- Ob "automatisch" bei der Kurse-Warteliste zum aktuellen Stand des Nebenläufigkeits-Problems in `2026-08-30-kurse-datenmodell.md` passt.
- Ob eine enge Ausnahme von der Akzentflächen-Regel für Delta-/Fortschrittswerte eingeführt wird, oder ob alle neun in §1.1 gelisteten Screens bereinigt werden.

---

## 5. Entscheidungen und Umsetzung (7. September 2026)

Zwei Punkte klärten sich bei genauerem Lesen von selbst, ohne Team-Entscheidung:

- **`HomeLeer`/`Home`-Bannertexte sind nicht vertauscht.** Inline-Kommentare im Code belegen Absicht: `HomeLeer` trägt die "Wechsel"-Formulierung für ein Mitglied ohne Historie am neuen Studio, `Home` die generische "Beitritt-oder-Wechsel"-Formulierung für ein Mitglied mit bestehender Historie. Keine Änderung.
- **"Automatisch" bei der Kurse-Warteliste ist unproblematisch.** Der Plan verbietet nur ein Benachrichtigungs-Versprechen — `KurseMeine.dc.html` verspricht keins ("du siehst es hier", kein "wir melden uns"). "Automatisch" beschreibt nur die ohnehin geplante Backend-Garantie (Nebenläufigkeit bei Platzvergabe, Punkt 1 der Fachlogik im Datenmodell-Plan). Keine Änderung.

Die übrigen vier Punkte wurden entschieden:

| # | Entscheidung | Ergebnis |
| --- | --- | --- |
| 1 | Akzentflächen-Regel (§1.1) | **Strikt durchsetzen.** Alle 9 betroffenen Screens bereinigt — Delta-/Fortschrittswerte auf `text-muted`, Chips/Balken auf Umriss statt Fläche. |
| 2 | Scanner-Navigation | **Sheet** (wie Spec §11), nicht Push. `MemberScanner.dc.html` umgebaut: Anfasser, obere Ecken gerundet, explizites 44pt-Schließen-Ziel zusätzlich zur Wisch-Geste. |
| 3 | NFC vs. QR | **NFC als visueller Standard**, bis der Trefferquoten-Test aus M0 Task 8 vorliegt. `TrainingScan.dc.html` nach Vorbild `TrainingLeer.dc.html` umgebaut; QR bleibt als gleichwertiger, aber kleinerer zweiter Weg sichtbar. |
| 4 | E-Mail-Enumeration bei Registrierung | **Neutral, wie Login.** Beide Screens zeigen jetzt einen dokumentierten, wortgleich-neutralen Fehler-/Alternativzustand. |
| 5 | "Verlassen" eines Studios | **Bestätigung — aber nativ, kein Custom-Dialog.** `.confirmationDialog`/`.alert` mit festgelegtem Titel/Text, in `MemberStudios.dc.html` als Kommentar hinterlegt; Trefferzonen von "wechseln" getrennt. |

**Umgesetzte Änderungen je Datei** (Artboards, `docs/superpowers/design/member/`):

- **Zugang:** `LoginMail.dc.html` (Banner neutralisiert, Fehlerzustand ergänzt), `LoginCode.dc.html` (Kontrast Hinweistext), `MemberRegistrieren.dc.html` (Kontrast Hinweistext, neutraler "bereits registriert"-Zustand), `MemberPasswort.dc.html` (Link neutralisiert, Kontrast Sicherheitssatz), `MemberStudios.dc.html` (Trefferzonen getrennt, nativer Bestätigungsdialog dokumentiert), `MemberScanner.dc.html` (Push → Sheet).
- **Gerät:** `Main.dc.html` (Sekundärlink neutralisiert), `GeraetWertRad.dc.html` (Reserve-Chip Umriss, Wdh.-Wert 44px), `GeraetProblem.dc.html` (Warn-Badge Umriss, Hauptaktion 64px), `GeraetErsteWerte.dc.html` (Gewicht-Wert 64px), `GeraetKalibrierung.dc.html` (Deaktiviert-Token korrigiert), `GeraetOffline.dc.html` (Zahlengröße vereinheitlicht).
- **Training/Kurse:** `TrainingScan.dc.html` (NFC-dominant, Schließen-Trefferfläche 44pt), `Kurse.dc.html` (Warn-Balken Umriss, Akzentflächen bereinigt, Chip-Radius Pille), `KursDetail.dc.html` (Fortschrittsbalken neutralisiert).
- **Home/Profil/Fallback:** `Home.dc.html` (Akzentflächen bereinigt inkl. Bannerhintergrund, Datum-Kurzform, Delta-Nachkommastelle), `HomeLeer.dc.html` (Banner neutralisiert inkl. Hintergrund), `Uebungsfortschritt.dc.html` (Akzentflächen bereinigt, Hero-Wert 64px + Akzentlinie), `Profil.dc.html` (Trefferfläche korrigiert), `FallbackGeraet.dc.html`/`FallbackAushang.dc.html` (CTA 64px, technische Basis vereinheitlicht), `FallbackAushang.dc.html` zusätzlich (Akzentflächen bereinigt).

**Spec-Änderungen** (`2026-08-30-designsystem.md`): §3 (neue Typografie-Rolle "Detail-Screentitel"), §6 (konkrete Spring-/Momentum-Werte für die Rad-Geste, Reduce-Motion-Präzisierung Resttimer, "kein Reveal"-Regel für den Verlaufsgraph, Press-Feedback-Standard), §10 (neutrale Sicherheitsantwort-Konvention, native Bestätigung für destruktive-aber-nicht-endgültige Aktionen), §11 (NFC-Standard bis Testergebnis, Sheet-Mechanik präzisiert).

**Nicht in dieser Runde angefasst** (kleinere, nicht-blockierende Befunde aus §3, bewusst zurückgestellt): fehlende "ohne Video"-Variante bei `GeraetEinweisung`, uneinheitliche Radius-Zuordnung bei Info-Karten, fehlender deaktivierter Zustand für "Beitreten" in `build.py`, Kurse-Zustände (Skelett/Leer/Offline/Fehler) — bleiben offen, da Kurse laut Datenmodell-Plan ohnehin erst M2 gebaut wird.
