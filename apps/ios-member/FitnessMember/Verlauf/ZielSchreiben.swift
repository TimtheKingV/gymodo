import Foundation

/// Ruling R27: DER eine Schreibweg eines Ziels (setzen oder aufgeben) --
/// Home (R23, "Neues Ziel setzen") und das Profil (Aufgabe 10) riefen
/// `setGoal`/`dropGoal` sonst an zwei Stellen mit denselben zwei
/// Nachlade-Schritten auf. `@MainActor`, weil beide Stores dieselbe
/// Isolation tragen (siehe deren Dokumentation) und dieser Typ sie direkt
/// haelt statt ueber `@Environment`.
@MainActor
enum ZielSchreiben {
    /// Nach `setGoal`/`dropGoal` IMMER beides neu laden -- der Kalender
    /// liest `weeklyTarget` aus `/me/sessions` (`VerlaufStore.laden`),
    /// nicht aus dem Bootstrap (Spec 4.5). Ein neues Zielgewicht macht
    /// ausserdem die alte "erreicht"-Zeile ungueltig: sie gehoerte zum
    /// Ziel, das dieser Aufruf gerade ersetzt.
    static func setzen(
        kind: String, targetValue: Double, apiClient: APIClient, katalog: CatalogStore, verlauf: VerlaufStore
    ) async -> String? {
        do throws(APIError) {
            _ = try await apiClient.setGoal(ZielWrite(kind: kind, targetValue: targetValue))
            if kind == ZielSheet.Art.zielgewicht.kind { verlauf.neuesZielgewichtGesetzt() }
            await katalog.load()
            await verlauf.laden(studioId: katalog.activeStudioId)
            return nil
        } catch {
            guard error != .offline else { return "Keine Verbindung. Das Ziel wurde nicht geändert." }
            return error.servertext
        }
    }

    /// "Aufgeben", kein Loeschen -- der Server setzt das aktive Ziel auf
    /// `dropped` (Spec 4.4), die Geschichte bleibt beim Mitglied.
    static func aufgeben(
        kind: String, apiClient: APIClient, katalog: CatalogStore, verlauf: VerlaufStore
    ) async -> String? {
        do throws(APIError) {
            try await apiClient.dropGoal(kind: kind)
            await katalog.load()
            await verlauf.laden(studioId: katalog.activeStudioId)
            return nil
        } catch {
            guard error != .offline else { return "Keine Verbindung. Das Ziel wurde nicht aufgegeben." }
            return error.servertext
        }
    }
}
