#if DEBUG
import Foundation
import Koerperbild
import Testing
@testable import FitnessMember

/// Die Testprofile gibt es nur im Debug-Build; der Schalter ist ein
/// UserDefaults-Wert, deshalb laufen die Tests nacheinander.
@MainActor
@Suite(.serialized)
struct KameraTestprofileTests {
    private static func uebung(name: String, kamera: String = "") -> BootstrapResponse.Exercise {
        GeraetTestdaten.dekodiere("""
        {"id":"u1","name":"\(name)","volumeKind":"reps","targetMin":8,"targetMax":12\(kamera)}
        """)
    }

    private static func mitSchalter(_ an: Bool, _ pruefung: () -> Void) {
        let vorher = KameraTestprofile.aktiv
        KameraTestprofile.aktiv = an
        defer { KameraTestprofile.aktiv = vorher }
        pruefung()
    }

    @Test func dateiLiegtImBundle() {
        #expect(KameraTestprofile.eintraege.values.contains { $0.key == "assisted_dip" })
        #expect(KameraTestprofile.katalogKey(name: "Dips") == "assisted_dip")
    }

    @Test func testprofilErgaenztBekannteUebung() {
        Self.mitSchalter(true) {
            let ergebnis = KameraTestprofile.ergaenzt(Self.uebung(name: "Dips"))
            #expect(ergebnis.kameravorgabe?.profil == .oberkoerper)
            #expect(ergebnis.uebungstempo != nil)
        }
    }

    @Test func ausgeschaltetBleibtAllesWieGeliefert() {
        Self.mitSchalter(false) {
            let ergebnis = KameraTestprofile.ergaenzt(Self.uebung(name: "Dips"))
            #expect(ergebnis.kamera == nil)
            #expect(ergebnis.tempo == nil)
        }
    }

    @Test func vorhandenesServerprofilGewinnt() {
        Self.mitSchalter(true) {
            let vom = #","kamera":{"profil":"liegend","signal":"ellbogen","seite":"beide","beginntMit":"senken"}"#
            let ergebnis = KameraTestprofile.ergaenzt(Self.uebung(name: "Dips", kamera: vom))
            #expect(ergebnis.kamera?.profil == "liegend")
            #expect(ergebnis.tempo == nil)
        }
    }

    @Test func unbekannterNameBleibtOhne() {
        Self.mitSchalter(true) {
            let ergebnis = KameraTestprofile.ergaenzt(Self.uebung(name: "Studio-Eigenbau"))
            #expect(ergebnis.kamera == nil)
            #expect(KameraTestprofile.katalogKey(name: "Studio-Eigenbau") == nil)
        }
    }
}
#endif
