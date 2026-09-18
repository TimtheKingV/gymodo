import Foundation
import Testing
@testable import FitnessMember

@Suite("RootDestinationLogic")
struct RootDestinationLogicTests {
    private let session = Session(accessToken: "t", userId: "u", email: "lena@example.de", expiresAt: .distantFuture)

    @Test("ohne Session immer authFlow, unabhaengig vom Catalog-Zustand")
    func noSessionAlwaysAuthFlow() {
        #expect(RootDestinationLogic.destination(session: nil, catalogState: .idle, onboardingOffen: false) == .authFlow)
        #expect(RootDestinationLogic.destination(session: nil, catalogState: .loaded(hasStudio: true), onboardingOffen: false) == .authFlow)
    }

    @Test("Session, Catalog laedt noch: loadingCatalog")
    func loadingShowsSpinner() {
        #expect(RootDestinationLogic.destination(session: session, catalogState: .loading, onboardingOffen: false) == .loadingCatalog)
        #expect(RootDestinationLogic.destination(session: session, catalogState: .idle, onboardingOffen: false) == .loadingCatalog)
    }

    @Test("Session, geladen ohne Studio: noStudio")
    func loadedWithoutStudio() {
        #expect(RootDestinationLogic.destination(session: session, catalogState: .loaded(hasStudio: false), onboardingOffen: false) == .noStudio)
    }

    @Test("Session, geladen mit Studio: main")
    func loadedWithStudio() {
        #expect(RootDestinationLogic.destination(session: session, catalogState: .loaded(hasStudio: true), onboardingOffen: false) == .main)
    }

    @Test("ein fehlgeschlagenes Laden fuehrt auf den Ladefehler -- nicht auf main und nicht auf noStudio")
    func failedGetsOwnScreen() {
        #expect(RootDestinationLogic.destination(session: session, catalogState: .failed, onboardingOffen: false) == .ladefehler)
    }

    // Der Regressionstest zum Ausfall vom 18. September: .failed und
    // "geladen, kein Studio" sind zwei verschiedene Aussagen und duerfen nie
    // wieder auf denselben Bildschirm fallen. Solange diese beiden Werte
    // sich unterscheiden, kann ein Serverausfall nicht mehr als
    // Mitgliedschaftslage durchgehen.
    @Test("Ladefehler und 'kein Studio' sind zwei verschiedene Ziele")
    func failedIsNotNoStudio() {
        let beiFehler = RootDestinationLogic.destination(session: session, catalogState: .failed, onboardingOffen: false)
        let ohneStudio = RootDestinationLogic.destination(session: session, catalogState: .loaded(hasStudio: false), onboardingOffen: false)
        #expect(beiFehler != ohneStudio)
    }

    // MARK: - Onboarding-Gate (Aufgabe 6)

    @Test("offenes Onboarding geht vor noStudio -- die Angaben gehoeren zur Person, nicht zum Studio")
    func onboardingBeforeNoStudio() {
        #expect(RootDestinationLogic.destination(session: session, catalogState: .loaded(hasStudio: false), onboardingOffen: true) == .onboarding)
    }

    @Test("offenes Onboarding geht vor main")
    func onboardingBeforeMain() {
        #expect(RootDestinationLogic.destination(session: session, catalogState: .loaded(hasStudio: true), onboardingOffen: true) == .onboarding)
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
        #expect(RootDestinationLogic.destination(session: nil, catalogState: .loaded(hasStudio: false), onboardingOffen: true) == .authFlow)
    }
}
