#if DEBUG
import Testing
import Sensorik
@testable import FitnessMember

struct SensorZeileTextTests {
    @Test func zaehlerTexte() {
        #expect(SensorZeile.zaehlerText(meldung: nil) == nil)
        #expect(SensorZeile.zaehlerText(meldung: .bereit) == "zählt")
        #expect(SensorZeile.zaehlerText(meldung: .stand(7)) == "zählt · 7")
        #expect(SensorZeile.zaehlerText(meldung: .pruefen(7, .luecke)) == "Verbindung unterbrochen – Zahl bitte prüfen · 7")
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

/// Testnotiz 15.10., #5: die Karte zeigt Name, Akku, Zustand -- keine Hz.
struct SensorKarteAnzeigeTests {
    @Test func verbundenZeigtNameUndAkku() {
        let a = SensorKarte.anzeige(zustand: .verbunden(name: "WT901BLE67", akkuProzent: 82))
        // Testnotiz 17.10., #3: "Gymtavo Tracker" statt des Bausteinnamens.
        #expect(a == .init(titel: "Gymtavo Tracker", untertitel: "Verbunden", akku: 82, ton: .verbunden))
        #expect(!a.untertitel.contains("Hz"))
    }

    @Test func nurDerBausteinnameWirdUmbenannt() {
        #expect(SensorName.anzeige("WT901BLE67") == "Gymtavo Tracker")
        #expect(SensorName.anzeige("wt901ble5") == "Gymtavo Tracker")
        #expect(SensorName.anzeige("Anderer Sensor") == "Anderer Sensor")
    }

    @Test func nichtVerbundenUndFehler() {
        #expect(SensorKarte.anzeige(zustand: .aus).untertitel == "Nicht verbunden · Tippen zum Verbinden")
        // Testnotiz 17.10., #1: dauerhaft "Nicht verbunden", nur nach dem Tipp "Wird gesucht".
        #expect(SensorKarte.anzeige(zustand: .sucht).untertitel == "Nicht verbunden")
        #expect(SensorKarte.anzeige(zustand: .sucht, suchtKurz: true).untertitel == "Wird gesucht …")
        #expect(SensorKarte.anzeige(zustand: .bluetoothNichtBereit(.ausgeschaltet)).ton == .warnung)
        #expect(SensorKarte.anzeige(zustand: .aus, fehler: "Boom") == .init(titel: "Sensor", untertitel: "Boom", akku: nil, ton: .warnung))
    }
}
#endif
