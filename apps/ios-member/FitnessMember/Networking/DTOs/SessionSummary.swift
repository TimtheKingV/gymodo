import Foundation

struct SessionsResponse: Codable, Equatable {
    let sessions: [SessionSummary]
    let summary: SessionsSummary
}

/// Die Kopfzeile von Home.dc.html. Serverseitig gerechnet: die
/// Gesamtzahl steht ueber der gedeckelten Liste, und die Wochengrenze
/// faellt in die Studio-Zeitzone -- beides kann der Client nicht.
///
/// Codable statt nur Decodable (Aufgabe 5): VerlaufFileStore schreibt
/// diesen Typ als Teil von GespeicherterVerlauf auf Platte.
struct SessionsSummary: Codable, Equatable {
    let totalCount: Int
    /// `nil` ohne aktives Studio -- dann zeigt Home die Wochenzahl nicht.
    let thisWeekCount: Int?
    let lastSessionAt: String?
    /// `nil` aus demselben Grund wie `thisWeekCount`, und zusaetzlich bei
    /// jedem Stand, der noch aus einem Cache von vor dieser Fassung
    /// kommt -- deshalb optional. Dann bleibt der Streifen aus, bis der
    /// naechste Abruf durch ist.
    let streak: Serienstand?
}

/// Der Stand der Serie am Kopf des Home-Tabs -- serverseitig gerechnet.
///
/// Alles in ORTSDATEN ("yyyy-MM-dd", Zeitzone des Studios), nicht in
/// Zeitpunkten: der Client zeichnet daraus sieben Tagesboxen und soll die
/// Wochengrenze nicht ein zweites Mal selbst rechnen. Dieselbe Festlegung
/// wie bei `CourseWeekSession.localDay` im Kursplan.
struct Serienstand: Codable, Equatable {
    /// Wochen in Folge mit mindestens einer Einheit. Die laufende Woche
    /// zaehlt mit, sobald ihre erste Einheit steht -- bis dahin steht
    /// hier der Wert der Vorwoche. `0` heisst: auch die Vorwoche blieb
    /// leer.
    let weeks: Int
    /// Der Montag der laufenden Woche.
    let weekStart: String
    let today: String
    /// Die Tage der laufenden Woche mit mindestens einer Einheit.
    let trainedDays: [String]
}

/// Codable statt nur Decodable (Aufgabe 5): derselbe Grund wie bei
/// SessionsSummary -- der Verlauf-Cache muss diesen Typ schreiben koennen.
struct SessionSummary: Codable, Equatable, Identifiable {
    struct Block: Codable, Equatable {
        struct Set: Codable, Equatable {
            let setIndex: Int
            let weightKg: Double
            let reps: Int
            let rir: Double?
            let problemFlag: Bool
            let problemReason: ProblemReason?
            let performedAt: String
        }
        let machineId: String
        let machineLabel: String
        let exerciseId: String
        let exerciseName: String
        let sets: [Set]
    }

    let id: String
    let startedAt: String
    let completedAt: String?
    let completedReason: String? // "manual" | "auto" | null
    let machineCount: Int
    let setCount: Int
    let blocks: [Block]
}
