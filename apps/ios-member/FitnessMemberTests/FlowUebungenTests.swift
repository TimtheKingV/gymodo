import Foundation
import Koerperbild
import Testing
@testable import FitnessMember

@MainActor
struct FlowUebungenTests {
    private static let kamera = #","kamera":{"profil":"oberkoerper","signal":"ellbogen","seite":"beide","beginntMit":"senken"},"tempo":{"senkenS":1,"haltenS":0,"hebenS":1}"#
    private static let ohneKameraProfil = #","kamera":{"profil":"ohne_kamera","signal":null,"seite":"beide","beginntMit":"senken"},"tempo":{"senkenS":1,"haltenS":0,"hebenS":1}"#

    private static func uebung(id: String, name: String, extra: String = "") -> String {
        #"{"id":"\#(id)","name":"\#(name)","volumeKind":"reps","targetMin":8,"targetMax":12\#(extra)}"#
    }

    /// Maschine m1 mit `maschinenUebungen`, Katalog-Typ mit `katalogUebungen` (JSON-Objekte).
    private static func bootstrap(maschinenUebungen: [String], katalogUebungen: [String]) -> BootstrapResponse {
        let maschine = """
        {"id":"m1","studioId":"s1","label":"Gerät 7","locationNote":null,"status":"active","tokenHashes":[],"visitCount":0,
         "equipmentModel":{"id":"em1","name":"Kurzhantel","manufacturer":null,"category":"kraft","photoPath":null,
           "loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,"settingDefinitions":[]},
         "exercises":[\(maschinenUebungen.joined(separator: ","))]}
        """
        let typ = """
        {"id":"em2","name":"Eigengewicht","manufacturer":null,"photoPath":null,"category":"kraft","loadUnit":"kg",
         "loadStep":1,"loadMin":0,"loadMax":null,"settingDefinitions":[],
         "exercises":[\(katalogUebungen.joined(separator: ","))]}
        """
        return GeraetTestdaten.dekodiere("""
        {"member":{"displayName":null,"goals":{"weeklyDays":null,"targetWeight":null}},
         "studios":[{"id":"s1","name":"Keller-Gym","timezone":"Europe/Berlin"}],
         "machines":[\(maschine)],"calibrations":[],"lastSets":[],
         "catalog":{"studioId":"s1","equipmentTypes":[\(typ)]}}
        """)
    }

    private static func schritt(_ exerciseId: String?) -> FlowSchritt {
        FlowSchritt(position: 1, name: "Schritt", beschreibung: nil, workS: 40, restS: 20, istWarmup: false,
                    exerciseId: exerciseId)
    }

    private static func flow(_ schritte: [FlowSchritt]) -> Flow {
        Flow(id: "f1", studioId: "s1", key: "k", titel: "T", beschreibung: nil, level: nil,
             schritte: schritte, dauerS: 60)
    }

    private static let standard = FlowUebungen(
        bootstrap: bootstrap(
            maschinenUebungen: [uebung(id: "m-ex", name: "Maschinenzug")],
            katalogUebungen: [uebung(id: "k-ex", name: "Katalogkniebeuge"),
                              uebung(id: "k-cam", name: "Katalogcurl", extra: kamera),
                              uebung(id: "k-aus", name: "Katalogplank", extra: ohneKameraProfil)]),
        testprofile: false)

    @Test func uebungAusKatalogUndMaschine() {
        #expect(Self.standard.uebung(Self.schritt("k-ex"))?.name == "Katalogkniebeuge")
        #expect(Self.standard.uebung(Self.schritt("m-ex"))?.name == "Maschinenzug")
    }

    @Test func unbekannteIdUndFehlenderBootstrapGebenNil() {
        #expect(Self.standard.uebung(Self.schritt("gibt-es-nicht")) == nil)
        #expect(Self.standard.uebung(Self.schritt(nil)) == nil)
        let leer = FlowUebungen(bootstrap: nil, testprofile: false)
        #expect(leer.uebung(Self.schritt("k-ex")) == nil)
        #expect(leer.ansicht(Self.schritt("k-ex"), mitKamera: true) == .ring)
    }

    @Test func ohneVerweisOderUnbekanntIstRing() {
        #expect(Self.standard.ansicht(Self.schritt(nil), mitKamera: true) == .ring)
        #expect(Self.standard.ansicht(Self.schritt("gibt-es-nicht"), mitKamera: true) == .ring)
    }

    @Test func ohneKameraangabenIstVideo() {
        #expect(Self.standard.ansicht(Self.schritt("k-ex"), mitKamera: true) == .video(exerciseId: "k-ex"))
        #expect(Self.standard.ansicht(Self.schritt("m-ex"), mitKamera: false) == .video(exerciseId: "m-ex"))
    }

    @Test func mitKameraangabenUndKameraIstKamera() {
        guard case .kamera(let start) = Self.standard.ansicht(Self.schritt("k-cam"), mitKamera: true) else {
            Issue.record("erwartet .kamera"); return
        }
        #expect(start.exerciseId == "k-cam")
        #expect(start.sollWiederholungen == nil)
        #expect(start.satzZiel == 1)
    }

    @Test func mitKameraangabenAberOhneKameraIstVideo() {
        #expect(Self.standard.ansicht(Self.schritt("k-cam"), mitKamera: false) == .video(exerciseId: "k-cam"))
    }

    @Test func profilOhneKameraIstVideo() {
        #expect(Self.standard.ansicht(Self.schritt("k-aus"), mitKamera: true) == .video(exerciseId: "k-aus"))
    }

    @Test func hatKameraSchrittNurMitKameraUebung() {
        #expect(Self.standard.hatKameraSchritt(Self.flow([Self.schritt(nil), Self.schritt("k-ex"), Self.schritt("k-cam")])))
        #expect(!Self.standard.hatKameraSchritt(Self.flow([Self.schritt(nil), Self.schritt("k-ex"), Self.schritt("k-aus")])))
        #expect(!Self.standard.hatKameraSchritt(Self.flow([])))
    }

    #if DEBUG
    @Test func testprofileErgaenzenKameraangabenNurWennAn() {
        let bootstrap = Self.bootstrap(maschinenUebungen: [],
                                       katalogUebungen: [Self.uebung(id: "dips", name: "Dips")])
        let an = FlowUebungen(bootstrap: bootstrap, testprofile: true)
        let aus = FlowUebungen(bootstrap: bootstrap, testprofile: false)
        if case .kamera = an.ansicht(Self.schritt("dips"), mitKamera: true) {} else { Issue.record("erwartet .kamera") }
        #expect(aus.ansicht(Self.schritt("dips"), mitKamera: true) == .video(exerciseId: "dips"))
    }
    #endif

    @Test func blickzeileJeProfil() {
        let seitlich = "Stell dich seitlich zur Kamera"
        #expect(Kameraprofil.ganzkoerperStehend.blickzeile == seitlich)
        #expect(Kameraprofil.stuetzBoden.blickzeile == seitlich)
        #expect(Kameraprofil.liegend.blickzeile == seitlich)
        #expect(Kameraprofil.oberkoerper.blickzeile == "Schau zur Kamera")
        #expect(Kameraprofil.zugHaengend.blickzeile == "Schau zur Kamera")
        #expect(Kameraprofil.ohneKamera.blickzeile == nil)
    }
}
