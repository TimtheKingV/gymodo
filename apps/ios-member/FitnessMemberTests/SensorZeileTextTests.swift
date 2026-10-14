#if DEBUG
import Testing
import Sensorik
@testable import FitnessMember

struct SensorZeileTextTests {
    @Test func zaehlerTexte() {
        #expect(SensorZeile.zaehlerText(meldung: nil) == nil)
        #expect(SensorZeile.zaehlerText(meldung: .bereit) == "zählt")
        #expect(SensorZeile.zaehlerText(meldung: .stand(7)) == "zählt · 7")
        #expect(SensorZeile.zaehlerText(meldung: .pruefen(7, .luecke)) == "Zahl prüfen · 7 (Lücke)")
        #expect(SensorZeile.zaehlerText(meldung: .pruefen(3, .signalSchwach)) == "Zahl prüfen · 3 (Signal schwach)")
        #expect(SensorZeile.zaehlerText(meldung: .pruefen(3, .taktUnregelmaessig)) == "Zahl prüfen · 3 (Takt unregelmäßig)")
        #expect(SensorZeile.zaehlerText(meldung: .zaehltNicht(.keineWiederholungen)) == "zählt hier nicht: keine Wiederholungen")
        #expect(SensorZeile.zaehlerText(meldung: .zaehltNicht(.keinSensor)) == "zählt nicht: kein Sensor")
        #expect(SensorZeile.zaehlerText(meldung: .zaehltNicht(.keineBefestigung)) == "Befestigung wählen")
    }

    @Test func befestigungTexte() {
        #expect(SensorZeile.befestigungText(BefestigungsWahl(art: .stapel, quelle: .vorschlag)) == "Stapel (Vorschlag)")
        #expect(SensorZeile.befestigungText(BefestigungsWahl(art: .koerper, quelle: .gewaehlt)) == "Körper")
        #expect(SensorZeile.befestigungText(nil) == "Befestigung wählen")
    }
}
#endif
