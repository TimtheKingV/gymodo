import Foundation
import Testing
@testable import FitnessMember

@Suite("RootDestinationLogic")
struct RootDestinationLogicTests {
    private let session = Session(accessToken: "t", userId: "u", email: "lena@example.de", expiresAt: .distantFuture)

    @Test("ohne Session immer authFlow, unabhaengig vom Catalog-Zustand")
    func noSessionAlwaysAuthFlow() {
        #expect(RootDestinationLogic.destination(session: nil, catalogState: .idle, onboardingOffen: false) == .authFlow)
        #expect(RootDestinationLogic.destination(session: nil, catalogState: .loaded, onboardingOffen: false) == .authFlow)
    }

    @Test("Session, Catalog laedt noch: loadingCatalog")
    func loadingShowsSpinner() {
        #expect(RootDestinationLogic.destination(session: session, catalogState: .loading, onboardingOffen: false) == .loadingCatalog)
        #expect(RootDestinationLogic.destination(session: session, catalogState: .idle, onboardingOffen: false) == .loadingCatalog)
    }

    @Test("Session, geladen: immer main -- auch ohne Studio")
    func loadedIsMain() {
        #expect(RootDestinationLogic.destination(session: session, catalogState: .loaded, onboardingOffen: false) == .main)
    }

    @Test("ein fehlgeschlagenes Laden fuehrt auf den Ladefehler -- nicht auf main")
    func failedGetsOwnScreen() {
        #expect(RootDestinationLogic.destination(session: session, catalogState: .failed, onboardingOffen: false) == .ladefehler)
    }

    // Regressionstest zum Ausfall vom 18. September: ein Serverausfall darf
    // nie wie ein geladener Katalog aussehen.
    @Test("Ladefehler und geladen sind zwei verschiedene Ziele")
    func failedIsNotLoaded() {
        let beiFehler = RootDestinationLogic.destination(session: session, catalogState: .failed, onboardingOffen: false)
        let geladen = RootDestinationLogic.destination(session: session, catalogState: .loaded, onboardingOffen: false)
        #expect(beiFehler != geladen)
    }

    // MARK: - Onboarding-Gate (Aufgabe 6)

    @Test("offenes Onboarding geht vor main")
    func onboardingBeforeMain() {
        #expect(RootDestinationLogic.destination(session: session, catalogState: .loaded, onboardingOffen: true) == .onboarding)
    }

    @Test("waehrend des Ladens zeigt onboardingOffen nichts -- ein gescheiterter Bootstrap darf es nicht raten")
    func onboardingNeverWhileLoading() {
        #expect(RootDestinationLogic.destination(session: session, catalogState: .loading, onboardingOffen: true) == .loadingCatalog)
        #expect(RootDestinationLogic.destination(session: session, catalogState: .idle, onboardingOffen: true) == .loadingCatalog)
    }

    @Test("ein gescheiterter Bootstrap zeigt nie das Onboarding")
    func onboardingNeverWhenFailed() {
        #expect(RootDestinationLogic.destination(session: session, catalogState: .failed, onboardingOffen: true) == .ladefehler)
    }

    @Test("ohne Session nie das Onboarding, egal was onboardingOffen sagt")
    func onboardingNeverWithoutSession() {
        #expect(RootDestinationLogic.destination(session: nil, catalogState: .loaded, onboardingOffen: true) == .authFlow)
    }

    // MARK: - Der Kaltstart (Testnotiz 19. September, Eintrag 1)

    @Test("vor der Wiederherstellung zeigt eine fehlende Session den Ladeschirm, nicht die Anmeldung")
    func startBeforeRestore() {
        #expect(
            RootDestinationLogic.destination(
                session: nil, catalogState: .idle, onboardingOffen: false,
                wiederhergestellt: false) == .start)
    }

    @Test("nach der Wiederherstellung heisst 'keine Session' wieder authFlow")
    func authFlowAfterRestore() {
        #expect(
            RootDestinationLogic.destination(
                session: nil, catalogState: .idle, onboardingOffen: false,
                wiederhergestellt: true) == .authFlow)
    }

    // Der Regressionstest zum aufblitzenden Anmeldebildschirm: solange
    // niemand nachgesehen hat, ob eine Sitzung im Schluesselbund liegt,
    // darf die Wurzel das Passwortfeld nicht zeichnen. Egal, was der
    // Katalog gerade sagt -- er kann ohne Session ohnehin nichts wissen.
    @Test("ein nicht wiederhergestellter Start fuehrt in KEINEM Katalogzustand auf authFlow")
    func startNeverAuthFlow() {
        let zustaende: [CatalogLoadState] = [
            .idle, .loading, .loaded, .failed,
        ]
        for zustand in zustaende {
            #expect(
                RootDestinationLogic.destination(
                    session: nil, catalogState: zustand, onboardingOffen: false,
                    wiederhergestellt: false) != .authFlow)
        }
    }

    // Wer sich gerade erst angemeldet hat, hat nie eine Wiederherstellung
    // gebraucht -- die Session steht trotzdem, und der Ladeschirm waere
    // hier ein Rueckschritt statt eines Fortschritts.
    @Test("eine frische Anmeldung gewinnt gegen das Flag")
    func freshSignInBeatsFlag() {
        #expect(
            RootDestinationLogic.destination(
                session: session, catalogState: .loaded, onboardingOffen: false,
                wiederhergestellt: false) == .main)
    }
}
