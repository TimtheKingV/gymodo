# Gerät-Kernflow — offene manuelle Abnahme

**Stand:** 8. September 2026
**Betrifft:** Sub-Projekt 2 der iOS-Member-App, Branch `phase7-ios-geraet`
**Zweck:** Alles, was Menschen prüfen müssen, weil Maschinen es nicht konnten.

Der Code ist gebaut, getestet und durchgesehen: 127 automatische Tests in
23 Suites, Kaltbau ohne eine einzige neue Warnung, jede der sechzehn
Aufgaben einzeln abgenommen, dazu eine Schlussdurchsicht über den gesamten
Branch. **Was hier steht, ist trotzdem nicht geprüft** — es braucht ein
Gerät, ein echtes Studio und Augen.

Nichts davon ist ein bekannter Fehler. Es ist die Liste dessen, wofür es
keinen Beweis gibt.

---

## 1. Der Durchgang am Gerät

Gegen ein echtes Studio mit mindestens einem Gerät, einer Übung und einem Tag.

1. **Kaltstart.** `https://gymodo-web.vercel.app/t/<token>` als Universal Link
   öffnen. Die App landet im Training-Tab (Tab-Leiste sichtbar, „Training"
   ausgewählt) und pusht den Geräte-Screen — kein eigener Tab.
   *Zuerst prüfen:* SwiftUI feuert `.onAppear` für einen nicht ausgewählten
   Tab beim ersten Aufbau nicht; dieser Pfad wurde deshalb eigens repariert.
2. **Warmer Fall.** Denselben Link öffnen, während die App auf einem
   **anderen** Tab läuft. Wechselt sie nach Training und öffnet das Gerät?
3. **Zweiter Tag bei offenem Geräte-Screen.** Einen zweiten Tag antippen,
   während der erste Geräte-Screen offen ist. Der zweite **ersetzt** den
   ersten, er stapelt sich nicht darauf. „Zurück zum Training" führt danach
   direkt zur Wurzel.
4. **Erstkontakt.** Der Dreischritt läuft bildschirmfüllend, **ohne
   Tab-Leiste**. Nach „Ersten Satz sichern" steht der Resttimer.
5. **Abbruch des Erstkontakts.** Das Schließen-Kreuz in Schritt 1 führt zur
   Training-Wurzel. Dasselbe Gerät erneut öffnen: der Dreischritt kommt
   wieder (er gilt erst nach Abschluss als erledigt).
6. **Zweiter Satz.** „Satz 2 sichern" mit vorbelegtem Gewicht. Ein Tap auf
   das Gewicht öffnet **beide** Räder; Sichern funktioniert ohne
   Zwischentap.
7. **Zirkel.** „Zurück zum Training", zweites Gerät scannen, dann über die
   Blockliste zum ersten zurück. Der Satzzähler läuft im **Block** weiter,
   nicht in der Session — und der Dreischritt kommt **nicht** wieder.
8. **QR statt NFC.** Einen QR-Code scannen. Er muss dasselbe tun wie ein
   NFC-Tap. *Dieser Pfad war bis zur Schlussdurchsicht tot* und ist neu
   repariert; er hat noch nie an echter Hardware funktioniert.
9. **Flugmodus.** Werte und Historie stehen, das Video fehlt, die
   Offline-Leiste steht, ein Satz meldet „gespeichert, wird gesendet".
10. **App-Kill im Flugmodus**, Neustart: Session und Warteschlange überleben,
    die Satznummer stimmt.
11. **Flugmodus aus.** Die Warteschlange läuft leer, zwei Sekunden
    „Gesendet", dann verschwindet die Karte.
12. **„Training beenden"** im Training-Tab. In der Datenbank prüfen:
    `workout_sessions.completed_reason = 'manual'`.

---

## 2. Das Wertrad — alles Sichtbare und Fühlbare ist ungeprüft

`RastRad` ist das Herzstück und die am häufigsten ausgelöste Geste der App.
Kein Subagent konnte es sehen oder fühlen. Gegen
`docs/superpowers/design/member/GeraetWertRad.dc.html` abnehmen:

- **Die Staffelung.** Gewählter Wert 64 pt, erste Nachbarn 30 pt, zweite
  26 pt. Umgesetzt über Skalierung (0,469 und 0,406 auf der 64-pt-Basis) und
  Deckkraft (0,38 und 0,15 auf `bg`) — die Farben sind aus den Tokens
  gerechnet, nicht gemessen. Wirken die Nachbarn zu hell oder zu blass, sind
  es zwei Zahlen, kein Umbau.
- **Die Silhouette.** Ruhe und Offen müssen dieselbe Silhouette haben. Die
  Linie liegt fest, die Zahlen ziehen daran vorbei.
- **Verschachteltes Scrollen — der wichtigste Punkt dieser Liste.** Die
  äußere Seiten-Scrollfläche und die inneren Rad-Scrollflächen teilen sich
  die vertikale Achse. Wenn das Rad am Daumen hakt oder die Seite mitzieht,
  ist die Kernaussage „danach ist Scrollen kostenlos" verletzt.
  *Reparatur liegt bereit:* äußeres Scrollen abschalten, solange die Räder
  offen sind.
- **Rubber-Banding** an Gerätminimum und -maximum.
- **Anschlag-Haptik.** Am Maximum klopft es **und** die Kontextzeile wechselt
  sichtbar auf „Maximum des Geräts erreicht".
- **Ein Randfall:** Kommt ein bereits ungültiger Wert herein, rastet das Rad
  beim Erscheinen ein — und klopft dabei möglicherweise ohne Nutzergeste.

---

## 3. VoiceOver

Ein Durchgang über alle sechs Views. Besonders:

- **Das Rad** ist ein Bereichsregler. Auf und Ab gehen **genau einen
  Geräteschritt**, angesagt wird der neue Wert mit Einheit. Am Anschlag
  zusätzlich „Maximum des Geräts erreicht".
- **Der Resttimer** meldet höchstens alle 15 Sekunden, nicht sekündlich.
  Die Ansage lautet „Pause, noch 1 Minute 12 Sekunden" — **einmal**, nicht
  doppelt.
- **Die Hauptaktion** liest „Satz 2 sichern, 80,0 Kilogramm" als **eine**
  Zeichenkette.
- **„Verstanden"** auf der Karte abgelehnter Sätze muss erreichbar und
  auslösbar sein.
- **Der Stepper** kündigt seinen Grenzhinweis derzeit doppelt an — bekannt,
  zurückgestellt.
- **Die Ziffernanzeige des Timers** wird als eigener Stopp vorgelesen. Ob das
  neben der Ansage stört, ist eine Urteilsfrage.

---

## 4. Dynamic Type und Reduce Motion

- **Dynamic Type bis XXL** über alle sechs Views. Die Wertzeile **bricht um**
  statt zu skalieren — bricht sie ins Layout, ist das Layout falsch, nicht
  die Einstellung des Nutzers.
- **Reduce Motion** über alle vier Bewegungen: Räder öffnen, Räder schließen,
  Satz → Pause, Press-Feedback. Jede wird zum Zustandswechsel; keine
  Information verschwindet. Der Resttimer-Balken springt sekundenweise statt
  zu laufen.

---

## 5. Gegen die Artboards

Jeder Screen gegen sein `.dc.html` unter `docs/superpowers/design/member/` —
**plus** die Abweichungstabelle in Abschnitt 9 der Spec. Die Artboards
tragen bekannte Regelbrüche; die Tabelle gewinnt.

Beim Bauen kamen fünf Abweichungen dazu, die noch **nicht** in der Tabelle
stehen und dort nachgetragen gehören:

| Screen | Artboard | Gebaut | Warum |
| --- | --- | --- | --- |
| `GeraetErkannt` | Eckradius 16 px | 12 (`Radius.card`) | §4 reserviert 16 für die Hauptaktion |
| `GeraetErkannt` | Fotohöhe 186 px | 180 | belanglos, keine Skala betroffen |
| `GeraetKalibrierung` | Trainer-Schalter in `accent` | `text` | ein eingeschalteter Toggle ist eine Fläche — zweite Akzentfläche |
| `GeraetUebungWechseln` | Akzent dreifach (Rahmen, Punkt, Text) | ein 3-pt-Streifen | genau eine Anwendung, wie in `GeraetErkannt` |
| `GeraetEinweisung` etc. | Zurück-Chevron | Schließen + Zurück je Schritt | ohne Ausweg wäre der Dreischritt eine Sackgasse |
| alle | — | Einstieg über die Blockliste hat keinen Vorschlag, kein Foto, kein Video | `tagContext` hängt am Token, den es dort nicht gibt |

---

## 6. Bekannt und bewusst zurückgestellt

Kein Handlungsbedarf vor dem Merge, aber nicht vergessen:

- **Vier vorbestehende Warnungen** aus Sub-Projekt 1
  (`QRScannerController.swift` dreimal, `SupabaseAuthBackend.swift` einmal,
  veralteter Initialisierer). Nicht in diesem Branch behoben — fremder Diff,
  und die Deprecation braucht eine eigene Prüfung. **Als Folgebranch
  anlegen:** dieser Branch hat den warnungsfreien Kaltbau als Maßstab
  etabliert, und vier stehende Warnungen sind genau das Rauschen, in dem der
  nächste echte Fund untergeht.
- **Ein Anschlag-Prädikat** steht in `RastRad.swift:167` noch inline, während
  die Hilfsfunktion an den zwei anderen Stellen greift. Driftgefahr, kein
  Verhaltensfehler.
- **Kein Medien-Cache:** offline gibt es kein Gerätefoto. Bewusst, in
  Abschnitt 8.4 der Spec begründet.
- **Reihenfolge beim Ausrollen:** Die neuen Swift-Felder `visitCount` und
  `settingDefinitions` sind nicht optional. Der App-Build darf die Geräte
  erst erreichen, **nachdem** die Serveränderung live ist. Auf der Leitung
  additiv, im Client streng.
