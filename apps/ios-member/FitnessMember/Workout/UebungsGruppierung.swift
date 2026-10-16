import Foundation

/// Die Hauptgruppen der Uebungsliste am Geraet in der Ansicht "Muskel".
/// Die Reihenfolge der Faelle ist die Reihenfolge auf dem Bildschirm.
enum MuskelHauptgruppe: Int, CaseIterable, Sendable {
    case brust, ruecken, schultern, arme, beine, rumpf
    /// Uebungen ohne darstellbaren Muskel (alter Server, Offline-Bootstrap,
    /// nur Muskeln, die das Modell nicht kennt).
    case weitere

    var titel: String {
        switch self {
        case .brust: "Brust"
        case .ruecken: "Rücken"
        case .schultern: "Schultern"
        case .arme: "Arme"
        case .beine: "Beine"
        case .rumpf: "Rumpf"
        case .weitere: "Weitere"
        }
    }

    /// Schluessel eines Muskels in der Reihenfolge, in der gleiche Muskeln
    /// innerhalb der Gruppe zusammenstehen. Der Nacken hat im Muskelmodell
    /// keinen eigenen Schluessel und laeuft unter `upper_back`.
    fileprivate var muskeln: [String] {
        switch self {
        case .brust: ["pectorals", "serratus_anterior"]
        case .ruecken: ["lats", "upper_back", "erectors"]
        case .schultern: ["deltoid_anterior", "deltoid_lateral", "deltoid_posterior", "rotator_cuff"]
        case .arme: ["biceps", "triceps", "forearms"]
        case .beine: ["quads", "hamstrings", "glutes", "adductors", "abductors", "calves", "tibialis", "fibularis"]
        case .rumpf: ["abs", "obliques"]
        case .weitere: []
        }
    }
}

/// Gruppiert die Uebungen eines Geraets nach Hauptmuskel -- nur Anzeige.
enum UebungsGruppierung {
    struct Abschnitt: Equatable {
        let gruppe: MuskelHauptgruppe
        let uebungen: [GeraetUebung]
    }

    /// Ab so vielen Uebungen lohnt der Schalter; darunter ist die Liste
    /// ohne Gruppen schneller zu ueberblicken.
    static let schalterAb = 6

    static func bietetSchalterAn(uebungsanzahl: Int) -> Bool {
        uebungsanzahl >= schalterAb
    }

    /// `uebungen` kommt schon in der "Zuletzt"-Reihenfolge; sie bleibt
    /// innerhalb gleicher Muskeln erhalten (stabil). Leere Gruppen entfallen.
    /// - nur: zeigt allein diese Gruppe (der Filter der Uebungsansicht).
    static func gruppieren(_ uebungen: [GeraetUebung], nur filter: MuskelHauptgruppe? = nil) -> [Abschnitt] {
        let eingeordnet = uebungen.enumerated().map { index, uebung in
            (index: index, uebung: uebung, platz: platz(uebung))
        }
        let sortiert = eingeordnet.sorted { a, b in
            if a.platz.gruppe != b.platz.gruppe { return a.platz.gruppe.rawValue < b.platz.gruppe.rawValue }
            if a.platz.muskel != b.platz.muskel { return a.platz.muskel < b.platz.muskel }
            return a.index < b.index
        }
        return MuskelHauptgruppe.allCases.compactMap { gruppe in
            if let filter, filter != gruppe { return nil }
            let treffer = sortiert.filter { $0.platz.gruppe == gruppe }.map(\.uebung)
            return treffer.isEmpty ? nil : Abschnitt(gruppe: gruppe, uebungen: treffer)
        }
    }

    /// Die Gruppen, in denen mindestens eine Uebung steht -- die Chips des Filters.
    static func vorhandeneGruppen(_ uebungen: [GeraetUebung]) -> [MuskelHauptgruppe] {
        gruppieren(uebungen).map(\.gruppe)
    }

    /// Der erste darstellbare Hauptmuskel; gibt es keinen, der erste
    /// darstellbare Muskel ueberhaupt.
    private static func platz(_ uebung: GeraetUebung) -> (gruppe: MuskelHauptgruppe, muskel: Int) {
        let hauptmuskeln = uebung.muscles.filter { $0.role == .primary }
        for muskel in hauptmuskeln + uebung.muscles {
            if let treffer = einordnen(muskel.key) { return treffer }
        }
        return (.weitere, 0)
    }

    private static func einordnen(_ key: String) -> (gruppe: MuskelHauptgruppe, muskel: Int)? {
        for gruppe in MuskelHauptgruppe.allCases {
            if let stelle = gruppe.muskeln.firstIndex(of: key) { return (gruppe, stelle) }
        }
        return nil
    }
}

/// Der Filter der Uebungsansicht auf "Gerät wählen": ein einziger Streifen
/// statt zweier Schalter. `alle` gruppiert nach Muskel, `zuletzt` zeigt die
/// flache Liste nach "Zuletzt", eine Gruppe zeigt nur sie.
enum Uebungsfilter: Hashable, Sendable {
    case alle
    case zuletzt
    case gruppe(MuskelHauptgruppe)

    var titel: String {
        switch self {
        case .alle: "Alle"
        case .zuletzt: "Zuletzt"
        case .gruppe(let gruppe): gruppe.titel
        }
    }

    /// Die Chips: Alle, Zuletzt, dann die Gruppen, in denen Uebungen stehen.
    static func angebot(gruppen: [MuskelHauptgruppe]) -> [Uebungsfilter] {
        [.alle, .zuletzt] + gruppen.map { .gruppe($0) }
    }

    /// Eine Gruppe, die es nicht (mehr) gibt, verhaelt sich wie "Alle".
    func wirksam(gruppen: [MuskelHauptgruppe]) -> Uebungsfilter {
        if case .gruppe(let gruppe) = self, !gruppen.contains(gruppe) { return .alle }
        return self
    }

    var gruppiert: Bool { self != .zuletzt }

    var nurGruppe: MuskelHauptgruppe? {
        if case .gruppe(let gruppe) = self { return gruppe }
        return nil
    }
}
