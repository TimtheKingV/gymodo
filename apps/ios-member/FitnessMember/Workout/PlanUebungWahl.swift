import Foundation

/// Welche Uebung beim Bearbeiten einer Einheit waehlbar ist (P4, Testnotiz
/// 10.11. #5). Der Server nimmt nur Uebungen an einem Katalogmodell, mit
/// Planmerkmalen und nicht doppelt; die Auswahl zeigt das vorher, statt
/// erst beim Speichern zu scheitern.
enum PlanUebungWahl {
    enum Sperre: Equatable {
        case keinKatalogmodell
        case ohnePlanmerkmale
        case schonInDerEinheit
    }

    /// Reihenfolge: Modell, dann Doppelung, dann Merkmale (P4, Testnotiz
    /// 10.11. #5) -- eine Uebung an einem Katalogmodell mit Merkmalen steht
    /// immer in `merkmale`, die Luecke "doppelt, aber ohne Merkmale" sagt
    /// deshalb zuerst das, was das Mitglied aendern kann.
    static func sperre(station: Station, uebungId: String,
                       merkmale: [String: PlanUebungsMerkmal], belegt: Set<String>) -> Sperre? {
        if modellId(station: station) == nil { return .keinKatalogmodell }
        if belegt.contains(uebungId) { return .schonInDerEinheit }
        if merkmale[uebungId] == nil { return .ohnePlanmerkmale }
        return nil
    }

    /// Das Katalogmodell, das der Server erwartet: am Studio-Geraet sein
    /// `catalogModelId`, am Typ dessen eigene ID (er ist der Katalogeintrag),
    /// wie `BootstrapResponse.aktivesGeraet` (P4, Testnotiz 10.11. #5).
    static func modellId(station: Station) -> String? {
        if let katalog = station.equipmentModel.catalogModelId { return katalog }
        if case .typ = station.art { return station.equipmentModel.id }
        return nil
    }

    static func text(_ sperre: Sperre) -> String {
        switch sperre {
        case .keinKatalogmodell: "Nicht im Plan möglich"
        case .ohnePlanmerkmale: "Noch nicht für Pläne freigegeben"
        case .schonInDerEinheit: "Schon in der Einheit"
        }
    }

    /// "Welche Übung?" an einer Station mit mehreren Uebungen: offen nur die
    /// freien, die gesperrten mit Grund im Hinweis. nil, wenn keine frei ist
    /// (P4, Testnotiz 10.11. #5).
    static func uebungswahl(station: Station, merkmale: [String: PlanUebungsMerkmal],
                            belegt: Set<String>) -> ZirkelUebungswahl? {
        var offen: [ZirkelUebung] = []
        var gesperrt: [String] = []
        for uebung in station.exercises {
            if let sperre = sperre(station: station, uebungId: uebung.id, merkmale: merkmale, belegt: belegt) {
                gesperrt.append("\(uebung.name) (\(text(sperre)))")
            } else {
                offen.append(ZirkelUebung(station: station.schluessel, exerciseId: uebung.id, token: nil))
            }
        }
        guard !offen.isEmpty else { return nil }
        var wahl = ZirkelUebungswahl(station: station, offen: offen, schonDabei: [])
        wahl.eigenerHinweis = gesperrt.isEmpty ? nil : "Nicht wählbar: " + gesperrt.joined(separator: ", ")
        return wahl
    }
}
