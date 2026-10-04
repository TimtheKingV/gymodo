import Foundation

/// Ein bestaetigter Satz, wie ihn der Client kennt -- vor oder nach dem
/// erfolgreichen PUT. Die id ist die setId aus M1-Spec SS6.3: clientseitig
/// erzeugt, damit derselbe PUT zweimal gesendet denselben Satz ergibt.
///
/// `load` und `volume` sind Zahlen ohne Einheit -- was sie bedeuten, sagt
/// der Block, in dem der Satz liegt (LokalerBlock.loadUnit/volumeKind).
struct LokalerSatz: Codable, Equatable, Identifiable {
    let id: UUID
    var setIndex: Int
    var load: Double
    /// Die Nebenbelastung (Neigung am Laufband). nil an jedem Geraet, das
    /// keine hat -- also an jedem Kraftgeraet.
    var secondaryLoad: Double?
    var volume: Int
    var rir: Double?
    var problemFlag: Bool
    var problemReason: ProblemReason?
    var performedAt: Date
}

extension LokalerSatz {
    private enum CodingKeys: String, CodingKey {
        case id, setIndex, load, secondaryLoad, volume, rir, problemFlag, problemReason, performedAt
    }

    /// Die Feldnamen von vor Migration 0046.
    private enum AlteKeys: String, CodingKey { case weightKg, reps }

    /// Das App-Update kann mitten in einer offenen Einheit kommen: die
    /// Datei traegt dann Saetze als weightKg/reps. Ohne den Rueckfall
    /// dekodierte sie nicht mehr, SessionFileStore.load() gaebe nil, und
    /// das laufende Training waere weg. Geschrieben wird immer in den
    /// neuen Namen -- nach dem naechsten Satz ist die Datei umgezogen.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let alt = try decoder.container(keyedBy: AlteKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        setIndex = try c.decode(Int.self, forKey: .setIndex)
        load = try c.decodeIfPresent(Double.self, forKey: .load)
            ?? alt.decode(Double.self, forKey: .weightKg)
        secondaryLoad = try c.decodeIfPresent(Double.self, forKey: .secondaryLoad)
        volume = try c.decodeIfPresent(Int.self, forKey: .volume)
            ?? alt.decode(Int.self, forKey: .reps)
        rir = try c.decodeIfPresent(Double.self, forKey: .rir)
        problemFlag = try c.decode(Bool.self, forKey: .problemFlag)
        problemReason = try c.decodeIfPresent(ProblemReason.self, forKey: .problemReason)
        performedAt = try c.decode(Date.self, forKey: .performedAt)
    }
}

/// Was die Zahlen eines Blocks bedeuten: Einheit der Belastung, Einheit
/// der Nebenbelastung (wenn das Geraet eine hat) und Umfangsart.
///
/// Der Block merkt sie sich beim Anlegen, statt sie bei jeder Anzeige im
/// Prefetch nachzuschlagen: TrainingLaeuft und der Abschluss muessen auch
/// dann richtig formatieren, wenn das Geraet inzwischen aus dem Prefetch
/// gefallen ist (stillgelegt, Studiowechsel) oder gar keiner da ist.
struct Blockeinheiten: Equatable, Hashable {
    let loadUnit: LoadUnit
    let secondaryUnit: LoadUnit?
    let volumeKind: VolumeKind

    /// Was vor Migration 0046 jeder Block war. Der Rueckfall fuer eine
    /// Sessiondatei aus dieser Zeit -- dort ist es keine Annahme, sondern
    /// eine Tatsache: es gab nichts anderes.
    static let kilogrammWiederholungen = Blockeinheiten(
        loadUnit: .kg, secondaryUnit: nil, volumeKind: .reps)
}

/// Ein Geraet plus eine Uebung, mit seinen Saetzen (M1-Spec SS5.3).
struct LokalerBlock: Codable, Equatable, Identifiable {
    var id: String { "\(machineId):\(exerciseId)" }
    let machineId: String
    let exerciseId: String
    let loadUnit: LoadUnit
    let secondaryUnit: LoadUnit?
    let volumeKind: VolumeKind
    var saetze: [LokalerSatz]

    var einheiten: Blockeinheiten {
        Blockeinheiten(loadUnit: loadUnit, secondaryUnit: secondaryUnit, volumeKind: volumeKind)
    }

    init(machineId: String, exerciseId: String,
         einheiten: Blockeinheiten = .kilogrammWiederholungen, saetze: [LokalerSatz]) {
        self.machineId = machineId
        self.exerciseId = exerciseId
        loadUnit = einheiten.loadUnit
        secondaryUnit = einheiten.secondaryUnit
        volumeKind = einheiten.volumeKind
        self.saetze = saetze
    }

    private enum CodingKeys: String, CodingKey {
        case machineId, exerciseId, loadUnit, secondaryUnit, volumeKind, saetze
    }

    /// Derselbe Grund wie bei LokalerSatz: ein Block aus der Fassung vor
    /// 0046 traegt keine Einheiten, und er war Kilogramm mal
    /// Wiederholungen.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let alt = Blockeinheiten.kilogrammWiederholungen
        machineId = try c.decode(String.self, forKey: .machineId)
        exerciseId = try c.decode(String.self, forKey: .exerciseId)
        loadUnit = try c.decodeIfPresent(LoadUnit.self, forKey: .loadUnit) ?? alt.loadUnit
        secondaryUnit = try c.decodeIfPresent(LoadUnit.self, forKey: .secondaryUnit)
        volumeKind = try c.decodeIfPresent(VolumeKind.self, forKey: .volumeKind) ?? alt.volumeKind
        saetze = try c.decode([LokalerSatz].self, forKey: .saetze)
    }
}

/// Die laufende Einheit. Entsteht seit Schnitt 4 mit dem Tap auf
/// "Training starten" (WorkoutSessionStore.trainingStarten) -- vorher
/// implizit mit dem ersten Satz (M1-Spec SS5.6, aufgehoben am
/// 15. September). Der Rueckfallweg ueber satzSichern bleibt.
struct LokaleSession: Codable, Equatable {
    let id: UUID
    let startedAt: Date
    var bloecke: [LokalerBlock]

    var letzterSatzAm: Date? {
        bloecke.flatMap(\.saetze).map(\.performedAt).max()
    }

    /// Ohne Satz ist eine Einheit ein Fehlstart, kein Training: sie wird
    /// verworfen, nicht abgeschlossen (Sammelstelle, Entschieden 2).
    var hatSaetze: Bool { bloecke.contains { !$0.saetze.isEmpty } }
}
