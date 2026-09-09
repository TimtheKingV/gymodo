import Foundation
import Testing
@testable import FitnessMember

@Suite("RootDestinationLogic")
struct RootDestinationLogicTests {
    private let session = Session(accessToken: "t", userId: "u", email: "lena@example.de", expiresAt: .distantFuture)

    @Test("ohne Session immer authFlow, unabhaengig vom Catalog-Zustand")
    func noSessionAlwaysAuthFlow() {
        #expect(RootDestinationLogic.destination(session: nil, catalogState: .idle) == .authFlow)
        #expect(RootDestinationLogic.destination(session: nil, catalogState: .loaded(hasStudio: true)) == .authFlow)
    }

    @Test("Session, Catalog laedt noch: loadingCatalog")
    func loadingShowsSpinner() {
        #expect(RootDestinationLogic.destination(session: session, catalogState: .loading) == .loadingCatalog)
        #expect(RootDestinationLogic.destination(session: session, catalogState: .idle) == .loadingCatalog)
    }

    @Test("Session, geladen ohne Studio: noStudio")
    func loadedWithoutStudio() {
        #expect(RootDestinationLogic.destination(session: session, catalogState: .loaded(hasStudio: false)) == .noStudio)
    }

    @Test("Session, geladen mit Studio: main")
    func loadedWithStudio() {
        #expect(RootDestinationLogic.destination(session: session, catalogState: .loaded(hasStudio: true)) == .main)
    }

    @Test("ein fehlgeschlagenes Laden fuehrt konservativ zu noStudio, nicht main")
    func failedFallsBackToNoStudio() {
        #expect(RootDestinationLogic.destination(session: session, catalogState: .failed) == .noStudio)
    }

    @Test("sollteZuruecksetzen ist wahr fuer authFlow, unabhaengig vom Weg dorthin")
    func sollteZuruecksetzenTrueForAuthFlow() {
        // Deckt beide Wege nach .authFlow ab: die explizite Abmeldung
        // (Session ging von etwas auf nichts ueber) und ein abgelaufenes
        // Token, das schon beim ersten Aufruf in dieser Prozesslaufzeit
        // nil liefert -- ein Wachposten nach dem Muster "hatte je eine
        // Session" wuerde den zweiten Fall verpassen.
        #expect(RootDestinationLogic.sollteZuruecksetzen(destination: .authFlow) == true)
    }

    @Test("sollteZuruecksetzen ist falsch fuer jede andere Zielansicht")
    func sollteZuruecksetzenFalseOtherwise() {
        #expect(RootDestinationLogic.sollteZuruecksetzen(destination: .loadingCatalog) == false)
        #expect(RootDestinationLogic.sollteZuruecksetzen(destination: .noStudio) == false)
        #expect(RootDestinationLogic.sollteZuruecksetzen(destination: .main) == false)
    }
}
