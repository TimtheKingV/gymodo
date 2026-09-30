import Foundation

/// Exakt die vier Werte aus packages/domain/src/workout.ts problemReasonSchema.
enum ProblemReason: String, Codable, Equatable, CaseIterable {
    case schmerz
    case geraetePasstNicht = "geraet_passt_nicht"
    case zuSchwer = "zu_schwer"
    case sonstiges
}

/// Anfrage-Rumpf fuer PUT /workout-sessions/{sessionId}/sets/{setId}.
/// sessionId/setId werden NICHT mitgeschickt -- sie stehen im Pfad und
/// gewinnen serverseitig ohnehin gegen den Rumpf (workout.ts Kommentar).
struct SetWrite: Codable, Equatable {
    var machineId: String
    var exerciseId: String
    var setIndex: Int
    var load: Double
    var volume: Int
    /// Pflicht genau dann, wenn das Geraetemodell eine Nebenbelastung hat
    /// -- der Server weist beides andere als validation_failed ab
    /// (Cardio-Spec 5.1). nil wird nicht mitgeschickt.
    var secondaryLoad: Double? = nil
    var rir: Double? = nil
    var problemFlag: Bool = false
    var problemReason: ProblemReason? = nil
    var performedAt: String? = nil
    /// Der Beginn der Einheit, ISO 8601 wie performedAt. Der Server legt die
    /// Session mit dem ersten Satz an und uebernimmt ihn dabei -- ohne ihn
    /// staende dort die Ankunft des ersten PUT, nach einem Offline-Training
    /// Stunden nach dem Start (Sammelstelle Punkt 10).
    var sessionStartedAt: String? = nil
}

extension SetWrite {
    private enum CodingKeys: String, CodingKey {
        case machineId, exerciseId, setIndex, load, volume, secondaryLoad, rir,
             problemFlag, problemReason, performedAt, sessionStartedAt
    }

    /// Die Feldnamen von vor Migration 0045.
    private enum AlteKeys: String, CodingKey { case weightKg, reps }

    /// Eigener Dekoder nur wegen der Warteschlange auf Platte
    /// (PendingWriteStore): wer vor dem App-Update offline trainiert hat,
    /// traegt dort Saetze mit weightKg/reps. Ohne den Rueckfall dekodierte
    /// die Datei nicht mehr, und genau die Saetze, die das Mitglied am
    /// laengsten mit sich herumtraegt, waeren weg. Geschrieben wird immer
    /// in den neuen Namen. Faellt zusammen mit dem Server-Alias
    /// (workout.ts, aliasAufloesen) mit dem uebernaechsten Release.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let alt = try decoder.container(keyedBy: AlteKeys.self)
        machineId = try c.decode(String.self, forKey: .machineId)
        exerciseId = try c.decode(String.self, forKey: .exerciseId)
        setIndex = try c.decode(Int.self, forKey: .setIndex)
        load = try c.decodeIfPresent(Double.self, forKey: .load)
            ?? alt.decode(Double.self, forKey: .weightKg)
        volume = try c.decodeIfPresent(Int.self, forKey: .volume)
            ?? alt.decode(Int.self, forKey: .reps)
        secondaryLoad = try c.decodeIfPresent(Double.self, forKey: .secondaryLoad)
        rir = try c.decodeIfPresent(Double.self, forKey: .rir)
        problemFlag = try c.decodeIfPresent(Bool.self, forKey: .problemFlag) ?? false
        problemReason = try c.decodeIfPresent(ProblemReason.self, forKey: .problemReason)
        performedAt = try c.decodeIfPresent(String.self, forKey: .performedAt)
        sessionStartedAt = try c.decodeIfPresent(String.self, forKey: .sessionStartedAt)
    }
}

struct RecordedSet: Decodable, Equatable {
    let id: String
    let studioId: String
    let userId: String
    let sessionId: String
    let machineId: String
    let exerciseId: String
    let setIndex: Int
    let load: Double
    let secondaryLoad: Double?
    let volume: Int
    let rir: Double?
    let problemFlag: Bool
    let problemReason: ProblemReason?
    let performedAt: String
}

/// Was beim naechsten Mal an einem Geraet dieser Einheit ansteht.
/// deltaLoad ist die Zahl, die der Screen zeigt ("+2,5"); ist sie nil,
/// sagt reasonCode warum es keinen Vorschlag gibt. Die Einheiten kommen
/// mit, damit der Abschluss "+0,5 km/h bei 6,0 %" schreiben kann, ohne das
/// Modell nachzuschlagen -- der Prefetch kann aelter sein als die Einheit.
struct Blockvorschlag: Decodable, Equatable {
    let machineId: String
    let exerciseId: String
    let resultLoad: Double?
    let deltaLoad: Double?
    /// Die Nebenbelastung, bei der der Vorschlag gilt; nie gesteigert.
    let secondaryLoad: Double?
    let loadUnit: LoadUnit
    let secondaryUnit: LoadUnit?
    let reasonCode: String
    let algoVersion: String
}

struct CompletedSession: Decodable, Equatable {
    let id: String
    let startedAt: String
    let completedAt: String
    let completedReason: String // "manual" | "auto"
    let vorschlaege: [Blockvorschlag]
}
