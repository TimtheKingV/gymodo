import Foundation

/// Die Uebungen eines Orts statt seiner Geraete -- die Ansicht "Uebungen"
/// auf "Gerät wählen". Reine Regeln ohne UI, wie `GeraeteAuswahl`.
enum UebungsAuswahl {
    /// Eine Uebung mit den Stationen, an denen man sie machen kann.
    struct Eintrag: Equatable, Identifiable {
        var id: String { uebung.id }
        let uebung: GeraetUebung
        /// Ohne gesperrte, in der Reihenfolge der Eingabe.
        let stationen: [Station]

        /// Die Modellnamen der Stationen, jeder einmal: drei gleiche
        /// Beinpressen sind "Beinpresse", nicht dreimal.
        var geraeteText: String {
            var namen: [String] = []
            for station in stationen where !namen.contains(station.equipmentModel.name) {
                namen.append(station.equipmentModel.name)
            }
            return namen.joined(separator: " · ")
        }
    }

    /// Jede Uebung einmal, in der Reihenfolge ihres ersten Auftretens. Eine
    /// Uebung nur an gesperrten Geraeten entfaellt.
    static func eintraege(stationen: [Station]) -> [Eintrag] {
        var reihenfolge: [String] = []
        var uebungen: [String: GeraetUebung] = [:]
        var jeUebung: [String: [Station]] = [:]
        for station in stationen where !station.gesperrt {
            for uebung in station.exercises {
                if uebungen[uebung.id] == nil {
                    reihenfolge.append(uebung.id)
                    uebungen[uebung.id] = GeraetUebung(
                        id: uebung.id, name: uebung.name, volumeKind: uebung.volumeKind,
                        targetMin: uebung.targetMin, targetMax: uebung.targetMax,
                        videoURL: nil, muscles: uebung.muscles)
                }
                jeUebung[uebung.id, default: []].append(station)
            }
        }
        return reihenfolge.compactMap { id in
            uebungen[id].map { Eintrag(uebung: $0, stationen: jeUebung[id] ?? []) }
        }
    }

    /// Wie am Geraet: dieses Training, dann Haeufigkeit, dann der Rest.
    static func zuletzt(_ eintraege: [Eintrag], heute: [String: Date], einheiten: [String: Int]) -> [Eintrag] {
        let alle = Dictionary(eintraege.map { ($0.id, $0) }, uniquingKeysWith: { erste, _ in erste })
        return GeraetEinstiegRechner.uebungsreihenfolge(eintraege.map(\.id), heute: heute, einheiten: einheiten)
            .compactMap { alle[$0] }
    }

    /// Einheiten je Uebung ueber alle Stationen.
    static func einheiten(stationen: [Station], bootstrap: BootstrapResponse) -> [String: Int] {
        var summe: [String: Int] = [:]
        for station in stationen {
            for (uebung, anzahl) in GeraetEinstiegRechner.einheitenJeUebung(station: station.schluessel, in: bootstrap) {
                summe[uebung, default: 0] += anzahl
            }
        }
        return summe
    }

    enum Ziel: Equatable {
        case direkt(Station)
        /// Mehrere Stationen und keine Historie: das Mitglied waehlt.
        case fragen([Station])
    }

    /// Ein Geraet: dorthin. Mehrere: das, an dem die Uebung schon gemacht
    /// wurde (die meisten Einheiten); ohne Historie wird gefragt.
    /// - einheiten: Station.schluessel -> Einheiten dieser Uebung dort.
    static func ziel(fuer eintrag: Eintrag, einheiten: [String: Int]) -> Ziel {
        if eintrag.stationen.count == 1, let station = eintrag.stationen.first { return .direkt(station) }
        var beste: (station: Station, anzahl: Int)?
        for station in eintrag.stationen {
            let anzahl = einheiten[station.schluessel] ?? 0
            if anzahl > (beste?.anzahl ?? 0) { beste = (station, anzahl) }
        }
        if let beste { return .direkt(beste.station) }
        return .fragen(eintrag.stationen)
    }
}
