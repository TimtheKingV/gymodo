import Foundation
import Testing
@testable import FitnessMember

/// Dieselben Testfaelle wie der TypeScript-Test (packages/domain/fixtures/plan-ablauf.json,
/// Spec F17): Server und Geraet duerfen beim Ablaufstatus nie auseinanderlaufen.
struct TrainingsplanAblaufTests {
    private final class Marker {}

    struct Tausch: Decodable, Sendable {
        let positionKey: String
        let exerciseId: String
        let hauptmuskeln: [String]
    }

    /// Entweder satz oder tausch, wie in der Fixture.
    struct Schritt: Decodable, Sendable {
        let satz: AblaufSatz?
        let tausch: Tausch?
    }

    struct Erwartet: Decodable, Sendable, Equatable {
        let key: String
        let status: PositionStatus
        let ersatzExerciseId: String?
    }

    struct StatusFall: Decodable, Sendable, CustomTestStringConvertible {
        let name: String
        let positionen: [AblaufPosition]
        let ungeplanteGesehen: [String]
        let saetze: [AblaufSatz]
        let tausche: [Tausch]
        let schritte: [Schritt]?
        let erwartet: [Erwartet]
        let erwartetUngeplant: [String]?
        var testDescription: String { name }
    }

    struct FolgeFall: Decodable, Sendable, CustomTestStringConvertible {
        let name: String
        let einheitKeys: [String]
        let zuletzt: String?
        let erwartet: String
        var testDescription: String { name }
    }

    struct ZaehlFall: Decodable, Sendable, CustomTestStringConvertible {
        let name: String
        let stati: [PositionStatus]
        let erwartet: Bool
        var testDescription: String { name }
    }

    struct Fixture: Decodable, Sendable {
        let statusFaelle: [StatusFall]
        let folgeFaelle: [FolgeFall]
        let zaehlFaelle: [ZaehlFall]
    }

    /// Warum die Fixture nicht da ist -- mit dem Text des Dekodierfehlers, damit
    /// ein neues Pflichtfeld nicht wie eine fehlende Datei aussieht.
    enum FixtureFehler: Error, Sendable, CustomStringConvertible {
        case fehltImBundle
        case nichtLesbar(String)

        var description: String {
            switch self {
            case .fehltImBundle: "plan-ablauf.json fehlt im Test-Bundle"
            case .nichtLesbar(let grund): "plan-ablauf.json ist nicht dekodierbar: \(grund)"
            }
        }
    }

    /// Ein Result statt Absturz: die parametrisierten Tests bekommen dann
    /// leere Listen, und der Waechtertest meldet den Fehler selbst.
    static let fixture: Result<Fixture, FixtureFehler> = {
        guard let url = Bundle(for: Marker.self).url(forResource: "plan-ablauf", withExtension: "json") else {
            return .failure(.fehltImBundle)
        }
        do {
            let data = try Data(contentsOf: url)
            return .success(try JSONDecoder().decode(Fixture.self, from: data))
        } catch {
            return .failure(.nichtLesbar(String(describing: error)))
        }
    }()

    static var statusFaelle: [StatusFall] { (try? fixture.get())?.statusFaelle ?? [] }
    static var folgeFaelle: [FolgeFall] { (try? fixture.get())?.folgeFaelle ?? [] }
    static var zaehlFaelle: [ZaehlFall] { (try? fixture.get())?.zaehlFaelle ?? [] }

    /// Die Zahlen sind der Stand der Fixture (Etappe 3): weniger hiesse, Faelle
    /// fielen still weg. Die Sonderpfade (schritte statt erst Tausche, dann
    /// Saetze; erwartetUngeplant) muessen abgedeckt bleiben, sonst prueft der
    /// Test sie nicht mehr.
    @Test func fixtureIstImBundleUndHatMindestensSoVieleFaelleWieDerTypeScriptTest() throws {
        let f = try Self.fixture.get()
        #expect(f.statusFaelle.count >= 19)
        #expect(f.folgeFaelle.count >= 9)
        #expect(f.zaehlFaelle.count >= 3)
        #expect(f.statusFaelle.filter { $0.schritte != nil }.count >= 1, "kein statusFall mit schritte")
        #expect(f.statusFaelle.filter { $0.erwartetUngeplant != nil }.count >= 8, "zu wenige statusFaelle mit erwartetUngeplant")
    }

    @Test(arguments: statusFaelle)
    func statusFall(_ fall: StatusFall) {
        var z = AblaufZustand(positionen: fall.positionen, ungeplanteGesehen: fall.ungeplanteGesehen)
        // Ohne schritte: erst alle Tausche, dann alle Saetze (wie der TS-Test).
        let schritte = fall.schritte
            ?? fall.tausche.map { Schritt(satz: nil, tausch: $0) }
            + fall.saetze.map { Schritt(satz: $0, tausch: nil) }
        for schritt in schritte {
            if let t = schritt.tausch {
                z = TrainingsplanAblauf.tauschen(z, positionKey: t.positionKey, ersatz: (exerciseId: t.exerciseId, hauptmuskeln: t.hauptmuskeln))
            } else if let s = schritt.satz {
                z = TrainingsplanAblauf.nachSatz(z, s)
            }
        }
        if let erwartetUngeplant = fall.erwartetUngeplant {
            #expect(z.ungeplanteGesehen == erwartetUngeplant, "\(fall.name): ungeplanteGesehen")
        }
        let ist = z.positionen.map { Erwartet(key: $0.key, status: $0.status, ersatzExerciseId: $0.ersatzExerciseId) }
        #expect(ist == fall.erwartet, "\(fall.name)")
    }

    @Test(arguments: folgeFaelle)
    func folgeFall(_ fall: FolgeFall) {
        #expect(TrainingsplanFolge.naechsteEinheitKey(einheitKeys: fall.einheitKeys, zuletzt: fall.zuletzt) == fall.erwartet, "\(fall.name)")
    }

    @Test(arguments: zaehlFaelle)
    func zaehlFall(_ fall: ZaehlFall) {
        let positionen = fall.stati.enumerated().map { i, status in
            AblaufPosition(key: "p\(i)", exerciseId: "e\(i)", hauptmuskeln: [], cardio: false, status: status, ersatzExerciseId: nil)
        }
        let z = AblaufZustand(positionen: positionen, ungeplanteGesehen: [])
        #expect(TrainingsplanAblauf.zaehlt(z) == fall.erwartet, "\(fall.name)")
    }

    @Test func tauschtWederCardioNochGezaehltePositionen() {
        func mk(_ cardio: Bool, _ status: PositionStatus) -> AblaufPosition {
            AblaufPosition(key: "a", exerciseId: "x", hauptmuskeln: [], cardio: cardio, status: status, ersatzExerciseId: nil)
        }
        for p in [mk(true, .offen), mk(false, .erledigt), mk(false, .optional)] {
            let z = AblaufZustand(positionen: [p], ungeplanteGesehen: [])
            #expect(TrainingsplanAblauf.tauschen(z, positionKey: "a", ersatz: (exerciseId: "w", hauptmuskeln: [])) == z)
        }
    }

    // MARK: - Umordnen

    private static func pos(_ key: String, _ status: PositionStatus = .offen, ersatz: String? = nil) -> AblaufPosition {
        AblaufPosition(key: key, exerciseId: "x\(key)", hauptmuskeln: ["m"], cardio: false, status: status, ersatzExerciseId: ersatz)
    }

    @Test func umordnenVerschiebtNachVorn() {
        let z = AblaufZustand(positionen: [Self.pos("a"), Self.pos("b"), Self.pos("c")], ungeplanteGesehen: [])
        let neu = TrainingsplanAblauf.umordnen(z, positionKey: "c", nach: 0)
        #expect(neu.positionen.map(\.key) == ["c", "a", "b"])
        let nachHinten = TrainingsplanAblauf.umordnen(z, positionKey: "a", nach: 2)
        #expect(nachHinten.positionen.map(\.key) == ["b", "c", "a"])
    }

    @Test func umordnenErhaeltStatusUndErsatz() {
        let getauscht = Self.pos("b", .getauscht, ersatz: "y")
        let z = AblaufZustand(positionen: [Self.pos("a"), getauscht, Self.pos("c")], ungeplanteGesehen: ["u"])
        let neu = TrainingsplanAblauf.umordnen(z, positionKey: "b", nach: 2)
        #expect(neu.positionen.last == getauscht)
        #expect(neu.ungeplanteGesehen == ["u"])
    }

    @Test func umordnenKlemmtIndex() {
        let z = AblaufZustand(positionen: [Self.pos("a"), Self.pos("b"), Self.pos("c")], ungeplanteGesehen: [])
        #expect(TrainingsplanAblauf.umordnen(z, positionKey: "a", nach: 99).positionen.map(\.key) == ["b", "c", "a"])
        #expect(TrainingsplanAblauf.umordnen(z, positionKey: "c", nach: -5).positionen.map(\.key) == ["c", "a", "b"])
    }

    @Test func umordnenUnbekannterSchluesselIstNoop() {
        let z = AblaufZustand(positionen: [Self.pos("a"), Self.pos("b")], ungeplanteGesehen: [])
        #expect(TrainingsplanAblauf.umordnen(z, positionKey: "zzz", nach: 0) == z)
    }
}
