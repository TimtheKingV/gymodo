import Foundation

/// Der Trainingsplan des Mitglieds (einer, ortsunabhaengig), wie ihn der
/// Bootstrap (`PlanFuerApp`) liefert. Dieselbe Struktur dekodiert auch die Antwort von createPlan,
/// acceptPlan und swapPlanPosition (`TrainingPlan` im Server): dort heisst
/// die Kennung `id`, und die App-Felder (naechste Einheit, Zaehler,
/// Alternativen) fehlen. Ein zweiter Typ mit fast denselben Feldern waere
/// eine Wahrheit an zwei Orten; wer nach einem Schreibweg den Zaehlerstand
/// braucht, laedt den Bootstrap neu.
///
/// Heisst nicht `TrainingsProfil`-aehnlich: `TrainingsProfil` gibt es schon
/// (Verlauf), deshalb die Trainingsplan*-Namen.
struct Trainingsplan: Decodable, Equatable, Sendable {
    let planId: String
    /// Das Katalogstudio, aus dem der Plan erzeugt wurde; nil fuer einen Plan
    /// ohne Studio (Freies Training). Kein Ort, an den der Plan gebunden
    /// waere: er gilt ueberall.
    let studioId: String?
    let version: Int
    let regelVersion: String
    let struktur: String
    let einheiten: [TrainingsplanEinheit]
    let gruende: [String]
    /// nil nur in der Antwort eines Schreibwegs, nie im Bootstrap.
    let naechsteEinheitKey: String?
    let zuletztEinheitKey: String?
    let einheitenErledigt: Int
    let anfaengerUebergang: Bool
    /// Tauschkandidaten je Baustein; ein Baustein ohne Kandidat fehlt ganz.
    let alternativen: [String: [PlanAlternative]]
    /// Zielgewichte je Planposition (Etappe 4, G8/G17), geschluesselt mit
    /// `zielSchluessel`. Leer in einer alten Server-Antwort und fuer
    /// Positionen ohne Ziel -- dann gilt wie im freien Training das letzte
    /// Gewicht. Die App rechnet daran nichts (F15), sie zeigt nur an.
    let zielgewichte: [String: Zielgewicht]
    /// Was das Mitglied gesperrt hat (nur an den Eigentuemer, Task 8 filtert
    /// damit). Leer in einer alten Server-Antwort und in der eines Schreibwegs.
    let merkliste: PlanMerkliste

    private enum CodingKeys: String, CodingKey {
        case planId, id, studioId, version, regelVersion, struktur, einheiten, gruende,
             naechsteEinheitKey, zuletztEinheitKey, einheitenErledigt, anfaengerUebergang, alternativen,
             zielgewichte, merkliste
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        planId = try c.decodeIfPresent(String.self, forKey: .planId) ?? c.decode(String.self, forKey: .id)
        studioId = try c.decodeIfPresent(String.self, forKey: .studioId)
        version = try c.decode(Int.self, forKey: .version)
        regelVersion = try c.decode(String.self, forKey: .regelVersion)
        struktur = try c.decode(String.self, forKey: .struktur)
        einheiten = try c.decode([TrainingsplanEinheit].self, forKey: .einheiten)
        gruende = try c.decodeIfPresent([String].self, forKey: .gruende) ?? []
        naechsteEinheitKey = try c.decodeIfPresent(String.self, forKey: .naechsteEinheitKey)
        zuletztEinheitKey = try c.decodeIfPresent(String.self, forKey: .zuletztEinheitKey)
        einheitenErledigt = try c.decodeIfPresent(Int.self, forKey: .einheitenErledigt) ?? 0
        anfaengerUebergang = try c.decodeIfPresent(Bool.self, forKey: .anfaengerUebergang) ?? false
        alternativen = try c.decodeIfPresent([String: [PlanAlternative]].self, forKey: .alternativen) ?? [:]
        zielgewichte = try c.decodeIfPresent([String: Zielgewicht].self, forKey: .zielgewichte) ?? [:]
        merkliste = try c.decodeIfPresent(PlanMerkliste.self, forKey: .merkliste) ?? PlanMerkliste()
    }

    /// Wie `zielSchluessel` in packages/domain/src/plangewichte.ts: erst
    /// Einheit und Position zusammen bezeichnen eine Position, weil der
    /// Generator die Positionen je Einheit ab "0" nummeriert.
    static func zielSchluessel(einheitKey: String, positionKey: String) -> String {
        "\(einheitKey):\(positionKey)"
    }

    func zielgewicht(einheitKey: String, positionKey: String) -> Zielgewicht? {
        zielgewichte[Self.zielSchluessel(einheitKey: einheitKey, positionKey: positionKey)]
    }
}

/// Das Zielgewicht einer Planposition (`PositionsZiel` im Server).
/// `aenderung` ist Ziel minus zuletzt tatsaechlich benutztes Gewicht an
/// diesem Geraet und dieser Uebung (nil: kein Vorgaenger oder gleich),
/// `grund` der Code der Rechnung -- beides nur fuer den Hinweis (G17).
/// Text statt Enum: ein Code, den erst ein spaeterer Server kennt, darf
/// den Bootstrap nicht unlesbar machen.
struct Zielgewicht: Decodable, Equatable, Sendable {
    let load: Double
    let secondaryLoad: Double?
    let aenderung: Double?
    let grund: String?
}

struct TrainingsplanEinheit: Decodable, Equatable, Sendable {
    let key: String
    let positionen: [TrainingsplanPosition]
    /// Kann eine Kommazahl sein (46,5).
    let geschaetzteMinuten: Double?
}

/// Rolle, Typ und Baustein bleiben Text: ein Wert, den erst ein spaeterer
/// Server kennt, machte sonst den ganzen Bootstrap unlesbar.
struct TrainingsplanPosition: Decodable, Equatable, Sendable {
    let key: String
    let baustein: String
    let rolle: String
    let exerciseId: String
    /// Das Katalogmodell der Position; welches Geraet im Studio es ist,
    /// entscheidet erst die Geraeteauswahl.
    let modelId: String
    let typ: String
    let saetze: Int
    let wdhVon: Int?
    let wdhBis: Int?
    let reserveVon: Int
    let reserveBis: Int
    let pauseSek: Int
    let aufwaermsatz: Bool
    let dauerMin: Int?
    let hauptmuskeln: [String]
}

/// Ein Tauschkandidat; der Server nennt bewusst nur die IDs (keine
/// Beschwerdehinweise, das waeren Gesundheitsdaten).
struct PlanAlternative: Codable, Equatable, Sendable {
    let exerciseId: String
    let modelId: String
}

/// Die Merkliste des Mitglieds (`PlanMerkliste` im Server): je Ort die
/// Uebungen, die dort fehlen, und ueberall die, die ihm nicht gefallen.
/// Eine Angabe zur Person: nie loggen.
struct PlanMerkliste: Codable, Equatable, Sendable {
    /// Ort-ID -> Uebungs-IDs.
    var nichtVorhanden: [String: [String]] = [:]
    var gefaelltNicht: [String] = []
}

/// Das Trainingsprofil in der Antwort und im PUT-Rumpf von
/// /me/training-profile. Text statt Enum aus dem Grund der Positionen.
struct TrainingsplanProfil: Codable, Equatable, Sendable {
    let minutes: Int
    let experience: String
    let focus: [String]
}

/// Planstand der laufenden Einheit, der mit jedem Satz-PUT mitgeht
/// (workout.ts sessionPlanSchema).
struct PlanMomentaufnahme: Codable, Equatable, Sendable {
    enum Status: String, Codable, Equatable, Sendable {
        case offen, erledigt, optional, getauscht
    }

    struct Position: Codable, Equatable, Sendable {
        let key: String
        let status: Status
        /// Die ERSATZuebung dieser Position, sonst nil (nil wird nicht mitgeschickt).
        let exerciseId: String?
    }

    let planId: String
    let einheitKey: String
    let stand: Int
    let positionen: [Position]
}
