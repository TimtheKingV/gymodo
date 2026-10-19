# Phasenzähler für Stapel (19.10.2026)

## Entscheidung

Am Satzende zählt für Befestigungsart `stapel` der Phasenzähler
(`Phasenzaehler.swift`, Kennung `stapel/phasen1`) statt der Kette aus `Satztakt`.
Kurzhantel und Langhantel bleiben unverändert bei der Kette. Die Live-Zahl
während des Satzes ändert sich nicht.

Herkunft: Sensorversuche vom 19.10. (OpenAI Astra), von uns nachgerechnet.
Die Python-Prototypen liegen in `tools/sensorik-sim/` (`phasenversuch.py`,
`vergleich.py`), ohne Änderung übernommen.

## Nachrechnung

Mit denselben Versionen (Python 3.14, numpy 2.3.5, scipy 1.17.0, ahrs 0.4.0,
vqf 2.1.1) ist `phasen-vergleich.csv` byte-identisch zu Astras Ergebnis. Ihre
„Baseline“ stimmt für alle 97 Sätze mit unserem Swift-`Satztakt` (Kette) überein.

| Art (Sätze) | Kette (bisher) | Phasenzähler |
|---|---|---|
| Stapel (37) | 32 exakt, 34 innerhalb ±1 | 33 exakt, **37** innerhalb ±1 |
| Kurzhantel (49) | 38 exakt, 47 innerhalb ±1 | 15 exakt, 32 innerhalb ±1 |
| Langhantel (11) | 4 exakt, 9 innerhalb ±1 | 3 exakt, 8 innerhalb ±1 |

Darum nur Stapel. Bei Hanteln trägt die Schwerkraftprojektion der drehenden
Hantel den Takt; Hochpass und Integration entfernen sie. EKF und VQF
(Orientierungsfilter) verschlechtern jede Variante und bleiben draußen.

Im Bericht (`data/sensoraufnahmen/taktbericht.md`): Stapel blind 18 von 18
innerhalb ±1 (vorher 15 von 18), gepoolt blind 28 von 30 (vorher 25 von 30),
Abstimmung Stapel 100 % innerhalb ±1, aber nur 84 % exakt (die Kette war auf
19/19 exakt abgestimmt).

## Grenzen

- **Keine unabhängige Bestätigung.** Der Phasenzähler wurde gewählt, nachdem
  die Ergebnisse auf diesen Sätzen vorlagen, und die Blindgruppe ist seit der
  Freigabe am 18.10. angesehen. Neue Stapelsätze müssen ihn bestätigen.
- Fünf bisher falsche Stapelsätze werden exakt, vier bisher exakte um eins
  falsch (Butterfly 17→18, Wadenheben 17→18, Abduktoren 30→31, Kabelrudern 15→14).
- Zählt am ganzen Satz (Hauptachse und Schwelle nutzen alle Werte), kein
  Livezähler. Der Zähler braucht keinen Server und rechnet pro Satz in
  Millisekunden (Python, Host); iPhone-Laufzeit nicht gemessen.
- Die Güte (`Ergebnis.guete`) ist der Median der Flächenbilanz zwischen Hin-
  und Rückphase (0,87 bis 0,99 auf allen 37 Sätzen). Sie trennt richtige nicht
  von falschen Zahlen, ein Satz wird mit dem Phasenzähler kaum als
  `signalSchwach` gekennzeichnet.

## Reproduktion

Vom Repository-Stamm:

```bash
python3 -m venv .venv-sensor
.venv-sensor/bin/pip install -r tools/sensorik-sim/requirements-phasen.txt
.venv-sensor/bin/python tools/sensorik-sim/phasenversuch.py --output /tmp/sensor-phasen
```

`PhasenzaehlerTests.stapelSaetzeGleichenDemPythonVersuch` prüft, dass die
Swift-Zahl für alle 37 Stapelsätze der Spalte `raw_phases` entspricht.
