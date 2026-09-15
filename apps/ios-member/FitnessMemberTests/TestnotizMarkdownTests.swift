#if DEBUG
import Foundation
import Testing
@testable import FitnessMember

struct TestnotizMarkdownTests {
    private let berlin = TimeZone(identifier: "Europe/Berlin")!

    private func markdown() throws -> String {
        TestnotizMarkdown.rendern(try TestnotizEintragTests.beispielSitzung(), zeitzone: berlin)
    }

    @Test func kopfzeileNenntVersionBuildModellUndSystem() throws {
        let erste = try markdown().split(separator: "\n").first.map(String.init)
        #expect(erste == "# Testsitzung 2026-09-13 14:12 — gymodo Member 1.0 (42), iPhone14,4, iOS 26.6.1")
    }

    @Test func jeEintragEineUeberschriftMitNummerZeitArtUndScreen() throws {
        let md = try markdown()
        #expect(md.contains("## 1 · 14:13 · Ausschnitt · GeraetView"))
        #expect(md.contains("## 2 · 14:15 · Element · UebungWechselnSheet"))
    }

    @Test func screenZeileTraegtDateiUndSortiertenKontext() throws {
        #expect(try markdown().contains("**Screen:** `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift` (exerciseId e_456, machineId m_123, phase eingabe)"))
    }

    @Test func ebenenNurWennEsMehrAlsEineGibt() throws {
        let md = try markdown()
        #expect(md.contains("**Ebenen:** GeraetView → UebungWechselnSheet"))
        #expect(md.components(separatedBy: "**Ebenen:**").count == 2)
    }

    @Test func elementZeileMitKennungLabelTypUndFundstelle() throws {
        #expect(try markdown().contains("**Element:** `geraet.satz-sichern` — „Satz 2 sichern, 42,5 Kilogramm“, Button, `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift:212`"))
    }

    @Test func ausschnittVorVollbild() throws {
        let md = try markdown()
        let ausschnitt = try #require(md.range(of: "![Ausschnitt](01-ausschnitt.png)"))
        let vollbild = try #require(md.range(of: "![Vollbild](01-voll.png)"))
        #expect(ausschnitt.lowerBound < vollbild.lowerBound)
    }

    @Test func protokollImDetailsBlockNurWennEsZeilenGibt() throws {
        let md = try markdown()
        #expect(md.contains("<details><summary>Protokoll (letzte 5 min, 1 Zeile)</summary>\n\n14:13:02 info tag — Tab-Wechsel auf Training wegen offenem Tag-Eingang\n\n</details>"))
        #expect(md.components(separatedBy: "<details>").count == 2)
    }

    @Test func gesprochenMitTranskriptUndAudio() throws {
        #expect(try markdown().contains("**Gesprochen:** Das Gewicht wird abgeschnitten wenn hundert komma fünf drinsteht ([Audio](01-notiz.m4a))"))
    }

    @Test func transkriptFehltAberAudioLiegtBei() throws {
        var sitzung = try TestnotizEintragTests.beispielSitzung()
        sitzung.entries[0].transcript = nil
        let md = TestnotizMarkdown.rendern(sitzung, zeitzone: berlin)
        #expect(md.contains("**Gesprochen:** Transkript fehlt, Audio liegt bei: [01-notiz.m4a](01-notiz.m4a)"))
    }

    @Test func ohneScreenSagtEsDas() throws {
        var sitzung = try TestnotizEintragTests.beispielSitzung()
        sitzung.entries[0].screen = nil
        let md = TestnotizMarkdown.rendern(sitzung, zeitzone: berlin)
        #expect(md.contains("## 1 · 14:13 · Ausschnitt · unbekannter Screen"))
        #expect(md.contains("**Screen:** unbekannt — kein Screen hat sich gemeldet"))
    }
}
#endif
