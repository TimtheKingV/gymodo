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

    /// Leer statt Absturz, falls die Ressource fehlt: der Waechtertest meldet das dann klar.
    static let fixture: Fixture? = {
        guard let url = Bundle(for: Marker.self).url(forResource: "plan-ablauf", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Fixture.self, from: data)
    }()

    static var statusFaelle: [StatusFall] { fixture?.statusFaelle ?? [] }
    static var folgeFaelle: [FolgeFall] { fixture?.folgeFaelle ?? [] }
    static var zaehlFaelle: [ZaehlFall] { fixture?.zaehlFaelle ?? [] }

    @Test func fixtureIstImBundleUndHatMindestensSoVieleFaelleWieDerTypeScriptTest() {
        #expect(Self.fixture != nil, "plan-ablauf.json fehlt im Test-Bundle oder ist nicht dekodierbar")
        #expect(Self.statusFaelle.count >= 12)
        #expect(Self.folgeFaelle.count >= 6)
        #expect(Self.zaehlFaelle.count >= 3)
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
}
