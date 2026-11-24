import XCTest
@testable import Koerperbild

/// Stufe 1 der Guete: laesst die Zaehl-Logik (`Koerperlage`) ueber die vorgerechneten
/// Skelette aller Uebungsvideos laufen und schreibt je Kameraprofil einen Bericht nach
/// data/koerperbild/profilbericht.md. Der Test schlaegt nur fehl, wenn Dateien fehlen oder
/// nicht lesbar sind oder ein Profil gar kein Video hat; das Urteil trifft der Bericht.
final class ProfilBerichtTests: XCTestCase {
    private let wurzel: String = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // KoerperbildTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // Koerperbild
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // ios-member
        .deletingLastPathComponent() // apps
        .deletingLastPathComponent() // Repo
        .path

    private struct Eintrag: Decodable {
        struct Kamera: Decodable { let profil: String; let signal: String?; let seite: String }
        let kamera: Kamera
    }

    private struct Videoergebnis {
        let key: String
        let signal: String
        let gezaehlt: Int
        let pflichtAnteil: Double
        let seite: Koerperseite
        let hub: Double?
        var richtig: Bool { gezaehlt == 5 || gezaehlt == 6 }
    }

    private static let sechsmal = 6
    private static let mindestAnteilRichtig = 0.9
    private static let mindestPflichtMedian = 0.95

    func testBerichtUeberAlleUebungsvideos() throws {
        let zuordnung = try JSONDecoder().decode(
            [String: Eintrag].self,
            from: Data(contentsOf: URL(fileURLWithPath: wurzel + "/data/koerperbild/zuordnung.json")))
        var ergebnisse: [Kameraprofil: [Videoergebnis]] = [:]
        var ohneVideo: [String] = []

        for key in zuordnung.keys.sorted() {
            let k = zuordnung[key]!.kamera
            guard let profil = Kameraprofil(rawValue: k.profil), profil != .ohneKamera else { continue }
            let pfad = wurzel + "/data/koerperbild/skelette/\(key).skelett.json"
            guard FileManager.default.fileExists(atPath: pfad) else { ohneVideo.append(key); continue }
            let folge = try Skelettfolge(daten: Data(contentsOf: URL(fileURLWithPath: pfad)))
            let signal = try XCTUnwrap(k.signal.flatMap { Gelenkwinkel(rawValue: $0) }, key)
            let seite = try XCTUnwrap(Seitenwahl(rawValue: k.seite), key)
            let vorgabe = try XCTUnwrap(Kameravorgabe(profil: profil, signal: signal, seite: seite), key)
            ergebnisse[profil, default: []].append(Self.auswerten(key: key, vorgabe: vorgabe, signal: k.signal ?? "", folge: folge))
        }

        let bericht = Self.bericht(ergebnisse: ergebnisse, ohneVideo: ohneVideo)
        let ziel = URL(fileURLWithPath: wurzel + "/data/koerperbild/profilbericht.md")
        try Data(bericht.utf8).write(to: ziel, options: .atomic)

        let verwendet = Set(zuordnung.values.compactMap { Kameraprofil(rawValue: $0.kamera.profil) }).subtracting([.ohneKamera])
        XCTAssertFalse(verwendet.isEmpty)
        for profil in verwendet.sorted(by: { $0.rawValue < $1.rawValue }) {
            XCTAssertFalse((ergebnisse[profil] ?? []).isEmpty, "Profil \(profil.rawValue) hat kein Video mit Skelett-Datei")
            XCTAssertTrue(bericht.contains("| \(profil.rawValue) |"), "Bericht ohne Zeile fuer \(profil.rawValue)")
        }
    }

    // MARK: Auswertung eines Videos

    private static func auswerten(key: String, vorgabe: Kameravorgabe, signal: String, folge: Skelettfolge) -> Videoergebnis {
        var lage = Koerperlage(vorgabe: vorgabe, gemerkterHub: nil)
        let n = folge.bilder.count
        let rate = folge.bildrate
        // 1 s Ruhe mit dem ersten erkannten Bild, dann los bei t = 1,0.
        if let erstes = folge.bilder.compactMap({ $0 }).first {
            let schritte = max(1, Int((rate).rounded()))
            for j in 0..<schritte {
                _ = lage.verarbeite(t: Double(j) / Double(schritte), skelett: erstes)
            }
        }
        lage.los(t: 1.0)
        for d in 0..<sechsmal {
            for i in 0..<n {
                _ = lage.verarbeite(t: 1.0 + Double(d * n + i) / rate, skelett: folge.bilder[i])
            }
        }
        let seite = lage.fuehrendeSeite ?? .links
        let pflicht = vorgabe.pflichtgelenke(seite)
        let vollstaendig = folge.bilder.filter { bild in
            guard let bild else { return false }
            return pflicht.allSatisfy { bild.sicher($0) != nil }
        }.count
        return Videoergebnis(key: key, signal: signal, gezaehlt: lage.wiederholungen.count,
                             pflichtAnteil: n == 0 ? 0 : Double(vollstaendig) / Double(n), seite: seite, hub: lage.hubGrad)
    }

    // MARK: Bericht

    private static func prozent(_ x: Double) -> String { String(format: "%.1f %%", 100 * x) }

    private static func median(_ werte: [Double]) -> Double {
        let s = werte.sorted()
        guard !s.isEmpty else { return 0 }
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }

    private static func bericht(ergebnisse: [Kameraprofil: [Videoergebnis]], ohneVideo: [String]) -> String {
        var z: [String] = []
        z.append("# Profilbericht Stufe 1 (Kamera)")
        z.append("")
        z.append("Erzeugt von ProfilBerichtTests aus data/koerperbild/skelette und data/koerperbild/zuordnung.json.")
        z.append("")
        z.append("Jedes Video wird sechsmal hintereinander abgespielt (1 s Ruhe mit dem ersten Bild davor, dann `los`), ohne gemerkten Hub. Richtig gezaehlt: 5 oder 6 Wiederholungen. Pflichtgelenk-Anteil: Anteil der Bilder, in denen alle Pflichtgelenke der fuehrenden Seite sicher sind (fuehrende Seite am Ende des Laufs, ohne Zaehlung links). Bestanden: mindestens 90 % richtig und Median des Pflichtgelenk-Anteils mindestens 95 %.")
        z.append("")
        z.append("| Profil | Videos | richtig gezaehlt | Anteil | Median Pflichtgelenke | Stufe 1 bestanden |")
        z.append("|---|---|---|---|---|---|")
        let profile = ergebnisse.keys.sorted { $0.rawValue < $1.rawValue }
        for p in profile {
            let v = ergebnisse[p]!
            let richtig = v.filter(\.richtig).count
            let anteil = Double(richtig) / Double(v.count)
            let med = median(v.map(\.pflichtAnteil))
            let ok = anteil >= mindestAnteilRichtig && med >= mindestPflichtMedian
            z.append("| \(p.rawValue) | \(v.count) | \(richtig) | \(prozent(anteil)) | \(prozent(med)) | \(ok ? "ja" : "nein") |")
        }
        for p in profile {
            let falsch = ergebnisse[p]!.filter { !$0.richtig }.sorted { $0.key < $1.key }
            z.append("")
            z.append("## \(p.rawValue): nicht richtig gezaehlt (\(falsch.count))")
            z.append("")
            if falsch.isEmpty { z.append("keine"); continue }
            z.append("| Video | Signal | gezaehlt / erwartet | Pflichtgelenke | fuehrende Seite | Hub |")
            z.append("|---|---|---|---|---|---|")
            for v in falsch {
                let hub = v.hub.map { String(format: "%.1f Grad", $0) } ?? "unbekannt"
                z.append("| \(v.key) | \(v.signal) | \(v.gezaehlt) / 5 oder 6 | \(prozent(v.pflichtAnteil)) | \(v.seite == .links ? "links" : "rechts") | \(hub) |")
            }
        }
        z.append("")
        z.append("## Ohne Video")
        z.append("")
        if ohneVideo.isEmpty { z.append("keine") } else { for k in ohneVideo.sorted() { z.append("- \(k)") } }
        z.append("")
        return z.joined(separator: "\n")
    }
}
