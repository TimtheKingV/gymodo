# iOS Member-App — Bewegungssensor: Anbindung und Rohdaten-Aufzeichnung (Teilprojekt A)

**Stand:** 19. September 2026
**Status:** Entschieden, bereit für Umsetzungsplan. Abschnitt 4 (Verifikation am Sensor) wird im ersten Schritt der Umsetzung ausgefüllt.
**Vorbedingung:** Der Satzpfad nach Schnitt 3 steht (`GeraetModel`, `GeraetView`, `WertZeile`, `WorkoutSessionStore`). Das Testnotiz-Modul ist drin; der Debug-Build zeigt den Dokumente-Ordner in der Dateien-App (`Info-Additions-Debug.plist`).
**Verhältnis zu anderen Dokumenten:** untergeordnet gegenüber `2026-08-28-fitness-retrofit-m1-design.md` und `2026-08-30-designsystem.md`. Die Grenze „gymodo misst nichts" (M1-Spec, Zeile 112 und 118; `2026-09-13-ziele-und-fortschritt-design.md`, Zeile 21) bleibt in diesem Teilprojekt unberührt, siehe Abschnitt 2.

> **Nachtrag 10. Oktober 2026:** Die Grenze ist mit Teilprojekt B gefallen; es gilt die neue Fassung in Blueprint §2.3. Siehe `2026-10-10-sensor-wiederholungszaehler-design.md` §3.

---

## 1. Warum

Die Member-App soll Wiederholungen künftig selbst zählen. Ein kleiner Bluetooth-Bewegungssensor (**WitMotion WT9011DCL-BT50**) haftet per Magnet an Hantel, Kabelzug oder Gewichtsstapel und sendet Beschleunigung, Drehrate und Winkel an das iPhone. Darauf bauen später Tempoanalyse und ein Spiel auf.

Das Gesamtvorhaben ist in vier Teilprojekte geschnitten, jedes mit eigener Spec, eigenem Plan und eigener Umsetzung:

| # | Teilprojekt | Ergebnis |
|---|---|---|
| **A** | Sensor-Anbindung und Rohdaten-Aufzeichnung (dieses Dokument) | Echte Sätze liegen als beschriftete Dateien vor; die Paketrate am iPhone ist gemessen |
| B | Wiederholungszähler, Einbindung in den Satzpfad, Herkunfts-Feld am Satz | Reps werden gezählt, das Mitglied bestätigt |
| C | Tempo- und Bewegungsanalyse | Dauer je Wiederholung, Pausen, später Bewegungsumfang |
| D | Spiel, gesteuert durch die Ereignisse aus B und C | Gamification |

A kommt zuerst, weil der Zähler mehrere Iterationen brauchen wird. Offline gegen echte Mitschnitte zu testen ist um ein Vielfaches schneller als im Studio. A liefert diese Mitschnitte nebenbei: Tim trainiert normal, die App schreibt mit, und der am Rad bestätigte Wert ist das Label.

## 2. Scope

**Enthalten:**

- Core-Bluetooth-Anbindung des Sensors: Scan, Verbindung, automatisches Wiederverbinden
- Reiner Parser für das WitMotion-Paketformat
- Befehle an den Sensor: Ausgaberate setzen (20, 50, 100 Hz), Akkustand lesen
- Aufzeichnung der Messwerte je Satz in eine Datei, beschriftet aus dem Satzpfad
- Abspiel-Quelle, die eine Aufnahme über dieselbe Schnittstelle wiedergibt
- Sensor-Zeile im Geräte-Screen und ein Diagnose-Blatt mit 5-Minuten-Ratentest
- Verifikation der Protokollangaben am echten Sensor, bevor sie zu Testdaten werden

**Alles davon nur im Debug-Build** (`#if DEBUG`). Einzige Ausnahme: der Bluetooth-Berechtigungstext in `project.yml` gilt je Target und steht damit auch im Release-Build, ohne dass dort Code dahinter läuft.

**Nicht enthalten:**

- Zählen, Tempo, jede Auswertung der Signale (B, C)
- Herkunfts-Feld am Satz, Migration, Änderungen an API, Domain oder DTOs. **In A verlässt kein Sensorwert das iPhone.** Die Produktgrenze „die Plattform speichert nur, was das Mitglied bestätigt, und behauptet nicht, gemessen zu haben" wird erst in B bewusst neu verhandelt.
- Beschleunigungs-Kalibrierung und „Konfiguration speichern" aus der App. Die Kalibrierung ist über die WitMotion-App erledigt; ein versehentlicher Kalibrier-Befehl am schräg hängenden Sensor würde alle folgenden Daten verfälschen.
- Magnetfeld-Kalibrierung und Nutzung des Yaw-Winkels. Am Gewichtsstapel ist der vom Datenblatt verlangte Abstand von 20 cm zu Stahl und Magneten nicht einzuhalten. Der Winkel wird mitgeschrieben, aber B darf sich auf Yaw nicht stützen.
- Hintergrundmodus `bluetooth-central`. In A bleibt der Bildschirm wach (Abschnitt 5.3); ob Mitglieder das Telefon beim Satz in die Tasche stecken, entscheidet B.
- Bindung Sensor ↔ Gerät über den NFC-Tag, mehrere Sensoren gleichzeitig, Live-Graph, Sichtbarkeit im Release-Build

> **Nachtrag 10. Oktober 2026:** Die Grenze ist mit Teilprojekt B gefallen; es gilt die neue Fassung in Blueprint §2.3. Siehe `2026-10-10-sensor-wiederholungszaehler-design.md` §3.

## 3. Protokoll (am 30. September 2026 am Sensor verifiziert)

Quelle: Herstellerangaben, zusammengetragen in einer Vorrecherche, korrigiert nach der Verifikation in Abschnitt 4.

| | |
|---|---|
| Anzeigename | `WT901BLE` + Nummer (am Testsensor `WT901BLE67`) |
| Service | `0000FFE5-0000-1000-8000-00805F9A34FB` |
| Notify (Daten) | `0000FFE4-0000-1000-8000-00805F9A34FB` |
| Write (Befehle) | `0000FFE9-0000-1000-8000-00805F9A34FB`, mit und ohne Antwort |

Die UUIDs sind 128-Bit-UUIDs des Herstellers, keine 16-Bit-Kurzformen: die Basis endet auf `…9A34FB`, die Bluetooth-Basis auf `…9B34FB`. `CBUUID(string: "FFE5")` passt deshalb nicht. Im weiteren Text stehen `FFE5`, `FFE4` und `FFE9` als Kürzel für diese drei UUIDs.

**Datenpaket:** 20 Byte. Header `0x55 0x61`, danach 18 Byte: Beschleunigung X/Y/Z, Drehrate X/Y/Z, Winkel X/Y/Z, je ein `Int16`, Low-Byte zuerst.

| Größe | Umrechnung | Einheit |
|---|---|---|
| Beschleunigung | Rohwert / 32768 × 16 | g |
| Drehrate | Rohwert / 32768 × 2000 | °/s |
| Winkel | Rohwert / 32768 × 180 | ° |

**Befehle** (5 Byte auf `FFE9`):

| Zweck | Bytes | In A benutzt |
|---|---|---|
| Rate 20 Hz | `FF AA 03 07 00` (aus der Registertabelle des Herstellers abgeleitet, nicht aus der Vorrecherche) | ja |
| Rate 50 Hz | `FF AA 03 08 00` | ja |
| Rate 100 Hz | `FF AA 03 09 00` | ja |
| Akkustand lesen | `FF AA 27 64 00` | ja |
| Konfiguration speichern | `FF AA 00 00 00` | **nein** |
| Beschleunigung kalibrieren | `FF AA 01 01 00` | **nein** |

Ein Ratenbefehl greift sofort und braucht kein Entsperren. Der Sensor behält die zuletzt gesetzte Rate über einen Reconnect und über Aus- und Einschalten hinweg, auch ohne „Konfiguration speichern".

Die Pakete tragen keinen Zeitstempel. Den Empfangszeitpunkt setzt die App selbst (Abschnitt 5.3). Eine Notification trägt mehrere Pakete (zwei bei 50 Hz, vier bei 100 Hz), die sich damit einen Empfangszeitpunkt teilen.

## 4. Verifikation am Sensor (erster Schritt der Umsetzung)

Eine Wegwerf-Probe verbindet sich mit dem Sensor und loggt rohe Bytes als Hex. Sie bleibt nicht im Repo. Ihr Ergebnis wird hier eingetragen, im Stil von `docs/m0-ergebnis.md`. Erst danach entstehen Parser-Tests aus den echten Bytes.

Zu klären:

1. Stimmen Service- und Characteristic-UUIDs? Steht `FFE5` im Advertisement, oder ist der Sensor nur am Namen zu erkennen? Welche Eigenschaften hat `FFE9` (write mit oder ohne Antwort)?
2. Stimmen Header, Paketlänge und Byte-Reihenfolge? Plausibilitätsprobe: Sensor flach und ruhig → eine Achse nahe ±1 g, Drehraten nahe 0.
3. Wie viele Pakete kommen je Notification an — genau eines, mehrere, auch Bruchstücke?
4. Welches Format hat die Antwort auf „Akkustand lesen" (erwartet: Registerantwort mit Header `55 71`), und wie wird daraus Prozent?
5. Greift ein Ratenbefehl sofort, ohne vorheriges Entsperren (`FF AA 69 88 B5`) und ohne „Konfiguration speichern"? Überlebt er ein Aus- und Einschalten (erwartet: nein)?
6. Stimmt der abgeleitete Befehl für 20 Hz (`FF AA 03 07 00`)?
7. Reale Rate am iPhone bei 20, 50 und 100 Hz über je 5 Minuten: Pakete je Sekunde, Abstand Median / p95 / Maximum.

**Ergebnis** (30. September 2026, Punkte 1 bis 6 mit einer Wegwerf-Probe am Mac, Sensor `WT901BLE67` flach und ruhig auf dem Tisch):

1. **UUIDs und Advertisement.** Service, Notify und Write tragen die Nummern `FFE5`, `FFE4`, `FFE9`, aber als 128-Bit-UUIDs mit der Herstellerbasis `0000xxxx-0000-1000-8000-00805F9A34FB`. Das Advertisement nennt den Namen `WT901BLE67` immer und den Service meistens: in einem von mehreren Läufen fehlte er im ersten Fund. Der Sensor wird deshalb am Service **oder** am Namenspräfix `WT` erkannt. `FFE9` hat die Eigenschaften 12, also Schreiben mit und ohne Antwort; `FFE4` hat 16, also nur Notify.
2. **Paket.** Header, Länge und Byte-Reihenfolge stimmen. Ein echtes Paket:
   `55 61 F5 FF 2E 00 00 08 FE FF FF FF FF FF D9 FF B5 00 00 00`
   ergibt Beschleunigung −0,0054 / 0,0225 / 1,0000 g, Drehrate −0,122 / −0,061 / −0,061 °/s, Winkel −0,214 / 0,994 / 0,000 °. Die Schwerkraft liegt wie erwartet auf z, die Drehraten bei null.
3. **Pakete je Notification.** Nie Bruchstücke; jede Notification war ein Vielfaches von 20 Byte. Bei 50 Hz kommen zwei Pakete je Notification (40 Byte), bei 100 Hz vier (80 Byte), bei 20 Hz eines. Der Mac bekam bei 50 und 100 Hz gleichbleibend rund 25 Notifications je Sekunde. Gebündelte Messwerte teilen sich also einen Empfangszeitpunkt, am Mac im Raster von etwa 40 ms. Für den Zähler in B ist das die Grenze der Zeitauflösung; wie das Raster am iPhone aussieht, misst Punkt 7.
4. **Akku.** Die Antwort ist eine Registerantwort und kam mitten in einer 60-Byte-Notification zwischen zwei Messwerten an:
   `55 71 64 00 7E 01 00 00 33 9B 76 FC A3 C4 00 00 00 00 E8 03`
   Register `0x64`, erster Wert `0x017E` = 382, also 3,82 V in Hundertstel Volt. Nach der Stufentabelle sind das 60 %.
5. **Ratenbefehl.** Greift innerhalb einer Sekunde, ohne Entsperren und ohne „Konfiguration speichern": nach `FF AA 03 09 00` stieg die Rate von 48–50 auf 96–100 Pakete je Sekunde. **Abweichend von der Erwartung bleibt die Rate erhalten**, sowohl über Trennen und Neuverbinden als auch über Aus- und Einschalten: nach dem Neustart sendete der Sensor weiter mit 100 Hz. Die App setzt die Rate deshalb bei jedem Verbinden ausdrücklich und verlässt sich nie auf einen Ausgangszustand. Nach der Probe steht der Sensor wieder auf 50 Hz.
6. **20 Hz.** `FF AA 03 07 00` stimmt: 144 Notifications zu je einem Paket in 7,3 s, rund 19,7 je Sekunde.
7. **Rate am iPhone** (4. Oktober 2026, iPhone 13 mini mit iOS 26.6.2, Sensor in Ruhe, App im Vordergrund, je 5 Minuten aus der Diagnose):

   | Soll | Pakete | Ist | Abstand Median | p95 | Maximum | Lücken |
   |---|---|---|---|---|---|---|
   | 20 Hz | 5.512 | 18,4 Hz (19,9 Hz ohne die 22,4 s im Hintergrund) | 49,7 ms | 90,8 ms | 22.396 ms (Hintergrund) | 0 |
   | 50 Hz | 14.894 | 49,6 Hz | 0 ms | 60,3 ms | 91,3 ms | 0 |
   | 100 Hz | 29.789 | 99,3 Hz | 0 ms | 60,1 ms | 120,2 ms | 0 |

   Bei 50 und 100 Hz kommt nichts verloren an. Die Pakete kommen gebündelt: bei 50 Hz zwei je Notification, die Notifications im Abstand von 30 oder 60 ms (am Mac 40 ms). Der Median von 0 ms ist diese Bündelung, nicht ein Messfehler. Die Zeitauflösung am iPhone liegt damit bei rund 30 ms, unabhängig von der Rate; 100 Hz liefert mehr Werte je Bündel, aber keine feineren Zeitstempel.

   **Empfehlung: 50 Hz bleibt die Standardrate.** Eine Wiederholung dauert mehrere Sekunden; 50 Hz zeigt sie in den ersten Aufnahmen deutlich (Drehrate um x bis über 110 °/s). 100 Hz verdoppelt Datenmenge und Funklast ohne bessere Zeitauflösung. 20 Hz wäre möglich, lässt aber für Tempo-Analysen in C wenig Reserve.

Abschnitt 3 ist entsprechend korrigiert (UUIDs, Verhalten der Rate, Bündelung). Parser, Befehle und Akku-Umrechnung bleiben, wie sie sind.

## 5. Komponenten

Neuer Ordner `apps/ios-member/FitnessMember/Workout/Sensor/`. Nach dem Anlegen der Dateien `xcodegen generate`.

| Datei | Aufgabe | Hängt ab von |
|---|---|---|
| `SensorMesswert.swift` | Wert-Typ: `t` (Sekunden, monotone Uhr), `beschleunigung`, `drehrate`, `winkel` je als x/y/z. `Sendable`, `Equatable`. | — |
| `WitMotionPaket.swift` | Reiner Parser, siehe 5.1 | `SensorMesswert` |
| `WitMotionBefehl.swift` | Die vier benutzten Befehle als benannte Konstanten. Kalibrieren und Speichern existieren im Code nicht. | — |
| `SensorQuelle.swift` | Das Protokoll, siehe 5.2 | `SensorMesswert` |
| `BluetoothSensorQuelle.swift` | Einzige Datei mit `import CoreBluetooth`, siehe 5.3 | Parser, Befehle |
| `AbspielSensorQuelle.swift` | Gibt eine Aufnahme über `SensorQuelle` wieder, in Echtzeit oder sofort | Aufnahmeformat |
| `SensorAufnahme.swift` | Schreibt Messwerte und Kopf in einen Ordner, siehe Abschnitt 6. Kennt kein Bluetooth. | `SensorMesswert` |
| `SensorStatistik.swift` | Rate, Abstände (Median, p95, Maximum), Lücken, verworfene Bytes aus Zeitstempeln. Rein. | — |
| `SensorAufnahmeKoordinator.swift` | Verbindet Satzpfad und Aufnahme, siehe Abschnitt 7.3 | Quelle, Aufnahme |

Dazu unter `Screens/Geraet/`: `SensorZeile.swift` und `SensorDiagnoseBlatt.swift` (Abschnitt 7).

### 5.1 Parser

`WitMotionPaket` nimmt `Data` aus einer Notification und gibt eine Liste von Ergebnissen zurück. Er hält einen Puffer über Aufrufe hinweg.

- Ein Ergebnis ist entweder `.messwert(roh)` (Header `55 61`), `.register(adresse, werte)` (Header `55 71`) oder es entfällt.
- Mehrere Pakete in einer Notification werden alle geliefert. Ein über zwei Notifications geteiltes Paket wird zusammengesetzt.
- Steht vor dem nächsten gültigen Header Unbekanntes, richtet sich der Parser am Header neu aus und zählt die übersprungenen Bytes (`verworfeneBytes`). Er wirft nie und erfindet keine Werte.
- Eine Registerantwort wird nie als Messwert gedeutet.

Den Zeitstempel setzt nicht der Parser, sondern die Quelle (5.3). Kommen mehrere Messwerte in einer Notification, bekommen sie denselben Empfangszeitpunkt; die Statistik weist das als Abstand 0 aus, was die Bündelung sichtbar macht statt sie zu verstecken.

### 5.2 `SensorQuelle`

```swift
protocol SensorQuelle: AnyObject, Sendable {
    var zustand: SensorZustand { get }
    var messwerte: AsyncStream<SensorMesswert> { get }
    func verbinden()
    func trennen()
    func rateSetzen(_ rate: SensorRate)
    func akkuLesen()
}
```

`SensorZustand`: `aus`, `bluetoothNichtBereit(Grund)` mit `ausgeschaltet | verweigert | nichtUnterstuetzt`, `sucht`, `mehrereGefunden([SensorFund])`, `verbindet`, `verbunden(name:akkuProzent:)`, `getrennt(wirdNeuVerbunden:)`.

`SensorRate`: `hz20`, `hz50`, `hz100`.

Die genaue Form (ein Strom je Abonnent, `@MainActor`-Bindung des Zustands) legt der Umsetzungsplan entlang der Swift-6-Nebenläufigkeit fest. Fest steht: Verbraucher sehen nur dieses Protokoll.

### 5.3 `BluetoothSensorQuelle`

- Scan ohne Dienstfilter; als Sensor gilt, wer Service `FFE5` im Advertisement nennt oder dessen Name mit `WT` beginnt (siehe 4.1). Ein Fund → verbinden. Mehrere Funde und keine gemerkte ID → `mehrereGefunden`, die Oberfläche lässt wählen. Die gewählte Peripheral-ID liegt in `UserDefaults`; beim nächsten Mal wird über `retrievePeripherals(withIdentifiers:)` direkt verbunden.
- Nach dem Verbinden: Service und Characteristics suchen, `FFE4` abonnieren, Rate setzen (Standard 50 Hz, **ohne** „Konfiguration speichern"; der Sensor behält die Rate trotzdem über einen Neustart, siehe 4.5, deshalb setzt die App sie bei jedem Verbinden neu), Akku lesen, danach alle 60 s erneut.
- **Zeitstempel:** als Erstes im Delegate-Callback, aus einer monotonen Uhr, vor Parser und Weitergabe.
- **Abriss:** Zustand `getrennt(wirdNeuVerbunden: true)`, sofort erneutes `connect`. Core Bluetooth kennt dafür kein Timeout; der Versuch steht, bis der Sensor wieder da ist oder `trennen()` gerufen wird.
- **Berechtigung:** Der `CBCentralManager` entsteht erst beim ersten `verbinden()`, also nach einem Tipp. Der Start der App fragt nicht nach Bluetooth. Ist schon ein Sensor gemerkt, verbindet die App beim Start selbst; die Berechtigung ist dann längst beantwortet. Nachgetragen am 9. Oktober 2026: iOS hatte die App beim Wechsel zu einer anderen App beendet, und nach dem Neustart lief ein Satz ohne Aufnahme, weil niemand „Sensor verbinden" getippt hatte.
- **Bildschirm:** Solange `verbunden` und der Geräte-Screen sichtbar ist, gilt `UIApplication.shared.isIdleTimerDisabled = true`. Beim Verlassen des Screens und beim Trennen zurück auf `false`.
- **Lebensdauer:** eine Instanz auf App-Ebene, weitergereicht per `.environment` wie die Stores. Die Verbindung überlebt den Wechsel zwischen Geräten.

`project.yml` bekommt `INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription: "gymodo verbindet sich mit deinem Bewegungssensor, um Wiederholungen zu erfassen."` Ohne den Schlüssel beendet iOS die App beim ersten `CBCentralManager`.

## 6. Aufnahmeformat `gymodo.sensoraufnahme/1`

Das Format ist der Vertrag zwischen A und B. Verbindliches Beispiel: `apps/ios-member/FitnessMemberTests/Fixtures/sensoraufnahme-beispiel/`.

### 6.1 Ordner

```
Sensoraufnahmen/                    im Dokumente-Ordner, neben Testnotizen/
  2026-09-19-1412-01/               Startzeit yyyy-MM-dd-HHmm, lokale Zeitzone, laufende Nummer je Minute
    aufnahme.json
    messwerte.csv
  ratentest-2026-09-19-1430.json    Ergebnis eines 5-Minuten-Tests, nur Statistik
```

### 6.2 `messwerte.csv`

```
t,ax,ay,az,gx,gy,gz,wx,wy,wz
0.000000,0.0127,-0.9981,0.0312,1.22,-0.61,0.00,-88.41,1.20,0.00
0.019874,0.0131,-0.9977,0.0308,1.10,-0.55,0.06,-88.40,1.21,0.00
# luecke 12.431000-14.902000
14.902000,...
```

- `t`: Sekunden seit Aufnahmestart, sechs Nachkommastellen. `a*` in g (vier Stellen), `g*` Drehrate in °/s (zwei Stellen), `w*` Winkel in ° (zwei Stellen).
- Dezimaltrenner ist immer der Punkt, unabhängig vom Gebietsschema des Geräts.
- Zeilen werden während der Aufnahme angehängt und regelmäßig auf die Platte gebracht. Nach einem Absturz ist alles bis kurz davor da.
- Zeilen mit `#` sind Kommentare. Festgelegt sind zwei:
  - `# luecke <von>-<bis>`: In diesem Zeitraum war die Verbindung getrennt.
  - `# rate <hz> ab <t>`: Ab `t` sendet der Sensor mit `<hz>` (20, 50 oder 100), weil in der Diagnose umgeschaltet wurde. `rateSollHz` in `aufnahme.json` bleibt die Rate vom Aufnahmestart. Nachgetragen am 4. Oktober 2026, nachdem ein Wechsel mitten im Satz am iPhone unsichtbar in einer Aufnahme lag; die Formatkennung bleibt `/1`, weil ältere Leser unbekannte Kommentare überspringen.
- Andere Kommentare überspringt ein Leser.
- CSV statt JSON, weil die Datei sich direkt in Numbers, Python oder einem Plot öffnen lässt. 50 Hz × 60 s sind rund 3000 Zeilen und 200 KB.

### 6.3 `aufnahme.json`

Beim Start angelegt, beim Abschluss vollständig neu geschrieben. Jedes Feld steht immer da; was nicht zutrifft, ist `null`. Zeitpunkte sind ISO 8601 mit Offset, ohne Sekundenbruchteile (wie im Testnotiz-Format).

| Pfad | Typ | Bedeutung |
|---|---|---|
| `format` | String | `gymodo.sensoraufnahme/1`. Leser lehnen Unbekanntes ab. |
| `startedAt`, `endedAt` | Zeitpunkt | `endedAt` ist `null`, solange die Aufnahme läuft |
| `sensor.name` | String | z. B. `WT901BLE67` |
| `sensor.rateSollHz` | Int | 20, 50 oder 100 |
| `sensor.akkuProzent` | Int oder `null` | letzter gelesener Stand |
| `geraet` | Objekt | `model`, `os`, `appBuild` |
| `kontext` | Objekt | `machineId`, `machineName`, `exerciseId`, `exerciseName`, `sessionId`; nach dem Sichern `setId`, `setIndex` |
| `label.weightKg` | Zahl oder `null` | das gesicherte Gewicht |
| `label.reps` | Int oder `null` | **der am Rad bestätigte Wert — die Wahrheit für B** |
| `label.problemFlag` | Bool oder `null` | |
| `befestigung` | String oder `null` | Freitext, z. B. „Gewichtsstapel oben", „Hantelscheibe außen". Je `machineId` gemerkt. |
| `statistik` | Objekt | `pakete`, `rateIstHz`, `abstandMs.median`, `abstandMs.p95`, `abstandMs.max`, `luecken`, `verworfeneBytes` |
| `abschluss` | String | `laeuft`, `gesichert`, `abgebrochen` |

`befestigung` ist die einzige Handeingabe. Sie ist unverzichtbar: Am Stapel ist das Signal rein linear, an der Hantel kommt Rotation dazu, am Hebelarm ein Kreisbogen. Ohne dieses Label lassen sich die Aufnahmen später nicht sinnvoll gruppieren.

### 6.4 Lebenszyklus

- **Start:** `phase == .eingabe` und Sensor `verbunden`. Verbindet sich der Sensor erst mitten in der Eingabe-Phase, startet die Aufnahme in diesem Moment.
- **Abschluss `gesichert`:** „Satz sichern" war erfolgreich. Labels und `setId` werden eingetragen. In der Pause läuft keine Aufnahme; der nächste Satz beginnt eine neue.
- **Abschluss `abgebrochen`:** Der Screen wird ohne Sichern verlassen, oder das Schreiben schlägt fehl. Die Datei bleibt liegen, `label.reps` ist `null`.
- **Verwaist:** Steht beim App-Start ein Ordner mit `abschluss: laeuft` da, wird er als `abgebrochen` nachgetragen; `endedAt` kommt aus der letzten CSV-Zeile.
- Ruhevorlauf vor der ersten Wiederholung und Nachlauf bis zum Tipp bleiben absichtlich drin. Genau damit muss B umgehen: Sensor anbringen, zum Telefon greifen.

## 7. Oberfläche und Einbindung

Alles nur im Debug-Build. Der Release-Build sieht im Satzpfad keine Änderung.

### 7.1 Sensor-Zeile (`SensorZeile`, in `GeraetView` oberhalb der Wertzeilen)

Eine kompakte Zeile aus vorhandenen Bausteinen des Designsystems, keine neue Komponente.

| Zustand | Anzeige | Tipp |
|---|---|---|
| `aus` | „Sensor verbinden" | startet den Scan |
| `sucht`, `verbindet` | „Sensor wird gesucht …" | bricht ab |
| `mehrereGefunden` | öffnet ein Blatt mit Name und Signalstärke je Fund | Auswahl |
| `verbunden`, Aufnahme läuft | ● „WT901BLE67 · 49,8 Hz · 82 %" | öffnet die Diagnose |
| `verbunden`, keine Aufnahme | „WT901BLE67 · 49,8 Hz · 82 %" | öffnet die Diagnose |
| `getrennt` | „Sensor getrennt, wird neu verbunden …" | öffnet die Diagnose |
| `bluetoothNichtBereit` | Klartext; bei `verweigert` mit Weg in die Einstellungen | |
| Schreibfehler | „Aufnahme fehlgeschlagen: …" bis zum nächsten Satz | |

Die Hz-Zahl ist die gemessene Ist-Rate der letzten Sekunde, nicht der Sollwert.

### 7.2 Diagnose-Blatt (`SensorDiagnoseBlatt`)

- Ist-Rate, Abstand Median / p95 / Maximum, verworfene Bytes, Lücken, Akku, Zeit seit dem Verbinden
- Rate umschalten: 20 / 50 / 100 Hz, wirkt sofort
- „5-Minuten-Test": zählt fünf Minuten und schreibt `ratentest-<zeit>.json` mit `format`, `sensor`, `geraet` und `statistik` wie in 6.3
- Textfeld `befestigung`, gemerkt je `machineId`
- „Sensor vergessen": löscht die gemerkte Peripheral-ID und trennt
- Kein Live-Graph. Die CSV im Plot reicht für A.

### 7.3 Einbindung in den Satzpfad

- `GeraetModel.init` bekommt einen Parameter `sensorAufnahme: SensorAufnahmeKoordinator?` mit Standardwert `nil`. Im Release-Build und in allen bestehenden Tests ist er `nil`; das bisherige Verhalten ändert sich nicht.
- `GeraetModel` ruft den Koordinator an genau drei Stellen: beim Eintritt in `.eingabe`, in `satzSichern` nach dem erfolgreichen Schreiben in den Store (dort liegen `setId`, `setIndex`, Gewicht und Wiederholungen vor), und beim Verlassen des Screens. Mehr Sensor-Logik kommt nicht in `GeraetModel`.
- Der Koordinator hört auf den Messwert-Strom, steuert `SensorAufnahme` und hält die laufende `SensorStatistik` für Zeile und Diagnose.
- **Die Aufnahme gefährdet nie den Satz.** Kein Aufruf des Koordinators wirft in den Satzpfad, keiner wird vor dem Sichern abgewartet. Fehler werden geloggt und in der Sensor-Zeile gezeigt; `satzSichern` läuft unberührt durch.
- Der Testnotiz-Kontext (`screen.context`) des Geräte-Screens bekommt `sensor: verbunden | aus`.

## 8. Fehlerfälle

| Fall | Verhalten |
|---|---|
| Paket mit falscher Länge oder falschem Header | Neu ausrichten am nächsten `55 61`, Bytes in `verworfeneBytes`. Kein Absturz, keine erfundenen Werte. |
| Registerantwort `55 71` | Eigene Variante, nie ein Messwert |
| Verbindung reißt im Satz ab | Lücken-Zeile, automatisches Wiederverbinden, Aufnahme läuft weiter. Das Label bleibt gültig; B sieht die Lücke. |
| Sensor geht im Satz aus | wie oben; beim Sichern endet die Aufnahme mit offener Lücke bis zum Ende |
| Schreibfehler, Platte voll | Aufnahme `abgebrochen`, Meldung in der Sensor-Zeile, Satz wird normal gesichert |
| App wird im Satz beendet | CSV bis kurz davor vorhanden; Nachtrag beim nächsten Start (6.4) |
| Bluetooth aus oder Berechtigung verweigert | Klartext in der Sensor-Zeile, Satzpfad voll benutzbar |
| Zwei Sensoren in Reichweite | Auswahl beim ersten Mal, danach greift die gemerkte ID |
| Gemerkter Sensor ist nicht da | Zustand bleibt `sucht`; „Sensor vergessen" in der Diagnose führt zurück zur Auswahl |

## 9. Tests

Swift Testing im Target `FitnessMemberTests`, ohne Sensor und ohne Bluetooth.

- **`WitMotionPaketTests`:** echtes Paket aus Abschnitt 4 mit bekannten Sollwerten; negative `Int16`; Skalierung an den Rändern (`Int16.min`, `Int16.max`); zwei Pakete in einer Notification; ein Paket über zwei Notifications; Unbekanntes vor dem Header samt Zählung; Registerantwort für den Akku; leere Daten.
- **`WitMotionBefehlTests`:** Bytes der vier Befehle. Der Typ bietet weder Kalibrieren noch Speichern an.
- **`SensorStatistikTests`:** Rate, Median, p95 und Maximum gegen konstruierte Zeitstempel; gebündelte Messwerte (Abstand 0); Lücken.
- **`SensorAufnahmeTests`:** CSV-Kopf und Zahlenformat, Punkt als Dezimaltrenner auch unter `de_DE`; Lücken-Zeile; `aufnahme.json` vollständig in den Zuständen `laeuft`, `gesichert`, `abgebrochen`; laufende Nummer bei zwei Aufnahmen in derselben Minute; Nachtrag verwaister Ordner.
- **`AbspielSensorQuelleTests`:** Datei schreiben, wieder abspielen, dieselben Messwerte kommen heraus; Lücken werden übersprungen; das verbindliche Beispiel aus den Fixtures ist lesbar. Das ist der Vertragstest für B.
- **`SensorAufnahmeKoordinatorTests`** mit einer Attrappe der Quelle: Start bei `.eingabe`; Start erst beim späteren Verbinden; Abschluss mit Labels beim Sichern; Abbruch beim Verlassen; keine Aufnahme ohne verbundenen Sensor; ein Fehler im Schreiber lässt das Sichern durchlaufen.
- **`GeraetModelTests`:** bestehende Tests unverändert grün. Neu: Sichern meldet dem Koordinator die richtige `setId`, das richtige Gewicht und die richtigen Wiederholungen; ein fehlgeschlagenes Sichern meldet nichts.

`BluetoothSensorQuelle`, `SensorZeile` und `SensorDiagnoseBlatt` werden nicht unit-getestet, sondern am Gerät geprüft:

1. Verbinden, Zeile zeigt Name, Ist-Rate und Akku
2. Rate auf 20, 50, 100 Hz; die Ist-Rate folgt
3. Drei Sätze sichern; drei Ordner mit `gesichert`, richtigen Labels und plausibler CSV
4. Screen ohne Sichern verlassen; Ordner mit `abgebrochen`
5. Sensor im Satz aus- und wieder einschalten; Lücken-Zeile, Aufnahme läuft weiter, Satz lässt sich sichern
6. Bluetooth am iPhone ausschalten; Klartext, Satz lässt sich sichern
7. App in den Hintergrund und zurück; Verhalten notieren (Eingang für die Hintergrund-Entscheidung in B)
8. Bildschirm bleibt wach, solange verbunden; sperrt wieder normal nach dem Verlassen des Screens
9. 5-Minuten-Test bei 20, 50 und 100 Hz; Dateien liegen in `Sensoraufnahmen/`
10. Ordner im Finder und in der Dateien-App sichtbar
11. Release-Build: keine Sensor-Zeile, keine Bluetooth-Abfrage

**Ergebnis am iPhone** (4. Oktober 2026): 1 bis 10 gehen. Zwei Funde sind behoben: Nach dem Wiedereinschalten von Bluetooth verband der Sensor nicht wieder, bis die App neu startete (Punkt 6; der Fix ist am 5. Oktober am iPhone bestätigt, über die Einstellungen und über das Kontrollzentrum), und ein Ratenwechsel in der Diagnose lag unsichtbar in der Aufnahme (Punkt 2, jetzt `# rate` in 6.2). Dazu kam ein Messwert mit negativer Zeit am Aufnahmestart, ebenfalls behoben. Punkt 11 ist über den Build geprüft: der Release-Build kompiliert ohne jeden Sensor-Typ, weil alles hinter `#if DEBUG` steht; am Gerät angesehen wurde er nicht.

Vor dem Melden das volle Set: `pnpm typecheck`, `pnpm test`, `pnpm test:integration`, `xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.

## 10. Fertig ist A, wenn

1. Abschnitt 4 ausgefüllt ist, mit Empfehlung für die Standardrate, und Abschnitt 3 dazu passt.
2. Mindestens 20 Aufnahmen mit `abschluss: gesichert` vorliegen, über mindestens drei Befestigungsarten (Gewichtsstapel, Hantel, Hebelarm oder Kabelzug). Das ist das Startmaterial für B.
3. Das volle Testset grün ist und die Geräte-Checkliste aus Abschnitt 9 abgehakt ist.

## 11. Offene Punkte für später

1. **Hintergrundmodus** `bluetooth-central` (B): hängt davon ab, wie Mitglieder das Telefon beim Satz ablegen. Beobachtung aus Punkt 7 der Geräte-Checkliste: Geht die App in den Hintergrund, bleibt die Verbindung bestehen, aber es kommen keine Messwerte an (4,0 s und 22,4 s in den Aufnahmen vom 4. Oktober). Weil die Verbindung nicht abreißt, schreibt die Aufnahme dafür **keine** Lücken-Zeile; die Zeit steht nur als großer Paketabstand in der CSV. B muss entweder den Hintergrundmodus einschalten oder solche Abstände selbst als Lücke werten.
2. **Produktgrenze „gymodo misst nichts"** (B): Sensor schlägt vor, Mitglied bestätigt, Herkunfts-Feld am Satz. Braucht eine Änderung der M1-Spec, nicht nur Code.
3. **Eigenes Swift-Package** für Parser, Format und Zähler (B): lohnt sich, sobald die Zähler-Iterationen am Simulator hängen. Die Schichten aus Abschnitt 5 sind dafür schon getrennt.
4. **Einrichtung ohne Herstellerapp** (nach B): Kalibrieren und Speichern aus der App, sobald Studios selbst Sensoren einrichten.
5. **Bindung Sensor ↔ Gerät** über den NFC-Tag: die Nummer im Anzeigenamen wäre der Schlüssel.

> **Nachtrag 10. Oktober 2026:** Erledigt mit Teilprojekt B. Siehe `2026-10-10-sensor-wiederholungszaehler-design.md` §3.
