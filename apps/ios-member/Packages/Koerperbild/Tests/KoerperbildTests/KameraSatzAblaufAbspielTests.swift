import XCTest
@testable import Koerperbild

/// Spielt aufgezeichnete Skelette der Katalogvideos durch den Ablauf und vergleicht die Zaehlung
/// mit dem Versuch vom 23.11. (`versuch-2026-11-23.csv`, Spalte `wege`: zwei Wege je Wiederholung).
final class KameraSatzAblaufAbspielTests: XCTestCase {
    private let wurzel: String = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // KoerperbildTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // Koerperbild
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // ios-member
        .deletingLastPathComponent() // apps
        .deletingLastPathComponent() // Repo
        .path

    /// Jedes Video zeigt eine Wiederholung; wie im Profilbericht laeuft es sechsmal hintereinander.
    private static let durchlaeufe = 6

    private func erwarteteWiederholungen(_ key: String) throws -> Int {
        let csv = try String(contentsOfFile: wurzel + "/data/koerperbild/versuch-2026-11-23.csv", encoding: .utf8)
        let zeile = try XCTUnwrap(csv.split(separator: "\n").first { $0.hasPrefix(key + ";") }, key)
        let felder = zeile.split(separator: ";", omittingEmptySubsequences: false)
        return try XCTUnwrap(Int(felder[7])) / 2   // Spalte "wege"
    }

    private func ablauf(fuer key: String) throws -> (KameraSatzAblauf, Skelettfolge) {
        let zuordnung = try XCTUnwrap(JSONSerialization.jsonObject(
            with: Data(contentsOf: URL(fileURLWithPath: wurzel + "/data/koerperbild/zuordnung.json"))) as? [String: [String: Any]])
        let eintrag = try XCTUnwrap(zuordnung[key])
        let kamera = try XCTUnwrap(eintrag["kamera"] as? [String: Any])
        let tempoWerte = try XCTUnwrap(eintrag["tempo"] as? [String: Double])
        let profil = try XCTUnwrap((kamera["profil"] as? String).flatMap(Kameraprofil.init(rawValue:)))
        let seite = try XCTUnwrap((kamera["seite"] as? String).flatMap(Seitenwahl.init(rawValue:)))
        let signal = (kamera["signal"] as? String).flatMap(Gelenkwinkel.init(rawValue:))
        let vorgabe = try XCTUnwrap(Kameravorgabe(profil: profil, signal: signal, seite: seite))
        let beginnt = try XCTUnwrap((kamera["beginnt_mit"] as? String).flatMap(Tempophase.init(rawValue:)))
        let tempo = Uebungstempo(senken: try XCTUnwrap(tempoWerte["senken_s"]), halten: try XCTUnwrap(tempoWerte["halten_s"]),
                                 heben: try XCTUnwrap(tempoWerte["heben_s"]), beginntMit: beginnt)
        let folge = try Skelettfolge(daten: Data(contentsOf: URL(fileURLWithPath: wurzel + "/data/koerperbild/skelette/\(key).skelett.json")))
        return (KameraSatzAblauf(vorgabe: vorgabe, tempo: tempo, gemerkterHub: nil, mitVideo: false), folge)
    }

    /// Das erste Bild steht still, bis der Countdown durch ist; dann laeuft die Aufnahme (sechs Durchlaeufe), danach `satzBeenden()`.
    private func spiele(_ key: String) throws -> (gezaehlt: Int, erwartet: Int) {
        var (a, folge) = try ablauf(fuer: key)
        let erstes = try XCTUnwrap(folge.bilder.compactMap { $0 }.first)
        let dt = 1 / folge.bildrate
        var t = 0.0
        while t < 15, a.schritt != .satz {
            a.bild(t: t, skelett: erstes)
            t += dt
        }
        XCTAssertEqual(a.schritt, .satz, key)
        for _ in 0..<Self.durchlaeufe {
            for bild in folge.bilder {
                a.bild(t: t, skelett: bild)
                t += dt
            }
        }
        a.satzBeenden()
        return (a.wiederholungen, try erwarteteWiederholungen(key))
    }

    /// bb_curl: oberkoerper, Signal Ellbogen, beide Seiten; Versuch: "zählt richtig", 11 Wege (5 Wiederholungen, 6 gespielt).
    func testKurzhantelCurlZaehltWieImVersuch() throws {
        let (gezaehlt, erwartet) = try spiele("bb_curl")
        XCTAssertGreaterThan(erwartet, 0)
        XCTAssertEqual(gezaehlt, erwartet, accuracy: 1)
    }

    /// bb_front_squat: ganzkoerper_stehend, Signal Knie; Versuch: "zählt richtig", 11 Wege (5 Wiederholungen, 6 gespielt).
    func testFrontKniebeugeZaehltWieImVersuch() throws {
        let (gezaehlt, erwartet) = try spiele("bb_front_squat")
        XCTAssertGreaterThan(erwartet, 0)
        XCTAssertEqual(gezaehlt, erwartet, accuracy: 1)
    }
}
