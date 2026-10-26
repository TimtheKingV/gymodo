# Satzautomatik (Debug)

Die Automatik ist standardmäßig eingeschaltet; die Sensorkarte speichert den
Schalter dauerhaft in `sensor.automatikAus`. Sie gilt für Wiederholungsübungen
mit verbundenem Sensor, Befestigung und bekannten Startwerten. Gewicht und
gegebenenfalls Nebenbelastung müssen aus der Vorbereitung oder der Historie
bekannt sein. Die Abschlussentscheidung nach dem Satzziel bleibt bestehen.

`Sensorik.SatzAutomatik` arbeitet mit Messzeit und Wiederholungsintervallen,
nicht mit der Zahl am Rad. Zwei zusammenhängende Wiederholungen bestätigen
den Start. Acht Sekunden ausgewertete Ruhe beenden den Satz. Messlücken setzen
die beobachtete Ruhe zurück. Zusätzliche Bewegungsevidenz aus Beschleunigung
und Drehrate schützt noch nicht abgeschlossene langsame Wiederholungen, kann
aber keinen Satz starten. Nachberechnete Wiederholungszeiten haben eine
Toleranz von 250 ms gegen nachträgliches Verschieben derselben Wiederholung.

Der appweite `ZaehlerKoordinator` hält den aktiven `GeraetModel`-Kontext während
der Automatik. Zähler und Mitschnitt werden beim automatischen Bildschirmwechsel
nicht erneut begonnen. In Pausen puffert der Mitschnitt rund 30 Sekunden;
er schreibt erst bei Bestätigung ab der ersten zugehörigen Wiederholung.
`TrainingRootView` bereitet den nächsten zulässigen Zirkel-Slot synchron beim
Speichern vor und verwendet dasselbe Modell bei dessen späterer Anzeige.
Fehlen Werte, bleibt der Drawer erforderlich.

Automatisches und manuelles Sichern teilen sich `GeraetModel.satzLokalSichern`;
Satzkennung, Eingabephase und Abschlussmarkierung verhindern doppelte Writes.
Session, Warteschlange und Mitschnitte bleiben nach dem ersten Entsperren
auch bei erneut gesperrtem Gerät schreibbar. Bestehende Session- und Warteschlangendateien werden beim Öffnen
umgestellt. Bluetooth-Hintergrundmodus bleibt auf Debug beschränkt.

Die bestehende Grenze der vollständigen Takt-Auswertung (150 Sekunden) gilt
weiter. Nach deren Überschreitung bleibt die manuelle Speicherung erforderlich.
Ein Prozessabbruch stellt keinen ungespeicherten Satz wieder her.

## Geräteabnahme

Die folgenden Schritte brauchen ein echtes iPhone und tatsächliche Bewegung;
Simulator- und Replay-Tests ersetzen diese Abnahme nicht:

- Gerät nach Appstart einmal entsperren, Übung und Befestigung wählen.
- Handy sperren, mindestens drei Sätze mit kurzen Atempausen trainieren.
  Nach acht Sekunden Ruhe muss je genau ein Satz lokal stehen.
- Dasselbe offline und im Zirkel mit mehreren Übungen wiederholen;
  Gewichte aus Vorbereitung und Vorrunde müssen übereinstimmen.
- Bluetooth während eines Satzes unterbrechen: kein Abschluss während der
  Lücke; nach Wiederverbindung erst acht neu beobachtete Sekunden Ruhe.
- Während der automatischen Speicherung manuell sichern, anschließend
  entsperren: genau ein lokaler Satz und ein passender Warteschlangeneintrag.
- Automatik deaktivieren, Übung wechseln und Training beenden: keine späteren
  automatischen Sätze. Nach Satzziel bleibt die Abschlussentscheidung stehen.

## Verifikation

- iOS-Suite: 1.516 Testfälle in 144 Suites, erfolgreich; der Test der
  Dateischutzattribute wird im Simulator ausdrücklich übersprungen.
- Sensorik: acht gezielte Zustands- und Signaltests erfolgreich.
- Release-Build für iOS ohne Signierung erfolgreich; die Sensorautomatik bleibt
  weiterhin auf Debug beschränkt.
- Zwei automatische Sätze ohne zwischenzeitlichen View-Aufruf: je fünf
  Wiederholungen, vorbereitetes Gewicht, genau zwei lokale Writes, danach
  Abschlussentscheidung. Mitschnittbeginn und gleichzeitiges manuelles
  Sichern sind ebenfalls durch Integrationstests geprüft.
- Auf einem echten iPhone 13 mini: 133 Modell- und Persistenztests erfolgreich,
  einschließlich Migration bestehender Dateischutzattribute und atomarer
  Schreibvorgänge. Der Test mit zwei automatisch gespeicherten Sätzen besteht
  auch auf dem Gerät.
- Die Geräteabnahme mit tatsächlichen Sensorbewegungen bei gesperrtem
  Bildschirm und Bluetooth-Unterbrechungen bleibt als manueller Praxistest offen.
