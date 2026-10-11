# Sensoraufnahmen

Mitschnitte aus dem Debug-Build der Member-App, Format `gymodo.sensoraufnahme/1` (Spec: `docs/superpowers/specs/2026-09-19-sensor-anbindung-aufzeichnung-design.md`, Abschnitt 6). Startmaterial für den Wiederholungszähler (Teilprojekt B).

Die Ordner sind unverändert vom iPhone kopiert. Was die App beim Sichern als Label geschrieben hat, steht in `aufnahme.json`. Wo das nicht stimmt und was wirklich gemacht wurde, steht in `korrekturen.json`; das zählt für B als Wahrheit.

## Stand 8. Oktober 2026

Noch **keine** Aufnahme ist Trainingsmaterial (`fuerZaehler: false` überall):

- **4. Oktober vormittags:** Schnelltest, Gerät mit der Hand bewegt, Wiederholungen nur ungefähr.
- **4. und 5. Oktober:** Geräte-Checkliste und Ratentests (Spec §4.7, §9).
- **8. Oktober:** Probe aller geplanten Übungen mit einer Wasserflasche als Hantel. Sie ist gut, um zu sehen, welche Befestigung ein lesbares Signal gibt, bildet aber weder Stange noch Gewichtsstapel nach.

Erste Beobachtungen aus dem 8. Oktober: Curls sind in der Drehrate um eine Achse sehr deutlich, eine Welle je Wiederholung. Squats und das Absetzen auf dem Stapel zeigen sich in der Beschleunigung. Frei geführte Stapel-Bewegung und der Sensor um den Hals sind kaum zu lesen.

Ab Teilprojekt B gezählt werden nur echte Sätze mit eingetragener Befestigung und korrekt bestätigten Wiederholungen.

## Felder in `korrekturen.json`

- `befestigungsart`: einer von `stapel`, `langhantel`, `kurzhantel`, `hebelarm`, `kabelgriff`, `koerper` oder `null` (Sensor-Spec B 5.4). Der Zähler wählt danach sein Profil; ohne Art läuft die Aufnahme nicht in den Gütebericht.
- `befestigung`: Freitext-Detail wie bisher („oben auf dem Stapel“).
- `repsWahr`: was wirklich gemacht wurde — die Wahrheit für den Zähler.
- `fuerZaehler`: `true` nur für echte Sätze mit eingetragener Art und korrekt bestätigten Wiederholungen. Nur sie zählen für das Gütetor, und nur, wenn sie nach dem `eingefrorenAm` des Profils aufgenommen wurden.

Neue Aufnahmen: Ordner unverändert vom iPhone kopieren, Eintrag hier anlegen, `swift test --package-path apps/ios-member/Packages/Sensorik` laufen lassen und den neuen `guetebericht.md` mit committen.
