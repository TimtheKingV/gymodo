import Foundation

/// Ein bestaetigter Satz, wie ihn der Client kennt -- vor oder nach dem
/// erfolgreichen PUT. Die id ist die setId aus M1-Spec SS6.3: clientseitig
/// erzeugt, damit derselbe PUT zweimal gesendet denselben Satz ergibt.
struct LokalerSatz: Codable, Equatable, Identifiable {
    let id: UUID
    var setIndex: Int
    var weightKg: Double
    var reps: Int
    var rir: Double?
    var problemFlag: Bool
    var problemReason: ProblemReason?
    var performedAt: Date
}

/// Ein Geraet plus eine Uebung, mit seinen Saetzen (M1-Spec SS5.3).
struct LokalerBlock: Codable, Equatable, Identifiable {
    var id: String { "\(machineId):\(exerciseId)" }
    let machineId: String
    let exerciseId: String
    var saetze: [LokalerSatz]
}

/// Die laufende Einheit. Entsteht implizit beim ersten Satz -- es gibt
/// keinen Startknopf (M1-Spec SS5.6).
struct LokaleSession: Codable, Equatable {
    let id: UUID
    let startedAt: Date
    var bloecke: [LokalerBlock]

    var letzterSatzAm: Date? {
        bloecke.flatMap(\.saetze).map(\.performedAt).max()
    }
}
