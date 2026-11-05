import Foundation
import Observation

/// Die abgehakten Cardio-Tage ("YYYY-MM-DD"), geteilt von Plan-Tab und Home.
///
/// Frueher hielt der Plan-Tab sie als eigenen `@State`; seit Home die Woche
/// markiert (Spec 1.1), lesen beide denselben Stand -- ein Haken im Plan steht
/// ohne zweiten Abruf auch auf Home.
@MainActor
@Observable
final class CardioChecksStore {
    private(set) var erledigt: Set<String> = []
    /// Die erfolgreich geladenen Bereiche ("YYYY-MM-DD", eingeschlossen). Nur
    /// darin heisst ein fehlender Haken "nicht gemacht"; ausserhalb (noch nicht
    /// geladen, Abruf fehlgeschlagen) weiss die App es nicht -- der Plan-Kalender
    /// laesst vergangene Cardio-Slots dort neutral statt "verpasst".
    private(set) var geladen: [ClosedRange<String>] = []
    /// Jede Aenderung am Haken zaehlt hoch; eine GET-Antwort, die vor ihr
    /// losging, wird verworfen (wie `KurseStore.generation`) -- sonst
    /// ueberschriebe ein aelterer Stand den frisch gesetzten Haken.
    private var generation = 0

    /// Laedt `von`...`bis` (eingeschlossen). Ein Fehler laesst den letzten Stand
    /// stehen: der Haken ist kein Grund fuer einen Fehlerzustand.
    func laden(von: String, bis: String, apiClient: APIClient) async {
        let start = generation
        do throws(APIError) {
            let tage = try await apiClient.cardioChecks(from: von, to: bis)
            guard start == generation else { return }
            erledigt = Self.zusammenfuehren(alt: erledigt, neu: Set(tage), von: von, bis: bis)
            geladen = Self.bereiche(alt: geladen, von: von, bis: bis)
        } catch {
            // Bleibt beim letzten Stand.
        }
    }

    /// Setzt oder nimmt den Haken; liefert bei einem Fehler den Servertext.
    func setzen(tagId: String, erledigt neu: Bool, apiClient: APIClient) async -> String? {
        generation += 1
        do throws(APIError) {
            if neu {
                try await apiClient.setCardioCheck(day: tagId)
                erledigt.insert(tagId)
            } else {
                try await apiClient.deleteCardioCheck(day: tagId)
                erledigt.remove(tagId)
            }
            return nil
        } catch {
            return error.servertext
        }
    }

    /// Ersetzt nur den geladenen Bereich: Home laedt eine Woche, der Plan-Tab
    /// mehrere -- keiner soll dem anderen die Tage ausserhalb seines Fensters
    /// loeschen. "YYYY-MM-DD" vergleicht sich als Text wie als Datum.
    nonisolated static func zusammenfuehren(alt: Set<String>, neu: Set<String>, von: String, bis: String) -> Set<String> {
        alt.filter { $0 < von || $0 > bis }.union(neu)
    }

    /// Merkt sich `von`...`bis` als geladen; ein schon abgedeckter Bereich
    /// kommt nicht doppelt hinzu (der Plan-Tab laedt bei jedem Erscheinen).
    nonisolated static func bereiche(alt: [ClosedRange<String>], von: String, bis: String) -> [ClosedRange<String>] {
        guard von <= bis else { return alt }
        if alt.contains(where: { $0.contains(von) && $0.contains(bis) }) { return alt }
        return alt + [von...bis]
    }
}
