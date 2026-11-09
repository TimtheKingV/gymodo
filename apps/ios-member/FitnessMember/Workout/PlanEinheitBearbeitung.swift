import Foundation

/// Arbeitsstand beim Bearbeiten einer Planeinheit: Reihenfolge und Entfernen
/// der Positionen, nur über deren Schlüssel. Gespeichert wird in einem Aufruf
/// (`APIClient.ordnePlanEinheit`).
struct PlanEinheitBearbeitung: Equatable {
    private let ausgang: [String]
    private(set) var keys: [String]

    init(einheit: TrainingsplanEinheit) {
        let keys = einheit.positionen.map(\.key)
        self.ausgang = keys
        self.keys = keys
    }

    var geaendert: Bool { keys != ausgang }
    var darfEntfernen: Bool { keys.count > 1 }

    /// Semantik wie `Array.move(fromOffsets:toOffset:)`.
    mutating func verschieben(von: IndexSet, nach: Int) {
        let von = IndexSet(von.filter { keys.indices.contains($0) })
        guard !von.isEmpty else { return }
        let verschoben = von.map { keys[$0] }
        let davor = von.filter { $0 < nach }.count
        var rest = keys
        rest.remove(atOffsets: von)
        let ziel = min(max(nach - davor, 0), rest.count)
        rest.insert(contentsOf: verschoben, at: ziel)
        keys = rest
    }

    /// `false` und unverändert, wenn danach nichts bliebe.
    @discardableResult
    mutating func entfernen(_ offsets: IndexSet) -> Bool {
        let gueltig = IndexSet(offsets.filter { keys.indices.contains($0) })
        guard !gueltig.isEmpty, gueltig.count < keys.count else { return false }
        keys.remove(atOffsets: gueltig)
        return true
    }

    /// In `keys`-Reihenfolge; unbekannte Schlüssel fallen weg.
    func positionen(in einheit: TrainingsplanEinheit) -> [TrainingsplanPosition] {
        let nachKey = Dictionary(einheit.positionen.map { ($0.key, $0) }, uniquingKeysWith: { erste, _ in erste })
        return keys.compactMap { nachKey[$0] }
    }

    /// Nach einem Tausch: Reihenfolge behalten, verschwundene Schlüssel raus,
    /// neue hinten an. Der Ausgangsstand bleibt, sodass `geaendert` ehrlich bleibt.
    mutating func uebernehmen(neueEinheit: TrainingsplanEinheit) {
        let neu = neueEinheit.positionen.map(\.key)
        let behalten = keys.filter(neu.contains)
        keys = behalten + neu.filter { !behalten.contains($0) }
    }
}
