import XCTest
@testable import Koerperbild

/// Die Skelette der Katalogvideos liegen im Repo (data/koerperbild/skelette),
/// erzeugt mit `skelette-rechnen`. Der Test liest den aktuellen Stand.
final class SkelettDateienTests: XCTestCase {
    /// .../apps/ios-member/Packages/Koerperbild/Tests/KoerperbildTests/SkelettDateienTests.swift -> Repo-Wurzel
    private let wurzel: String = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // KoerperbildTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // Koerperbild
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // ios-member
        .deletingLastPathComponent() // apps
        .deletingLastPathComponent() // Repo
        .path

    func testFuerJedesKatalogvideoGibtEsEineLesbareSkelettdatei() throws {
        let videos = try FileManager.default.contentsOfDirectory(atPath: wurzel + "/catalog/media/videos").filter { $0.hasSuffix(".mp4") }
        XCTAssertGreaterThan(videos.count, 180)
        for v in videos {
            let pfad = wurzel + "/data/koerperbild/skelette/" + v.replacingOccurrences(of: ".mp4", with: ".skelett.json")
            let folge = try Skelettfolge(daten: Data(contentsOf: URL(fileURLWithPath: pfad)))
            XCTAssertGreaterThan(folge.bilder.count, 20, v); XCTAssertGreaterThan(folge.bildrate, 0, v)
        }
    }
}
