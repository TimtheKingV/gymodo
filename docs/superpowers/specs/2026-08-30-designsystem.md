# gymodo — Designsystem M1

**Stand:** 30. August 2026
**Status:** abgestimmt, Grundlage für die Member-App-Implementierung
**Verhältnis zur M1-Spec:** untergeordnet. `2026-08-28-fitness-retrofit-m1-design.md` bestimmt, *was* die Screens tun; dieses Dokument bestimmt, *wie* sie aussehen und sich anfühlen. Bei Widerspruch gilt die M1-Spec.
**Design-Canvas:** https://claude.ai/code/artifact/4f6035c6-7612-42ed-9791-cf0794713bdd — 27 Artboards. Die Canvas zeigt es, dieses Dokument macht es zitierbar.

---

## 1. Richtung

**Hallenboden.** Nahezu schwarz, ein einziger Signalakzent, übergroße Ziffern.

Die Entscheidung folgt aus dem Nutzungskontext, nicht aus Geschmack: Gerätebereiche liegen häufig im Keller und sind schummrig beleuchtet, die App wird einhändig bedient, während die andere Hand am Gerät liegt, oft mit feuchten Händen, und sie wird zwischen zwei Sätzen für drei Sekunden angesehen. Daraus folgt alles Weitere — große Zahlen, große Trefferflächen, wenig Farbe, keine Dekoration.

Verworfene Alternativen: eine helle, instrumentenhafte Richtung (präziser, aber im dunklen Raum blendend) und eine Beschilderungs-Richtung in warmem Off-White (charaktervoll, aber derselbe Blendungseinwand).

---

## 2. Farbe

| Token | Wert | Verwendung |
| --- | --- | --- |
| `bg` | `#0A0B0D` | Grundfläche |
| `surface` | `#14161A` | Karten, Blöcke, Listen |
| `surface-raised` | `#1D2026` | Sheets, Stepper-Tasten, aktive Zeile |
| `line` | `#2A2E36` | Trennlinien, Umrisse, Gitterlinien |
| `text` | `#F2F4F7` | Fließtext, Werte |
| `text-muted` | `#9BA3AF` | Labels, Sekundärtext |
| `text-faint` | `#5C636E` | Fußnoten, deaktivierte Zustände, Achsenbeschriftung |
| `accent` | `#D4FF3F` | Hauptaktion, aktiver Wert, Verlaufskurve |
| `accent-pressed` | `#A8CC2A` | gedrückte Hauptaktion |
| `on-accent` | `#0A0B0D` | Schrift **auf** dem Akzent |
| `warn` | `#FFB020` | Problemmeldung |
| `danger` | `#FF5A4E` | Offline, Fehler, Abmelden |

**Kontrast gegen `bg`:** `accent` 17,4 : 1 · `text` 17,9 : 1 · `text-muted` 7,4 : 1 · `text-faint` 3,6 : 1. `text-faint` ist damit nur für Text ≥ 15 pt oder nicht-tragende Information zulässig — nie für etwas, das gelesen werden muss.

### Zwei Regeln, die nicht verhandelbar sind

1. **Genau eine Akzentfläche je Screen.** Der Akzent markiert die eine Hauptaktion und den aktiven Wert. Flächig als Dekor eingesetzt verliert er die Signalwirkung, für die er gewählt wurde — und der Nutzer verliert die Fähigkeit, im Halbdunkel in einer Sekunde zu erkennen, wo er hinfassen muss.
2. **Kein reines Schwarz.** `#000000` lässt keinen Raum für Ebenen und schmiert beim Scrollen auf OLED.

`warn` erscheint ausschließlich als **Umriss**, nie als Fläche: eine Problemmeldung ist Feedback des Nutzers, kein Systemfehler. Eine warngelbe Fläche würde sie als Fehlverhalten lesen lassen.

---

## 3. Typografie

**Schrift: SF Pro (System).** Kein Webfont, keine externe Abhängigkeit. Dynamic Type und VoiceOver funktionieren mit der Systemschrift zuverlässig, und die erste externe Abhängigkeit löst laut M1-Spec Abschnitt 9 die Anlage des Privacy Manifests aus. Der Signage-Charakter entsteht aus **Gewicht und Laufweite**, nicht aus einer gekauften Schrift.

*Die Canvas rendert Archivo, weil SF Pro auf Windows nicht verfügbar ist. Die Proportionen entsprechen sich; wo Archivo enger läuft, entspricht dem ein Tracking von −2 % auf SF Pro Black.*

| Rolle | Größe / Gewicht | Besonderheit |
| --- | --- | --- |
| Gerätename | 30–34 pt / Black | Versalien, Tracking −2,5 % |
| Screentitel | 32 pt / Black | Versalien, Tracking −3 % |
| Übungsname | 16–17 pt / Semibold | `text-muted` |
| **Wert (Held)** | 64–72 pt / Black | tabellarisch, Akzent-Unterstrich 4 pt |
| Wert (sekundär) | 17–21 pt / Black | tabellarisch |
| Fließtext | 15–17 pt / Regular | Zeilenhöhe 1,45–1,5 |
| Label | 11 pt / Extrabold | Versalien, Tracking +14 % |

**Alle Ziffern tabellarisch** (`.monospacedDigit()`). Ohne das springt der Resttimer bei jeder Sekunde und die Satzliste flimmert beim Scrollen.

**Zahlformat:** Dezimalkomma, immer mit einer Nachkommastelle bei Gewichten (`80,0 kg`, nie `80 kg`) — sonst wirkt ein Wechsel von `80` auf `82,5` wie ein Formatfehler statt wie eine Steigerung. Einheit immer sichtbar, immer Kilogramm.

---

## 4. Maße

- **Abstandsskala:** 4 · 8 · 12 · 16 · 24 · 32 · 48
- **Radius:** 12 (Karte) · 14 (Nebenaktion, Stepper) · 16 (Hauptaktion) · Pille (Chips)
- **Trefferflächen:** ≥ 44 pt. **Hauptaktion 64 pt hoch**, Nebenaktion 46–52 pt, Radzeile 44 pt.
- **Seitenrand:** 20 pt im Content, 28 pt auf Login-Screens.
- Alles Bedienbare liegt im **unteren Drittel**.

---

## 5. Zustände

Fünf Stile, einmal definiert, überall gleich:

| Zustand | Aussehen | Regel |
| --- | --- | --- |
| **Skelett** | `surface-raised`-Blöcke ohne Animationspflicht | Nur für **Medien**. Werte kommen aus dem Prefetch und sind sofort da — ein Skelett über einer Gewichtszahl wäre eine Lüge über die Architektur. |
| **Leer** | Überschrift + nächster Schritt | Erklärt, was zu tun ist. Nie eine leere Statistik mit Nullen. |
| **Offline** | `danger`-Umriss, 10 % `danger`-Fläche | Formulierung immer „gespeichert, wird gesendet" — **nie** „fehlgeschlagen". Der Satz ist lokal sicher; das muss die Sprache tragen. |
| **Fehler** | `danger`-Umriss, voller Kontrast | Sagt, was falsch ist **und** was gilt („Gewicht liegt über dem Gerätemaximum"), nie nur „ungültig". |
| **Deaktiviert** | `surface-raised` auf `text-faint` | Nie stumm — daneben steht, was fehlt. |

---

## 6. Bewegung

- **Resttimer als linearer Balken, kein Spinner.** Er zeigt Restdauer, nicht Beschäftigung.
- **Reduce Motion** ersetzt jede Animation durch einen Zustandswechsel, nie durch Weglassen der Information. Der Balken springt dann sekundenweise statt zu laufen.
- **Haptik nie als einzige Rückmeldung** (M1-Spec 5.9). Jede Bestätigung ist zusätzlich sichtbar.

---

## 7. Wertwahl — ein Tap, dann scrollen

Gewicht und Wiederholungen stehen **nackt auf der Fläche**: große Zahl, darunter eine Linie. Kein Kasten, kein Rahmen, kein Eingabefeld. **Ein Tap auf eine der beiden Zahlen öffnet beide Räder** — danach wird nur noch gescrollt, ohne weiteren Tap und ohne Tastatur, mit dem Daumen der Hand, die das Handy hält.

**Der Kniff: die Linie bleibt liegen, die Zahlen ziehen daran vorbei.** Es braucht keinen Auswahlbalken und keine Umrandung — die Unterstreichung, die im Ruhezustand schon den aktiven Wert markiert, ist im offenen Zustand die Rastmarke. Damit hat der Screen in beiden Zuständen dieselbe Silhouette, und der Übergang ist eine Bewegung statt eines Aufbaus.

**Es gibt keine ± Tasten.** Sie belegten je 56–62 pt links und rechts vom Wert und lösten nichts, was das Rad nicht schneller löst.

| Zustand | Aussehen |
| --- | --- |
| Ruhe | Wert 64 pt, darunter 4 pt `accent` (Gewicht) bzw. 3 pt `line` (Wiederholungen). Unter der Linie der Kontext: `Vorschlag · +2,5` bzw. `Ziel 8 – 12` |
| Offen | Zwei Nachbarn je Richtung, 30 pt in `text-faint` und 26 pt in `line`, nach oben und unten in `bg` ausgeblendet. Der gewählte Wert behält Größe und Akzentlinie |

**Die Rastung kommt aus dem Gerät, nicht aus dem Entwurf:** `equipment_models.weight_step_kg`. Dieselbe Daumenstrecke deckt an einer Beinpresse mit 2,5-kg-Platten eine andere Spanne ab als an einem Beinbeuger mit 5-kg-Platten. Wiederholungen rasten immer auf 1.

Das Rad ersetzt keinen Wert, es **zeigt die Nachbarn**: wer 80,0 sieht, sieht auch, dass der nächste Schritt 82,5 ist und nicht 81. Die Plattenabstufung des Geräts steht damit in der Bedienung statt in einer Fußnote — der häufigste Fehler beim Eintippen, ein Wert den das Gerät gar nicht kann, wird strukturell unmöglich.

**VoiceOver:** jedes Rad ist ein Bereichsregler (`adjustable`). Auf und Ab gehen genau einen Geräteschritt und sagen den neuen Wert mit Einheit an.

---

## 8. Einstieg nach dem Tap

Nach dem Tap entscheidet die **eigene Historie am Gerät**, wo das Mitglied landet:

| Besuche an diesem Gerät | Genutzte Übungen | Ziel |
| --- | --- | --- |
| 0 — Erstkontakt | – | Gerät erkannt → Einweisung → Kalibrierung → erste Werte → Satz |
| genau 1 | beliebig | Gerät erkannt (die Optionen bleiben sichtbar) |
| ab 2 | mehrere | Gerät erkannt, zuletzt genutzte Übung oben |
| ab 2 | immer dieselbe | **direkt zum Satz** |

**Der Erkennungs-Screen zeigt das Gerätefoto.** Es bestätigt in einer Sekunde, dass man am richtigen Gerät steht — das ist bei zwei baugleichen Stationen nebeneinander der eigentliche Nutzen, nicht Dekoration. Ein Tap auf eine Übung führt direkt zum Satz; es gibt keinen Bestätigungsknopf.

**Das weicht von Spec §5.7 ab.** Dort wurde die Auswahl schon übersprungen, sobald ein Gerät nur eine Übung trägt. Jetzt entscheidet die **Gewohnheit des Mitglieds**, nicht der Katalog des Studios: Wer erst einmal hier war, sieht weiterhin, was es sonst noch gäbe. Das kostet in genau einem Fall einen Tap ohne Wahlmöglichkeit — zweiter Besuch an einem Gerät mit nur einer Übung — und kauft dafür, dass niemand eine Übung nie findet, weil die App zu früh optimiert hat.

**Der Erstkontakt ist ein modaler Dreischritt** (Einweisung · Kalibrierung · erste Werte) ohne Tab-Leiste. Er läuft genau einmal je Gerät und Übung.

**Beim ersten Mal schlägt gymodo kein Gewicht vor.** Es hat keine Historie, und ein Vorschlag ohne Daten wäre eine Trainingsempfehlung — genau das, was die Produktgrenze ausschließt. Das Rad startet am Gerätminimum, das Mitglied stellt selbst ein. Ab dem zweiten Mal entfällt der Schritt: die Werte stehen direkt auf dem Geräte-Screen, und dort werden sie auch geändert.

Die Kalibrierungswerte (Sitz, Lehne, Winkel) bleiben ± Stepper statt Räder — ihre Wertebereiche sind einstellig, ein Rad wäre dort mehr Mechanik als Nutzen.

---

## 9. Das Interaktionsbudget

> Ein normaler Satz lässt sich mit höchstens **zwei** Interaktionen bestätigen. (Blueprint §5.6)

Im Normalfall ist es **eine**: Gewicht steht (Vorschlag übernommen), Wiederholungen stehen (letzter Wert), ein Tap auf „Satz N sichern". Wer abweicht, zahlt genau **einen** zusätzlichen Tap — er öffnet beide Räder, und danach ist Scrollen kostenlos. Damit bleibt auch der Abweichungsfall bei zwei Interaktionen.

Diese Zahl ist eine Abnahmebedingung, kein Ziel. Ein Entwurf, der drei Interaktionen braucht, wird neu entworfen — nicht abgewogen.

Daraus folgt direkt:

- **Kein Keyboard, nirgends im Satzpfad.** Gewicht und Wiederholungen sind Räder mit der Schrittweite des Gerätemodells (Abschnitt 7), nicht Textfelder.
- **Übungsauswahl kostet im Normalfall keinen Tap** (M1-Spec 5.7): eine Übung → übersprungen; Historie vorhanden → vorausgewählt.
- **RIR ist optional und abschaltbar** (Profil). Wer es nicht nutzt, sieht das Feld nicht.

---

## 10. Texte

- **Durchgehend Deutsch**, Du-Form, keine Ausrufezeichen, kein Motivationston. Die App ist ein Werkzeug am Gerät, kein Coach.
- **Zeitangaben** in der Studio-Zeitzone (`studios.timezone`), Datum ausgeschrieben („Mi, 27. August").
- **Kein Freitext zu Schmerzen, Verletzungen oder Gesundheit** — nirgendwo. Die Problemmeldung ist ein Boolean plus feste Liste (`schmerz`, `geraet_passt_nicht`, `zu_schwer`, `sonstiges`). Textfelder gibt es ausschließlich beim Login (E-Mail, Code).
- **Produktgrenze im Klartext**, sichtbar auf Geräte-Screen und Profil:

  > gymodo misst nichts. Angezeigt wird ausschließlich, was du selbst bestätigt hast. Einweisungsvideos und Einstellhinweise sind Inhalte deines Studios, keine Trainings- oder Gesundheitsempfehlung von gymodo.

- **Vorschläge sind eine Rechnung, keine Empfehlung.** Formulierung: „Vorschlag +2,5 kg", nie „Du solltest".
- **Geräte werden stillgelegt, nie gelöscht.** Ein Gerät, das je einen Tag getragen hat, hat keinen Löschpfad — die Sprache muss das tragen.

---

## 11. Navigation

Vier Tabs: **Home · Training · Kurse · Profil**. Der Geräte-Screen ist kein Tab — er wird als Push **innerhalb** von Training geöffnet und behält die Tab-Leiste; „Zurück zum Training" bleibt zusätzlich als expliziter Ausstieg für Zirkeltrainierende.

**Plan** (M3) ist in der Struktur reserviert, erscheint aber **nicht** in der Tab-Leiste, solange er keinen Inhalt hat. Ein leerer Tab ist ein Versprechen ohne Gegenwert; in der Canvas steht er nur auf dem Fundament-Artboard als Platzhalter.

**Kurse ist gestaltet, aber nicht gebaut.** Es gibt dafür weder Tabelle noch Endpoint — siehe `docs/superpowers/plans/2026-08-30-kurse-datenmodell.md`. Die Artboards sind Entwurf, kein Versprechen. Das gilt besonders für den Satz auf „Meine Kurse", der beim Nachrücken von der Warteliste eine Nachricht ankündigt: Benachrichtigungen existieren nicht, und bis sie existieren darf der Satz nicht in die App.

**Scan-Zugang** ist ein Button im Training-Tab, kein Element der Tab-Leiste. NFC und QR stehen im Scan-Sheet gleichwertig nebeneinander — fällt der Trefferquoten-Test aus M0 Task 8 durch, kostet der Schwenk auf QR-first nur Text.

---

## 12. VoiceOver

Beschriftungen je Kernelement — Wert und Einheit gehören in **ein** Label, sonst liest VoiceOver „achtzig, Komma, null, k, g" als vier Elemente:

| Element | Label | Wert / Hinweis |
| --- | --- | --- |
| Wertanzeige | „Gewicht" | „80,0 Kilogramm" |
| Rad | „Gewicht" bzw. „Wiederholungen" | `adjustable`: Auf/Ab ändert um einen Geräteschritt, angesagt wird der neue Wert mit Einheit; am Anschlag zusätzlich „Maximum des Geräts erreicht" |
| Hauptaktion | „Satz 2 sichern, 80,0 Kilogramm" | eine Zeichenkette, kein zusammengesetztes Element |
| Resttimer | „Pause, noch 1 Minute 12 Sekunden" | als Live-Region, Aktualisierung höchstens alle 15 s |
| Blockzeile | „Beinpresse, Beidbeinig, 3 Sätze, 80,0 Kilogramm" | Aktion: „Öffnet das Gerät" |
| Problemmeldung | „Problem melden" | Hinweis: „Verhindert einen Steigerungsvorschlag" |
| Verlaufsdiagramm | „Gewichtsverlauf Beinpresse, Beidbeinig" | Audio Graph oder Wertetabelle als Alternative |

**Dynamic Type bis XXL ist Abnahmebedingung.** Die Wertzeile ist ein vertikaler Stack, der ab XL umbricht statt zu skalieren. Bricht sie bei XXL ins Layout, ist das Layout falsch — nicht die Einstellung des Nutzers.

---

## 13. Diagramme

Ein Diagramm in M1: der Gewichtsverlauf je Übung (Swift Charts, keine externe Abhängigkeit).

- **Eine Serie, eine Farbe** (`accent`) — keine Legende nötig, der Titel benennt sie.
- **Linie 2 pt**, Messpunkte ≥ 8 pt, Gitter in `line`, Achsenbeschriftung in `text-faint`.
- **Direkte Beschriftung nur an Anfang und Ende**, nie an jedem Punkt.
- **Text trägt Textfarben, nie die Serienfarbe.**
- Die Achse beginnt **nicht** bei null — Trainingsgewichte bewegen sich in einem schmalen Band; eine Nullachse macht jeden Fortschritt unsichtbar. Der Achsenbereich wird stattdessen sichtbar beschriftet.
- **Unter dem Diagramm stehen die Rohwerte** der letzten Einheiten. Die Kurve ist eine Zusammenfassung; sie muss nachprüfbar bleiben, weil die Plattform nichts misst.

---

## 14. Offen

- **Wortmarke und App-Icon.** In der Canvas steht „gymodo" gesetzt mit einem Akzentpunkt — ein Platzhalter, kein Logo.
- **Gerätefotos und Einweisungsvideos** sind in allen Artboards Platzhalter. Echte Inhalte kommen aus dem Trainerportal.
- **Trainerportal und Betreiber-Dashboard** haben keine Gestaltung. Sie sind Desktop/Tablet, haben Formulare, Upload-Fortschritt und Tabellen und teilen mit der Member-App nur die Tokens aus Abschnitt 2. Eigene Designrunde.
- **Hell-Modus.** Bewusst nicht gebaut. Wird er nachgerüstet, ist Abschnitt 5 (Zustände) die teure Stelle, nicht die Farbtabelle.
