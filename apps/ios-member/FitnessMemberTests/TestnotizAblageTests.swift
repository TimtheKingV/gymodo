#if DEBUG
import Foundation
import Testing
@testable import FitnessMember

struct TestnotizAblageTests {
    private let berlin = TimeZone(identifier: "Europe/Berlin")!

    private func frischeWurzel() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("testnotiz-tests-\(UUID().uuidString)")
    }

    private func kopf() throws -> TestnotizSitzung.Kopf {
        var k = try TestnotizEintragTests.beispielSitzung().session
        k.id = ""
        return k
    }

    private func eintrag() throws -> TestnotizEintrag {
        var e = try TestnotizEintragTests.beispielSitzung().entries[1]
        e.index = 0
        e.screenshot = ""
        return e
    }

    @Test func ordnernameIstMinutengenauInDerZeitzone() throws {
        let kopf = try kopf()
        #expect(Zeitformat.ordnername(kopf.startedAt, zeitzone: berlin) == "2026-09-13-1412")
    }

    @Test func legtDenOrdnerMitLeererSitzungAn() async throws {
        let wurzel = frischeWurzel()
        let ablage = try TestnotizAblage(wurzel: wurzel, kopf: kopf(), zeitzone: berlin)
        #expect(ablage.ordner.lastPathComponent == "2026-09-13-1412")
        let json = try Data(contentsOf: ablage.ordner.appendingPathComponent("sitzung.json"))
        let gelesen = try JSONDecoder.testnotiz().decode(TestnotizSitzung.self, from: json)
        #expect(gelesen.session.id == "2026-09-13-1412")
        #expect(gelesen.entries.isEmpty)
        #expect(FileManager.default.fileExists(atPath: ablage.ordner.appendingPathComponent("sitzung.md").path))
    }

    @Test func zweiteSitzungInDerselbenMinuteBekommtEinSuffix() throws {
        let wurzel = frischeWurzel()
        _ = try TestnotizAblage(wurzel: wurzel, kopf: kopf(), zeitzone: berlin)
        let zweite = try TestnotizAblage(wurzel: wurzel, kopf: kopf(), zeitzone: berlin)
        #expect(zweite.ordner.lastPathComponent == "2026-09-13-1412-2")
    }

    @Test func nummeriertEintraegeUndBenenntDateien() async throws {
        let ablage = try TestnotizAblage(wurzel: frischeWurzel(), kopf: kopf(), zeitzone: berlin)
        let erster = try await ablage.schreiben(eintrag(), voll: Data([1]), ausschnitt: Data([2]), audio: nil)
        let zweiter = try await ablage.schreiben(eintrag(), voll: Data([3]), ausschnitt: nil, audio: nil)

        #expect(erster.index == 1)
        #expect(erster.screenshot == "01-voll.png")
        #expect(erster.crop == "01-ausschnitt.png")
        #expect(zweiter.index == 2)
        #expect(zweiter.screenshot == "02-voll.png")
        #expect(zweiter.crop == nil)

        let fm = FileManager.default
        #expect(fm.fileExists(atPath: ablage.ordner.appendingPathComponent("01-ausschnitt.png").path))
        #expect(fm.fileExists(atPath: ablage.ordner.appendingPathComponent("02-voll.png").path))
        #expect(await ablage.anzahl == 2)
    }

    @Test func schreibtJsonUndMarkdownNachJedemEintrag() async throws {
        let ablage = try TestnotizAblage(wurzel: frischeWurzel(), kopf: kopf(), zeitzone: berlin)
        _ = try await ablage.schreiben(eintrag(), voll: Data([1]), ausschnitt: nil, audio: nil)

        let json = try Data(contentsOf: ablage.ordner.appendingPathComponent("sitzung.json"))
        let gelesen = try JSONDecoder.testnotiz().decode(TestnotizSitzung.self, from: json)
        #expect(gelesen == (await ablage.sitzung))
        let md = try String(contentsOf: ablage.ordner.appendingPathComponent("sitzung.md"), encoding: .utf8)
        #expect(md.contains("## 1 · 14:15 · Element"))
    }

    @Test func verschiebtDasAudioInDenOrdner() async throws {
        let quelle = FileManager.default.temporaryDirectory.appendingPathComponent("aufnahme-\(UUID().uuidString).m4a")
        try Data([9, 9]).write(to: quelle)
        let ablage = try TestnotizAblage(wurzel: frischeWurzel(), kopf: kopf(), zeitzone: berlin)
        let gesichert = try await ablage.schreiben(eintrag(), voll: Data([1]), ausschnitt: nil, audio: quelle)

        #expect(gesichert.audio == "01-notiz.m4a")
        #expect(!FileManager.default.fileExists(atPath: quelle.path))
        #expect(FileManager.default.fileExists(atPath: ablage.ordner.appendingPathComponent("01-notiz.m4a").path))
    }

    @Test func transkriptWirdNachgetragen() async throws {
        let ablage = try TestnotizAblage(wurzel: frischeWurzel(), kopf: kopf(), zeitzone: berlin)
        let gesichert = try await ablage.schreiben(eintrag(), voll: Data([1]), ausschnitt: nil, audio: nil)
        try await ablage.transkriptNachtragen(index: gesichert.index, text: "hallo")

        let json = try Data(contentsOf: ablage.ordner.appendingPathComponent("sitzung.json"))
        #expect(try JSONDecoder.testnotiz().decode(TestnotizSitzung.self, from: json).entries[0].transcript == "hallo")
    }

    @Test func zipIstEinZipArchiv() async throws {
        let ablage = try TestnotizAblage(wurzel: frischeWurzel(), kopf: kopf(), zeitzone: berlin)
        _ = try await ablage.schreiben(eintrag(), voll: Data([1]), ausschnitt: nil, audio: nil)
        let zip = try await ablage.zipFuerTeilen()
        #expect(zip.pathExtension == "zip")
        let kopfbytes = try Data(contentsOf: zip).prefix(2)
        #expect(Array(kopfbytes) == [0x50, 0x4B])
    }
}
#endif
