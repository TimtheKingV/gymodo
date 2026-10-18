import Foundation

/// Die Hauptgruppen der Uebungsliste am Geraet in der Ansicht "Muskel".
/// Die Reihenfolge der Faelle ist die Reihenfolge auf dem Bildschirm.
enum MuskelHauptgruppe: Int, CaseIterable, Sendable {
    /// Nur fuer Geraete: mehrere Hauptmuskelgruppen unter ihren Uebungen.
    /// Ganz oben und eigener Abschnitt, weil ein solches Geraet sonst unter
    /// jeder seiner Gruppen stuende.
    case mehrere
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
        case .mehrere: "Mehrere"
        }
    }

    /// Schluessel eines Muskels in der Reihenfolge, in der gleiche Muskeln
    /// innerhalb der Gruppe zusammenstehen. Der Nacken hat im Muskelmodell
    /// keinen eigenen Schluessel und laeuft unter `upper_back`.
    var muskelSchluessel: [String] {
        switch self {
        case .brust: ["pectorals", "serratus_anterior"]
        case .ruecken: ["lats", "upper_back", "erectors"]
        case .schultern: ["deltoid_anterior", "deltoid_lateral", "deltoid_posterior", "rotator_cuff"]
        case .arme: ["biceps", "triceps", "forearms"]
        case .beine: ["quads", "hamstrings", "glutes", "adductors", "abductors", "calves", "tibialis", "fibularis"]
        case .rumpf: ["abs", "obliques"]
        case .weitere, .mehrere: []
        }
    }
}

extension MuskelHauptgruppe {
    /// Die sechs Gruppen, die Home auswertet und zeigt, in Anzeigereihenfolge.
    static let angezeigt: [MuskelHauptgruppe] = [.brust, .ruecken, .schultern, .arme, .beine, .rumpf]
}

/// Ein Abschnitt der Ansicht "Muskel", fuer jede Art von Eintrag (Uebungen
/// am Geraet, Zeilen des Uebungsfortschritts auf Home -- Testnotiz 17.10., #2).
struct MuskelAbschnitt<Eintrag> {
    let gruppe: MuskelHauptgruppe
    let eintraege: [Eintrag]
}

extension MuskelAbschnitt: Equatable where Eintrag: Equatable {}

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
        abschnitte(uebungen, muskeln: \.muscles, nur: filter)
            .map { Abschnitt(gruppe: $0.gruppe, uebungen: $0.eintraege) }
    }

    /// Wie `gruppieren`, fuer jeden Eintrag, dessen Muskeln `muskeln` nennt
    /// (Testnotiz 17.10., #2: der Uebungsfortschritt auf Home hat selbst keine
    /// Muskeln, sie kommen aus dem Bootstrap).
    static func abschnitte<Eintrag>(
        _ eintraege: [Eintrag], muskeln: (Eintrag) -> [GeraetMuskel], nur filter: MuskelHauptgruppe? = nil
    ) -> [MuskelAbschnitt<Eintrag>] {
        let eingeordnet = eintraege.enumerated().map { index, eintrag in
            (index: index, eintrag: eintrag, platz: platz(muskeln: muskeln(eintrag)))
        }
        let sortiert = eingeordnet.sorted { a, b in
            if a.platz.gruppe != b.platz.gruppe { return a.platz.gruppe.rawValue < b.platz.gruppe.rawValue }
            if a.platz.muskel != b.platz.muskel { return a.platz.muskel < b.platz.muskel }
            return a.index < b.index
        }
        return MuskelHauptgruppe.allCases.compactMap { gruppe in
            if let filter, filter != gruppe { return nil }
            let treffer = sortiert.filter { $0.platz.gruppe == gruppe }.map(\.eintrag)
            return treffer.isEmpty ? nil : MuskelAbschnitt(gruppe: gruppe, eintraege: treffer)
        }
    }

    /// Die Gruppen, in denen mindestens eine Uebung steht -- die Chips des Filters.
    static func vorhandeneGruppen(_ uebungen: [GeraetUebung]) -> [MuskelHauptgruppe] {
        vorhandeneGruppen(uebungen, muskeln: \.muscles)
    }

    static func vorhandeneGruppen<Eintrag>(
        _ eintraege: [Eintrag], muskeln: (Eintrag) -> [GeraetMuskel]
    ) -> [MuskelHauptgruppe] {
        abschnitte(eintraege, muskeln: muskeln).map(\.gruppe)
    }

    /// Die Hauptgruppe einer Uebung mit diesen Muskeln.
    static func hauptgruppe(muskeln: [GeraetMuskel]) -> MuskelHauptgruppe {
        platz(muskeln: muskeln).gruppe
    }

    /// Alle Gruppen, in denen die Hauptmuskeln der Uebung liegen (Geraete:
    /// ein Ruderergometer beansprucht Beine UND Ruecken). Ohne Hauptmuskel
    /// zaehlt der erste darstellbare Muskel, sonst `weitere`.
    static func hauptgruppen(muskeln: [GeraetMuskel]) -> Set<MuskelHauptgruppe> {
        let gruppen = Set(muskeln.filter { $0.role == .primary }.compactMap { einordnen($0.key)?.gruppe })
        return gruppen.isEmpty ? [hauptgruppe(muskeln: muskeln)] : gruppen
    }

    /// Der erste darstellbare Hauptmuskel; gibt es keinen, der erste
    /// darstellbare Muskel ueberhaupt.
    private static func platz(muskeln: [GeraetMuskel]) -> (gruppe: MuskelHauptgruppe, muskel: Int) {
        let hauptmuskeln = muskeln.filter { $0.role == .primary }
        for muskel in hauptmuskeln + muskeln {
            if let treffer = einordnen(muskel.key) { return treffer }
        }
        return (.weitere, 0)
    }

    private static func einordnen(_ key: String) -> (gruppe: MuskelHauptgruppe, muskel: Int)? {
        for gruppe in MuskelHauptgruppe.allCases {
            if let stelle = gruppe.muskelSchluessel.firstIndex(of: key) { return (gruppe, stelle) }
        }
        return nil
    }
}

