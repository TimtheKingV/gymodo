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

    @Test("ein fehlgeschlagenes Laden fuehrt konservativ zu noStudio, nicht main")
    func failedFallsBackToNoStudio() {
        #expect(RootDestinationLogic.destination(session: session, catalogState: .failed, onboardingOffen: false) == .noStudio)
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
        #expect(RootDestinationLogic.destination(session: session, catalogState: .failed, onboardingOffen: true) == .noStudio)
    }

    @Test("ohne Session nie das Onboarding, egal was onboardingOffen sagt")
    func onboardingNeverWithoutSession() {
        #expect(RootDestinationLogic.destination(session: nil, catalogState: .loaded(hasStudio: false), onboardingOffen: true) == .authFlow)
    }
}
