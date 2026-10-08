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

/// Eine Station plus eine Uebung, mit ihren Saetzen (M1-Spec SS5.3).
struct LokalerBlock: Codable, Equatable, Identifiable {
    var id: String { "\(stationSchluessel):\(exerciseId)" }
    /// "geraet:<id>" | "typ:<id>" -- gespeichert statt abgeleitet, damit der
    /// Schluessel einer laufenden Einheit stabil bleibt, auch wenn sich
    /// Bootstrap und Katalog aendern.
    let stationSchluessel: String
    /// nil am Typ.
    let machineId: String?
    let equipmentModelId: String?
    let exerciseId: String
    let loadUnit: LoadUnit
    let secondaryUnit: LoadUnit?
    let volumeKind: VolumeKind
    var saetze: [LokalerSatz]

    var einheiten: Blockeinheiten {
        Blockeinheiten(loadUnit: loadUnit, secondaryUnit: secondaryUnit, volumeKind: volumeKind)
    }

    init(station: Station, exerciseId: String,
         einheiten: Blockeinheiten = .kilogrammWiederholungen, saetze: [LokalerSatz]) {
        stationSchluessel = station.schluessel
        machineId = station.machineId
        equipmentModelId = station.equipmentModelId
        self.exerciseId = exerciseId
        loadUnit = einheiten.loadUnit
        secondaryUnit = einheiten.secondaryUnit
        volumeKind = einheiten.volumeKind
        self.saetze = saetze
    }

    /// Der Block an einem Geraet, wenn nur dessen Kennung vorliegt (Altbestand
    /// der Tests und Dateien von vor dem Katalog).
    init(machineId: String, exerciseId: String,
         einheiten: Blockeinheiten = .kilogrammWiederholungen, saetze: [LokalerSatz]) {
        stationSchluessel = "geraet:\(machineId)"
        self.machineId = machineId
        equipmentModelId = nil
        self.exerciseId = exerciseId
        loadUnit = einheiten.loadUnit
        secondaryUnit = einheiten.secondaryUnit
        volumeKind = einheiten.volumeKind
        self.saetze = saetze
    }

    private enum CodingKeys: String, CodingKey {
        case stationSchluessel, machineId, equipmentModelId, exerciseId, loadUnit, secondaryUnit, volumeKind, saetze
    }

    /// Derselbe Grund wie bei LokalerSatz: ein Block aus der Fassung vor
    /// 0046 traegt keine Einheiten, und er war Kilogramm mal
    /// Wiederholungen. Ein Block von vor dem Katalog traegt nur machineId --
    /// sein Schluessel ist dann "geraet:<id>", wie ihn der Server bildet.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let alt = Blockeinheiten.kilogrammWiederholungen
        machineId = try c.decodeIfPresent(String.self, forKey: .machineId)
        equipmentModelId = try c.decodeIfPresent(String.self, forKey: .equipmentModelId)
        if let schluessel = try c.decodeIfPresent(String.self, forKey: .stationSchluessel) {
            stationSchluessel = schluessel
        } else if let machineId {
            stationSchluessel = "geraet:\(machineId)"
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.stationSchluessel,
                .init(codingPath: c.codingPath, debugDescription: "Block ohne Station"))
        }
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
    /// Seit wann die laufende Pause dauert; nil, solange trainiert wird
    /// (Testnotiz 05.10., #7, #11). Nur lokal: der Server kennt keine
    /// Pause, er bekommt weiter Saetze mit ihren Zeitpunkten.
    var pausiertSeit: Date? = nil
    /// Die Summe aller abgeschlossenen Pausen.
    var pausenDauer: TimeInterval = 0
    /// Der Ort der Einheit, gesetzt mit dem ersten Satz mit bekanntem Ort;
    /// nil bei Dateien von vor dem Katalog.
    var ort: Ort? = nil

    var letzterSatzAm: Date? {
        bloecke.flatMap(\.saetze).map(\.performedAt).max()
    }

    /// Ohne Satz ist eine Einheit ein Fehlstart, kein Training: sie wird
    /// verworfen, nicht abgeschlossen (Sammelstelle, Entschieden 2).
    var hatSaetze: Bool { bloecke.contains { !$0.saetze.isEmpty } }

    var istPausiert: Bool { pausiertSeit != nil }

    /// Trainierte Zeit bis `jetzt`, ohne Pausen. Eine laufende Pause
    /// friert die Uhr ein: gezaehlt wird nur bis zu ihrem Beginn. Liegt
    /// `jetzt` vor dem Pausenbeginn (der Abschluss rechnet bis zum letzten
    /// Satz), zaehlt sie gar nicht.
    func trainiert(bis jetzt: Date) -> TimeInterval {
        let ende = pausiertSeit.map { min($0, jetzt) } ?? jetzt
        return max(0, ende.timeIntervalSince(startedAt) - pausenDauer)
    }

    /// Idempotent: ein zweiter Tap verschiebt den Pausenbeginn nicht.
    mutating func pausieren(jetzt: Date) {
        guard pausiertSeit == nil else { return }
        pausiertSeit = jetzt
    }

    mutating func fortsetzen(jetzt: Date) {
        guard let seit = pausiertSeit else { return }
        pausenDauer += max(0, jetzt.timeIntervalSince(seit))
        pausiertSeit = nil
    }
}

extension LokaleSession {
    private enum CodingKeys: String, CodingKey {
        case id, startedAt, bloecke, pausiertSeit, pausenDauer, ort
    }

    /// Eine Sessiondatei von vor der Pause kennt beide Felder nicht. Ohne
    /// den Rueckfall dekodierte sie nicht mehr, und ein App-Update mitten
    /// im Training loeschte die laufende Einheit -- derselbe Grund wie bei
    /// LokalerSatz.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        bloecke = try c.decode([LokalerBlock].self, forKey: .bloecke)
        pausiertSeit = try c.decodeIfPresent(Date.self, forKey: .pausiertSeit)
        pausenDauer = try c.decodeIfPresent(TimeInterval.self, forKey: .pausenDauer) ?? 0
        ort = try c.decodeIfPresent(Ort.self, forKey: .ort)
    }
}
