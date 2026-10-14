#if DEBUG
import Foundation
import Sensorik

/// Gemerkte Befestigungsart je Station und Uebung, sonst der Vorschlag aus
/// dem Geraetetyp (Sensor-Spec B, Nachtrag 14.10. Punkte 1 und 2).
///
/// Je Uebung, nicht nur je Station: an der Kombistation haengt der Sensor
/// beim Butterfly anders als beim Reverse Fly.
struct Befestigungsspeicher {
    let einstellungen: UserDefaults

    init(einstellungen: UserDefaults) { self.einstellungen = einstellungen }

    private func schluessel(_ kontext: SatzZaehlerKontext) -> String {
        "sensor.befestigungsart.\(kontext.station.schluessel).\(kontext.exerciseId)"
    }

    func wahl(fuer kontext: SatzZaehlerKontext) -> BefestigungsWahl? {
        if let roh = einstellungen.string(forKey: schluessel(kontext)), let art = Befestigungsart(rawValue: roh) {
            return BefestigungsWahl(art: art, quelle: .gewaehlt)
        }
        let modell = kontext.station.equipmentModel
        return Befestigungsart.vorschlag(geraetename: modell.name, istKraft: modell.category == .kraft)
            .map { BefestigungsWahl(art: $0, quelle: .vorschlag) }
    }

    func merken(_ art: Befestigungsart, fuer kontext: SatzZaehlerKontext) {
        einstellungen.set(art.rawValue, forKey: schluessel(kontext))
    }
}
#endif
