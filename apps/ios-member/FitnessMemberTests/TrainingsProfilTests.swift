import Foundation
import Testing
@testable import FitnessMember

struct TrainingsProfilTests {
    /// Eine Uebung je Name; die Muskeln stehen im Katalog (`muskelnJeUebung`).
    private func muskel(_ key: String, _ rolle: GeraetMuskel.Rolle = .primary) -> GeraetMuskel {
        GeraetMuskel(key: key, name: key, role: rolle)
    }

    private func satz(_ index: Int, cardio: CardioWerte? = nil) -> SessionSummary.Block.Set {
        SessionSummary.Block.Set(
            setIndex: index, load: 50, secondaryLoad: nil, volume: 10, rir: nil,
            problemFlag: false, problemReason: nil, performedAt: "2026-09-08T16:10:00Z",
            cardio: cardio)
    }

    private func block(_ uebung: String, saetze: Int, cardio: Bool = false) -> SessionSummary.Block {
        SessionSummary.Block(
            machineId: "m-\(uebung)", machineLabel: uebung, exerciseId: uebung,
            exerciseName: uebung, loadUnit: .kg, secondaryUnit: nil, volumeKind: .reps,
            sets: (0..<saetze).map { satz($0, cardio: cardio ? CardioWerte(zeit: 600) : nil) })
    }

    private func einheit(id: String = "s1", _ bloecke: [SessionSummary.Block]) -> SessionSummary {
        SessionSummary(
            id: id, startedAt: "2026-09-08T16:04:00Z", completedAt: "2026-09-08T16:51:00Z",
            completedReason: "manual", machineCount: bloecke.count,
            setCount: bloecke.reduce(0) { $0 + $1.sets.count }, blocks: bloecke)
    }

    private func profil(
        _ bloecke: [SessionSummary.Block], katalog: [String: [GeraetMuskel]]
    ) -> TrainingsProfil {
        TrainingsProfil.berechne(
            karte: Trainingskarte(teile: [einheit(bloecke)]), muskeln: katalog)
    }

    private func standardKatalog() -> [String: [GeraetMuskel]] {
        [
            "bankdruecken": [muskel("pectorals"), muskel("deltoid_anterior", .secondary), muskel("triceps", .secondary)],
            "fliegende": [muskel("pectorals")],
            "rudern": [muskel("lats"), muskel("upper_back"), muskel("biceps", .secondary)],
            "latziehen": [muskel("lats"), muskel("biceps", .secondary)],
            "bizepscurl": [muskel("biceps")],
            "trizepsdruecken": [muskel("triceps")],
            "schulterdruecken": [muskel("deltoid_anterior"), muskel("deltoid_lateral")],
            "beinpresse": [muskel("quads"), muskel("glutes")],
            "crunch": [muskel("abs")],
        ]
    }

    @Test func brustMitTrizepsAlsNebenmuskelHeisstBrustTrizeps() {
        let p = profil(
            [block("bankdruecken", saetze: 6), block("fliegende", saetze: 3), block("trizepsdruecken", saetze: 2)],
            katalog: standardKatalog())

        #expect(p.titel == "Brust, Trizeps")
    }

    @Test func rueckenMitBizepsUndBauchHeisstRueckenBizepsBauch() {
        let p = profil(
            [block("rudern", saetze: 6), block("latziehen", saetze: 4), block("bizepscurl", saetze: 2), block("crunch", saetze: 5)],
            katalog: standardKatalog())

        #expect(p.titel == "Rücken, Bizeps, Bauch")
    }

    @Test func ausgewogenerOberkoerperHeisstOberkoerper() {
        let p = profil(
            [block("bankdruecken", saetze: 4), block("rudern", saetze: 4), block("schulterdruecken", saetze: 4)],
            katalog: standardKatalog())

        #expect(p.titel == "Oberkörper")
    }

    @Test func beineUndOberkoerperHeissenGanzkoerper() {
        let p = profil(
            [block("beinpresse", saetze: 5), block("bankdruecken", saetze: 4), block("rudern", saetze: 4)],
            katalog: standardKatalog())

        #expect(p.titel == "Ganzkörper")
    }

    @Test func fastNurArmeHeissenArme() {
        let p = profil(
            [block("bizepscurl", saetze: 6), block("trizepsdruecken", saetze: 6), block("fliegende", saetze: 1)],
            katalog: standardKatalog())

        #expect(p.titel == "Arme")
    }

    @Test func einEinzelnerTrizepssatzKommtNichtInDenNamen() {
        let p = profil(
            [block("fliegende", saetze: 12), block("trizepsdruecken", saetze: 1)],
            katalog: standardKatalog())

        #expect(p.titel == "Brust")
    }

    @Test func nurBeineHeissenBeine() {
        let p = profil([block("beinpresse", saetze: 8)], katalog: standardKatalog())

        #expect(p.titel == "Beine")
    }

    @Test func nurCardioHeisstCardio() {
        let k: [String: [GeraetMuskel]] = ["laufband": [muskel("quads")]]
        let p = profil([block("laufband", saetze: 1, cardio: true)], katalog: k)

        #expect(p.titel == "Cardio")
        #expect(p.stufen.isEmpty)
    }

    @Test func ohneBekannteMuskelnHeisstEsTraining() {
        let p = profil([block("unbekannt", saetze: 4)], katalog: [:])

        #expect(p.titel == "Training")
        #expect(p.stufen.isEmpty)
    }

    @Test func derStaerksteMuskelIstStarkDerSchwacheSchwachDerUnbelasteteFehlt() {
        // Bankdruecken: Brust 6 Punkte (stark), Schulter vorn und Trizeps je 3 (50 % -> stark).
        // Fliegende ergaenzt nur Brust. Rudern 1 Satz: Lats 1 (schwach), upper_back 1 (schwach).
        let p = profil(
            [block("bankdruecken", saetze: 6), block("rudern", saetze: 1)],
            katalog: standardKatalog())

        #expect(p.stufen["pectorals"] == .stark)
        #expect(p.stufen["lats"] == .schwach)
        #expect(p.stufen["quads"] == nil)
    }

    @Test func einSekundaersatzAlleinZaehltNicht() {
        // Rudern mit 1 Satz: Bizeps nur Nebenmuskel und unter der Mindestzahl.
        let p = profil([block("rudern", saetze: 1)], katalog: standardKatalog())

        #expect(p.stufen["biceps"] == nil)
        #expect(p.stufen["lats"] == .stark)
    }

    @Test func eineZusammengefalteteKarteSummiertDieLastAllerTeile() {
        let karte = Trainingskarte(teile: [
            einheit(id: "a", [block("fliegende", saetze: 2)]),
            einheit(id: "b", [block("rudern", saetze: 2)]),
        ])
        let p = TrainingsProfil.berechne(karte: karte, muskeln: standardKatalog())

        #expect(p.stufen["pectorals"] == .stark)
        #expect(p.stufen["lats"] == .stark)
    }
}
