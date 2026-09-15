#if DEBUG
import Foundation
import Testing
@testable import FitnessMember

struct TestnotizScreenStapelTests {
    private let training = ScreenEintrag(datei: "apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift")
    private let geraet = ScreenEintrag(datei: "apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift")
    private let sheet = ScreenEintrag(datei: "apps/ios-member/FitnessMember/Screens/Geraet/UebungWechselnSheet.swift")

    @Test func nameIstDerDateinameOhneEndung() {
        #expect(geraet.name == "GeraetView")
    }

    // Beobachtete Reihenfolge beim Push (Spike 2026-09-14): das Ziel
    // erscheint, DANACH verschwindet die Wurzel.
    @Test func pushErsetztDieWurzel() {
        var s = TestnotizScreenStapel()
        s.erschienen(training)
        s.erschienen(geraet)
        s.verschwunden(token: training.token)
        #expect(s.aktueller?.name == "GeraetView")
        #expect(s.pfad == [geraet.datei])
    }

    // Beim Pop: die Wurzel erscheint wieder, danach verschwindet das Ziel.
    @Test func popLegtDieWurzelFrei() {
        var s = TestnotizScreenStapel()
        s.erschienen(training)
        s.erschienen(geraet)
        s.verschwunden(token: training.token)
        s.erschienen(training)
        s.verschwunden(token: geraet.token)
        #expect(s.aktueller?.name == "TrainingRootView")
        #expect(s.pfad == [training.datei])
    }

    // Ein Sheet ueberdeckt, ohne dass der Screen darunter verschwindet.
    @Test func sheetLiegtObenUndGehtWiederWeg() {
        var s = TestnotizScreenStapel()
        s.erschienen(geraet)
        s.erschienen(sheet)
        #expect(s.pfad == [geraet.datei, sheet.datei])
        s.verschwunden(token: sheet.token)
        #expect(s.aktueller?.name == "GeraetView")
    }

    // Tab-Wechsel in beiden denkbaren Reihenfolgen.
    @Test func tabwechselInBeidenReihenfolgen() {
        var a = TestnotizScreenStapel()
        a.erschienen(training)
        a.erschienen(geraet)
        a.verschwunden(token: training.token)
        #expect(a.aktueller?.name == "GeraetView")

        var b = TestnotizScreenStapel()
        b.erschienen(training)
        b.verschwunden(token: training.token)
        b.erschienen(geraet)
        #expect(b.aktueller?.name == "GeraetView")
        #expect(b.pfad == [geraet.datei])
    }

    // Modifier an einer Group werden auf jedes Kind verteilt: das neue Kind
    // erscheint mit demselben Token, bevor das alte verschwindet.
    @Test func gruppenwechselVerliertDenScreenNicht() {
        var s = TestnotizScreenStapel()
        let flow = ScreenEintrag(datei: "apps/ios-member/FitnessMember/Screens/Geraet/ErstkontaktFlow.swift")
        s.erschienen(flow)
        s.erschienen(flow)
        s.verschwunden(token: flow.token)
        #expect(s.aktueller?.name == "ErstkontaktFlow")
        s.verschwunden(token: flow.token)
        #expect(s.aktueller == nil)
    }

    @Test func unbekanntesVerschwindenAendertNichts() {
        var s = TestnotizScreenStapel()
        s.erschienen(geraet)
        s.verschwunden(token: UUID())
        #expect(s.pfad == [geraet.datei])
    }

    @Test func kontextWirdNachgezogen() {
        var s = TestnotizScreenStapel()
        s.erschienen(geraet)
        s.kontextAktualisieren(token: geraet.token, kontext: ["phase": "pause"])
        #expect(s.aktueller?.kontext == ["phase": "pause"])
    }

    @Test func quellpfadIstRepoRelativ() {
        #expect(Quellpfad.relativ("/Users/tim/Documents/fitness-app/apps/ios-member/FitnessMember/Screens/Home/HomeRootView.swift")
                == "apps/ios-member/FitnessMember/Screens/Home/HomeRootView.swift")
        #expect(Quellpfad.relativ("/Users/tim/Documents/fitness-app/.claude/worktrees/x/apps/ios-member/FitnessMember/A.swift")
                == "apps/ios-member/FitnessMember/A.swift")
        #expect(Quellpfad.relativ("/irgendwo/anders/B.swift") == "B.swift")
    }
}
#endif
