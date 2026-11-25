import Foundation
import Testing
import Koerperbild
@testable import FitnessMember

@Suite("Uebung: Kameraprofil und Tempo")
struct UebungKameraTests {
    private func dekodiere(_ json: String) throws -> BootstrapResponse.Exercise {
        try JSONDecoder().decode(BootstrapResponse.Exercise.self, from: Data(json.utf8))
    }

    @Test func alterServerOhneFelder() throws {
        let u = try dekodiere(#"{"id":"e1","name":"Curl","volumeKind":"reps","targetMin":8,"targetMax":12}"#)
        #expect(u.kamera == nil)
        #expect(u.kameravorgabe == nil)
        #expect(u.uebungstempo == nil)
    }

    @Test func kniebeugeMitTempo() throws {
        let u = try dekodiere(#"{"id":"e1","name":"Kniebeuge","volumeKind":"reps","targetMin":8,"targetMax":12,"kamera":{"profil":"ganzkoerper_stehend","signal":"knie","seite":"beide","beginntMit":"senken"},"tempo":{"senkenS":3,"haltenS":1,"hebenS":2}}"#)
        #expect(u.kameravorgabe == Kameravorgabe(profil: .ganzkoerperStehend, signal: .knie, seite: .beide))
        #expect(u.uebungstempo == Uebungstempo(senken: 3, halten: 1, heben: 2, beginntMit: .senken))
    }

    @Test func ohneTempoGiltDerStandard() throws {
        let u = try dekodiere(#"{"id":"e1","name":"Curl","volumeKind":"reps","targetMin":8,"targetMax":12,"kamera":{"profil":"ohne_kamera","signal":null,"seite":null,"beginntMit":"heben"}}"#)
        #expect(u.kameravorgabe?.profil == .ohneKamera)
        #expect(u.kameravorgabe?.seite == .beide)
        #expect(u.uebungstempo == .standard(beginntMit: .heben))
    }

    @Test func unbekanntesProfilVomNeuerenServer() throws {
        let u = try dekodiere(#"{"id":"e1","name":"X","volumeKind":"reps","targetMin":8,"targetMax":12,"kamera":{"profil":"kopfstand","signal":"knie","seite":"beide","beginntMit":"heben"}}"#)
        #expect(u.kameravorgabe == nil)
        #expect(u.uebungstempo == nil)
    }

    @Test func kaputtesKameraObjektLaesstDieUebungLeben() throws {
        let u = try dekodiere(#"{"id":"e1","name":"X","volumeKind":"reps","targetMin":8,"targetMax":12,"kamera":{"profil":7}}"#)
        #expect(u.name == "X")
        #expect(u.kamera == nil)
    }

    @Test func sekundenUebungHatNieEineVorgabe() throws {
        let u = try dekodiere(#"{"id":"e1","name":"Plank","volumeKind":"seconds","targetMin":30,"targetMax":60,"kamera":{"profil":"ohne_kamera","signal":null,"seite":null,"beginntMit":"heben"}}"#)
        #expect(u.kameravorgabe == nil)
    }

    @Test func kameraprofilOhneSignalGiltNicht() throws {
        let u = try dekodiere(#"{"id":"e1","name":"X","volumeKind":"reps","targetMin":8,"targetMax":12,"kamera":{"profil":"oberkoerper","signal":null,"seite":"links","beginntMit":"heben"}}"#)
        #expect(u.kameravorgabe == nil)
    }

    @Test func unbekanntesBeginntMitSturztNicht() throws {
        let u = try dekodiere(#"{"id":"e1","name":"X","volumeKind":"reps","targetMin":8,"targetMax":12,"kamera":{"profil":"ohne_kamera","signal":null,"seite":null,"beginntMit":"halten"}}"#)
        #expect(u.kameravorgabe == nil)
        #expect(u.uebungstempo == nil)
    }
}
