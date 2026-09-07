import Foundation
import Testing
@testable import FitnessMember

@Suite("TagLink")
struct TagLinkTests {
    @Test("akzeptiert einen gueltigen Tag-Link")
    func acceptsValidLink() {
        let url = URL(string: "https://\(TagLink.host)/t/abcdefghij0123456789AB")!
        #expect(TagLink.token(from: url) == "abcdefghij0123456789AB")
    }

    @Test("weist eine fremde Domain zurueck")
    func rejectsForeignHost() {
        let url = URL(string: "https://boese.example/t/abcdefghij0123456789AB")!
        #expect(TagLink.token(from: url) == nil)
    }

    @Test("weist http zurueck")
    func rejectsHttp() {
        let url = URL(string: "http://\(TagLink.host)/t/abcdefghij0123456789AB")!
        #expect(TagLink.token(from: url) == nil)
    }

    @Test("weist einen falschen Pfad zurueck")
    func rejectsWrongPath() {
        let url = URL(string: "https://\(TagLink.host)/x/abcdefghij0123456789AB")!
        #expect(TagLink.token(from: url) == nil)
    }

    @Test("weist einen zu kurzen Token zurueck")
    func rejectsShortToken() {
        let url = URL(string: "https://\(TagLink.host)/t/kurz")!
        #expect(TagLink.token(from: url) == nil)
    }

    @Test("weist unerlaubte Zeichen zurueck")
    func rejectsIllegalCharacters() {
        let url = URL(string: "https://\(TagLink.host)/t/abcdefghij0123456789A%2F")!
        #expect(TagLink.token(from: url) == nil)
    }

    @Test("weist zusaetzliche Pfadsegmente zurueck")
    func rejectsExtraSegments() {
        let url = URL(string: "https://\(TagLink.host)/t/abcdefghij0123456789AB/extra")!
        #expect(TagLink.token(from: url) == nil)
    }
}
