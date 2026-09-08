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

/// Der QR-Pfad liefert den vollen Link, NFC liefert bereits eine URL --
/// token(fromScan:) ist der eine Ort, der beides auf denselben blanken
/// Token bringt (Review-Fund: die QR-Seite hashte bislang den ganzen Link
/// und traf nie einen tokenHash).
@Suite("TagLink.token(fromScan:)")
struct TagLinkTokenFromScanTests {
    @Test("extrahiert den Token aus einem vollstaendigen Link")
    func extractsFromFullLink() {
        let link = "https://\(TagLink.host)/t/abcdefghij0123456789AB"
        #expect(TagLink.token(fromScan: link) == "abcdefghij0123456789AB")
    }

    @Test("laesst einen blanken Token unveraendert durch")
    func passesThroughBareToken() {
        #expect(TagLink.token(fromScan: "abcdefghij0123456789AB") == "abcdefghij0123456789AB")
    }

    @Test("gibt bei weder Link noch Token die Eingabe unveraendert zurueck")
    func passesThroughGarbage() {
        #expect(TagLink.token(fromScan: "wirklich-unsinn") == "wirklich-unsinn")
    }
}
