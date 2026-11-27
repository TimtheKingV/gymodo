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

    /// Die Flow-Uebungen (data/koerperbild/flow-zuordnung.json) kommen unabhaengig
    /// vom Profil-Filter hinzu; die Eintraege aus dem Zuordnungsvorschlag bleiben.
    @Test func flowUebungenHabenEinTestprofil() {
        let liegestuetz = KameraTestprofile.eintraege["Liegestütz"]
        #expect(liegestuetz?.key == "bw_pushup")
        #expect(liegestuetz?.kamera.profil == "stuetz_boden")
        #expect(liegestuetz?.kamera.signal == "ellbogen")
        #expect(liegestuetz?.tempo.senkenS == 1)
        #expect(liegestuetz?.tempo.haltenS == 0)
        #expect(liegestuetz?.tempo.hebenS == 1)
        let jack = KameraTestprofile.eintraege["Jumping Jack"]
        #expect(jack?.key == "bw_jumping_jack")
        #expect(jack?.kamera.profil == "oberkoerper")
        #expect(jack?.kamera.signal == "schulter")
        #expect(jack?.kamera.beginntMit == "heben")
        #expect(KameraTestprofile.eintraege["Dips"]?.key == "assisted_dip")
        #expect(KameraTestprofile.eintraege["Bizepscurl"]?.key == "bb_curl")
    }

    /// Vier Katalogübungen heißen „Ausfallschritt – rückwärts“. Der Flow nutzt
    /// `bw_reverse_lunge` mit dem Flow-Tempo; das normale Training behält den
    /// ersten Eintrag nach Schlüssel (`bb_reverse_lunge`, 3 / 1 / 2).
    @Test func flowLoestGleichnamigeUebungAufIhrenFlowEintragAuf() {
        let flow = KameraTestprofile.ergaenzt(Self.uebung(name: "Ausfallschritt – rückwärts"),
                                              eingeschaltet: true, imFlow: true)
        #expect(flow.tempo == TempoDTO(senkenS: 1, haltenS: 0, hebenS: 1))
        #expect(KameraTestprofile.flowKatalogKey(name: "Ausfallschritt – rückwärts") == "bw_reverse_lunge")
        let normal = KameraTestprofile.ergaenzt(Self.uebung(name: "Ausfallschritt – rückwärts"), eingeschaltet: true)
        #expect(normal.tempo == TempoDTO(senkenS: 3, haltenS: 1, hebenS: 2))
        #expect(KameraTestprofile.katalogKey(name: "Ausfallschritt – rückwärts") == "bb_reverse_lunge")
    }

    /// Jede Übung aus data/koerperbild/flow-zuordnung.json löst im Flow auf ihren
    /// eigenen Schlüssel auf, auch wenn ihr Name im Katalog mehrfach vorkommt.
    @Test func jedeFlowZuordnungLoestAufIhrenSchluesselAuf() {
        let flow = KameraTestprofile.alle.filter { $0.flow == true }
        #expect(Set(flow.map(\.key)) == ["bw_back_extension_floor", "bw_jumping_jack", "bw_leg_raise_lying",
                                         "bw_pushup", "bw_reverse_lunge", "bw_squat_floor_touch",
                                         "bw_squat_jump", "bw_squat_pulse"])
        for eintrag in flow {
            #expect(KameraTestprofile.flowKatalogKey(name: eintrag.name) == eintrag.key, "\(eintrag.key)")
        }
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
