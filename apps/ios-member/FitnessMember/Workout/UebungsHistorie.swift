import Foundation

/// Der letzte eigene Satz einer Uebung an einer Station und wie die
/// Uebungslisten ihn zeigen ("vor 3 Tagen · 10,0 kg"). Eine Stelle fuer
/// freies Training (GeraetModel) und Mini-Zirkel (ZirkelUebungswahl) --
/// vorher kannte der Zirkel nur die Saetze von heute, und seine Favoriten
/// blieben leer (Testnotiz 10.11., #14).
enum UebungsHistorie {

    /// Am Geraet aus lastSets, am Typ aus lastTypeSets. Ein Satz am Geraet
    /// zaehlt nicht fuer den Typ und umgekehrt.
    static func letzterSatz(an station: Station, uebungId: String,
                            in bootstrap: BootstrapResponse) -> GeraetModel.LetzterSatz? {
        switch station.art {
        case .geraet(let machineId):
            bootstrap.lastSets.first { $0.machineId == machineId && $0.exerciseId == uebungId }
                .map { GeraetModel.LetzterSatz(load: $0.load, secondaryLoad: $0.secondaryLoad,
                                               volume: $0.volume, cardio: $0.cardio, performedAt: $0.performedAt) }
        case .typ(let equipmentModelId):
            bootstrap.lastTypeSets.first { $0.equipmentModelId == equipmentModelId && $0.exerciseId == uebungId }
                .map { GeraetModel.LetzterSatz(load: $0.load, secondaryLoad: $0.secondaryLoad,
                                               volume: $0.volume, cardio: $0.cardio, performedAt: $0.performedAt) }
        }
    }

    /// Die Cardio-Werte oder die Belastung mit Einheit. nil, wenn der Satz
    /// keins von beiden hat -- dann gilt die Uebung als ohne Historie.
    static func wert(_ letzter: GeraetModel.LetzterSatz, loadUnit: LoadUnit) -> String? {
        if let cardio = letzter.cardio { return Zahlformat.cardio(cardio) }
        return letzter.load.map { Zahlformat.belastungMitEinheit($0, loadUnit) }
    }

    /// Ganze Tage seit dem Satz; nil, wenn performedAt sich nicht parsen laesst.
    static func tage(seit letzter: GeraetModel.LetzterSatz, jetzt: Date) -> Int? {
        guard let datum = ISO8601DateFormatter().date(from: letzter.performedAt) else { return nil }
        return Calendar.current.dateComponents([.day], from: datum, to: jetzt).day
    }

    /// "heute" statt "vor 0 Tagen" -- Letzteres liest sich wie ein
    /// Rechenfehler.
    static func alter(tage: Int) -> String {
        if tage <= 0 { return "heute" }
        return tage == 1 ? "vor 1 Tag" : "vor \(tage) Tagen"
    }

    /// "vor 3 Tagen · 10,0 kg"; ohne parsebares Datum nur der Wert, ohne
    /// Wert nil.
    static func zeile(_ letzter: GeraetModel.LetzterSatz, loadUnit: LoadUnit, jetzt: Date) -> String? {
        guard let wert = wert(letzter, loadUnit: loadUnit) else { return nil }
        return [tage(seit: letzter, jetzt: jetzt).map(alter(tage:)), wert].compactMap { $0 }.joined(separator: " · ")
    }

    /// Ohne Historie: "Noch nie · Ziel 8 – 12 Wdh."
    static func nochNie(_ uebung: GeraetUebung) -> String {
        "Noch nie · Ziel \(Zahlformat.korridorMitEinheit(uebung.targetMin, uebung.targetMax, uebung.volumeKind))"
    }
}
