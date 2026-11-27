import XCTest
@testable import Koerperbild

/// Spielt die vorgerechneten Skelette der Uebungsvideos aus dem Flow "HIIT 20 Minuten" durch den
/// `FlowZaehler`: Start bei t = 0, das Video laeuft in Schleife, bis 40 s erreicht sind.
/// Erwartet sind die Wiederholungen im Loop mal die Durchlaeufe, Toleranz unter 1 je Durchlauf.
/// Eine Uebung steht genau dann in `data/koerperbild/flow-zuordnung.json`, wenn sie so zaehlt;
/// durchgefallene Uebungen laufen im Flow mit der Uhr (Bericht: docs/flows/hiit-20-min-kamera-bericht.md).
final class FlowZaehlerAbspielTests: XCTestCase {
    private let wurzel: String = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // KoerperbildTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // Koerperbild
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // ios-member
        .deletingLastPathComponent() // apps
        .deletingLastPathComponent() // Repo
        .path

    /// Laenge der Arbeitsphase, ueber die gezaehlt wird.
    private static let arbeitsphase: TimeInterval = 40

    struct Fall {
        let key: String
        let profil: Kameraprofil
        let signal: Gelenkwinkel
        let beginntMit: Tempophase
        /// Aus dem Video bestimmt: Umkehrpunkte des Signalwinkels und Sichtpruefung der Einzelbilder.
        let wiederholungenImLoop: Int
    }

    /// Profile wie in der Planvorgabe, Seite beide, Tempo 1 / 0 / 1.
    static let faelle: [Fall] = [
        Fall(key: "bw_jumping_jack", profil: .oberkoerper, signal: .schulter, beginntMit: .heben, wiederholungenImLoop: 1),
        Fall(key: "bw_squat_floor_touch", profil: .ganzkoerperStehend, signal: .knie, beginntMit: .senken, wiederholungenImLoop: 1),
        Fall(key: "bw_squat_pulse", profil: .ganzkoerperStehend, signal: .knie, beginntMit: .senken, wiederholungenImLoop: 1),
        Fall(key: "bw_burpee_slow", profil: .ganzkoerperStehend, signal: .huefte, beginntMit: .senken, wiederholungenImLoop: 1),
        Fall(key: "bw_burpee_jump", profil: .ganzkoerperStehend, signal: .huefte, beginntMit: .senken, wiederholungenImLoop: 1),
        Fall(key: "bw_pushup", profil: .stuetzBoden, signal: .ellbogen, beginntMit: .senken, wiederholungenImLoop: 1),
        // Flow vereinfacht (27.11.2026): Profil, Signal und Beginn aus data/koerperbild/zuordnung.json.
        // bw_lunge_kick und bw_leg_drop_pull sind nicht mehr im Flow (ihr letzter Stand steht im Bericht);
        Fall(key: "bw_back_extension_floor", profil: .liegend, signal: .huefte, beginntMit: .heben, wiederholungenImLoop: 1),
        Fall(key: "bw_reverse_lunge", profil: .ganzkoerperStehend, signal: .knie, beginntMit: .senken, wiederholungenImLoop: 1),
        Fall(key: "bw_leg_raise_lying", profil: .liegend, signal: .huefte, beginntMit: .heben, wiederholungenImLoop: 1),
        // Videos von Tim am 27.11.2026 abgenommen. bw_v_up steht in zuordnung.json ohne Kamera und ohne
        // Signal; geprueft wird mit den Werten des Beinhebens (liegend / huefte, beginnt mit heben wie dort).
        // bw_squat_jump hat keinen Eintrag dort; Werte wie bw_squat_floor_touch.
        Fall(key: "bw_v_up", profil: .liegend, signal: .huefte, beginntMit: .heben, wiederholungenImLoop: 1),
        Fall(key: "bw_squat_jump", profil: .ganzkoerperStehend, signal: .knie, beginntMit: .senken, wiederholungenImLoop: 1),
    ]

    struct Ergebnis {
        let gezaehlt: Int
        let erwartet: Int
        let durchlaeufe: Int
        /// Anteil der Bilder ab Start, in denen `FlowZaehler.erkannt` true war.
        let erkanntAnteil: Double
        /// Anteil der Videobilder, in denen ueberhaupt ein Skelett erkannt wurde.
        let skelettAnteil: Double
        /// Toleranz 1 je Durchlauf, die Grenze selbst ausgenommen: Bei einer Wiederholung im Loop
        /// liesse die eingeschlossene Grenze sonst 0 und die doppelte Zahl als richtig durchgehen.
        var bestanden: Bool { abs(gezaehlt - erwartet) < durchlaeufe }
    }

    private func spiele(_ fall: Fall) throws -> Ergebnis {
        let folge = try Skelettfolge(daten: Data(contentsOf: URL(
            fileURLWithPath: wurzel + "/data/koerperbild/skelette/\(fall.key).skelett.json")))
        let vorgabe = try XCTUnwrap(Kameravorgabe(profil: fall.profil, signal: fall.signal, seite: .beide))
        let tempo = Uebungstempo(senken: 1, halten: 0, heben: 1, beginntMit: fall.beginntMit)
        var z = FlowZaehler(vorgabe: vorgabe, tempo: tempo)
        // Zeit aus der Bildnummer, nicht aufsummiert: sonst laeuft ein Video von genau 8 s
        // wegen Rundung einen sechsten Durchlauf.
        var bilder = 0
        var erkannt = 0
        var durchlaeufe = 0
        z.start(t: 0)
        while Double(bilder) / folge.bildrate < Self.arbeitsphase {
            for bild in folge.bilder {
                z.bild(t: Double(bilder) / folge.bildrate, skelett: bild)
                bilder += 1
                if z.erkannt { erkannt += 1 }
            }
            durchlaeufe += 1
        }
        let mitSkelett = folge.bilder.filter { $0 != nil }.count
        return Ergebnis(gezaehlt: z.wiederholungen, erwartet: fall.wiederholungenImLoop * durchlaeufe,
                        durchlaeufe: durchlaeufe, erkanntAnteil: Double(erkannt) / Double(bilder),
                        skelettAnteil: Double(mitSkelett) / Double(folge.bilder.count))
    }

    private func flowZuordnung() throws -> [String: [String: Any]] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: URL(
            fileURLWithPath: wurzel + "/data/koerperbild/flow-zuordnung.json"))) as? [String: [String: Any]])
    }

    func testFlowZuordnungEnthaeltGenauDieUebungenDieRichtigZaehlen() throws {
        let zuordnung = try flowZuordnung()
        XCTAssertEqual(Set(zuordnung.keys).subtracting(Self.faelle.map(\.key)), [], "Eintrag ohne Pruefung gegen das Video")
        for fall in Self.faelle {
            let e = try spiele(fall)
            print(String(format: "FlowZaehlerAbspiel %@ gezaehlt %d erwartet %d (%d Durchlaeufe) erkannt %.1f %% Skelett %.1f %% %@",
                         fall.key, e.gezaehlt, e.erwartet, e.durchlaeufe, e.erkanntAnteil * 100, e.skelettAnteil * 100,
                         e.bestanden ? "bestanden" : "durchgefallen"))
            XCTAssertEqual(zuordnung[fall.key] != nil, e.bestanden,
                           "\(fall.key): gezaehlt \(e.gezaehlt), erwartet \(e.erwartet), Abweichung unter \(e.durchlaeufe) noetig")
        }
    }

    /// Die verbliebenen Eintraege tragen die Werte, mit denen hier gezaehlt wurde.
    func testEintraegeStimmenMitDerVorgabeUeberein() throws {
        let zuordnung = try flowZuordnung()
        for fall in Self.faelle {
            guard let eintrag = zuordnung[fall.key] else { continue }
            let kamera = try XCTUnwrap(eintrag["kamera"] as? [String: Any], fall.key)
            XCTAssertEqual(kamera["profil"] as? String, fall.profil.rawValue, fall.key)
            XCTAssertEqual(kamera["signal"] as? String, fall.signal.rawValue, fall.key)
            XCTAssertEqual(kamera["seite"] as? String, "beide", fall.key)
            XCTAssertEqual(kamera["beginnt_mit"] as? String, fall.beginntMit.rawValue, fall.key)
            let tempo = try XCTUnwrap(eintrag["tempo"] as? [String: Double], fall.key)
            XCTAssertEqual(tempo, ["senken_s": 1, "halten_s": 0, "heben_s": 1], fall.key)
        }
    }
}
