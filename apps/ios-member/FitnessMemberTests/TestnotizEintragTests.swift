#if DEBUG
import Foundation
import Testing
@testable import FitnessMember

struct TestnotizEintragTests {
    private final class Marker {}

    static func beispiel() throws -> Data {
        let url = try #require(Bundle(for: Marker.self).url(forResource: "testnotiz-beispiel", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    static func beispielSitzung() throws -> TestnotizSitzung {
        try JSONDecoder.testnotiz().decode(TestnotizSitzung.self, from: beispiel())
    }

    @Test func liestDieBeispieldateiVollstaendig() throws {
        let sitzung = try Self.beispielSitzung()
        #expect(sitzung.format == "gymodo.testnotiz/1")
        #expect(sitzung.session.device.screen.scale == 3)
        #expect(sitzung.entries.count == 2)

        let erster = sitzung.entries[0]
        #expect(erster.kind == .crop)
        #expect(erster.screen?.file == "apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift")
        #expect(erster.screen?.context["phase"] == "eingabe")
        #expect(erster.cropRect?.pixels.width == 1005)
        #expect(erster.element == nil)

        let zweiter = sitzung.entries[1]
        #expect(zweiter.element?.source == .accessibility)
        #expect(zweiter.element?.line == 212)
        #expect(zweiter.crop == nil)
        #expect(zweiter.runtime.studioId == nil)
    }

    // Ein Feld, das der Encoder weglaesst, kostete einen Leser den Schluessel,
    // den er voraussetzt. Deshalb steht null drin -- auf jeder Ebene.
    @Test func schreibtNullStattWegzulassen() throws {
        let text = String(decoding: try JSONEncoder.testnotiz().encode(Self.beispielSitzung()), as: UTF8.self)
        #expect(text.contains("\"element\" : null"))
        #expect(text.contains("\"audio\" : null"))
        #expect(text.contains("\"studioId\" : null"))

        var ohneKennung = try #require(try Self.beispielSitzung().entries[1].element)
        ohneKennung.identifier = nil
        ohneKennung.file = nil
        ohneKennung.line = nil
        let element = String(decoding: try JSONEncoder.testnotiz().encode(ohneKennung), as: UTF8.self)
        #expect(element.contains("\"identifier\" : null"))
        #expect(element.contains("\"line\" : null"))
    }

    @Test func schreibtZeitpunkteMitOffset() throws {
        let berlin = try #require(TimeZone(identifier: "Europe/Berlin"))
        let text = String(decoding: try JSONEncoder.testnotiz(zeitzone: berlin).encode(Self.beispielSitzung()), as: UTF8.self)
        #expect(text.contains("\"startedAt\" : \"2026-09-13T14:12:03+02:00\""))
    }

    @Test func rundreiseVerliertNichts() throws {
        let a = try Self.beispielSitzung()
        let b = try JSONDecoder.testnotiz().decode(TestnotizSitzung.self, from: JSONEncoder.testnotiz().encode(a))
        #expect(a == b)
    }
}
#endif
