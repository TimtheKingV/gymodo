import Foundation
import Testing
@testable import FitnessMember

struct PfadbereinigungTests {
    private let geraet = GeraetRoute.geraet(station: "geraet:m", exerciseId: "e", token: nil)
    @MainActor
    private var abschluss: GeraetRoute {
        let store = WorkoutSessionStore(fileStore: SessionFileStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        _ = store.satzSichern(station: .testGeraet("m"), exerciseId: "e",
                              einheiten: .kilogrammWiederholungen, load: 40, volume: 10,
                              problemFlag: false, problemReason: nil)
        let session = store.aktiveSession()!
        return .abschluss(sessionId: session.id, zusammenfassung: Trainingszusammenfassung(session)!)
    }

    @Test func endetDieEinheitVonAussenWirdGeleert() {
        #expect(Pfadbereinigung.leeren(laeuftVorher: true, laeuftJetzt: false, pfad: [geraet]))
    }

    @Test func laeuftSieWeiterOderStartetSieWirdNichtGeleert() {
        #expect(!Pfadbereinigung.leeren(laeuftVorher: true, laeuftJetzt: true, pfad: [geraet]))
        #expect(!Pfadbereinigung.leeren(laeuftVorher: false, laeuftJetzt: true, pfad: [geraet]))
    }

    @MainActor
    @Test func derAbschlussScreenBleibtStehen() {
        #expect(!Pfadbereinigung.leeren(laeuftVorher: true, laeuftJetzt: false, pfad: [abschluss]))
    }

    /// Training fortsetzen (Testnotiz 14.10., 18:45 #3): wird genau die
    /// Einheit des stehenden Abschlusses wieder aktiv, geht es zur Wurzel.
    @MainActor
    @Test func fortgesetzteEinheitRaeumtDenAbschluss() {
        let route = abschluss
        guard case .abschluss(let id, _) = route else { Issue.record("kein Abschluss"); return }
        #expect(Pfadbereinigung.nachFortsetzenLeeren(aktiveId: id, pfad: [route]))
    }

    @MainActor
    @Test func einAnderesTrainingRaeumtDenAbschlussNicht() {
        #expect(!Pfadbereinigung.nachFortsetzenLeeren(aktiveId: UUID(), pfad: [abschluss]))
        #expect(!Pfadbereinigung.nachFortsetzenLeeren(aktiveId: nil, pfad: [abschluss]))
        #expect(!Pfadbereinigung.nachFortsetzenLeeren(aktiveId: UUID(), pfad: [geraet]))
    }
}
