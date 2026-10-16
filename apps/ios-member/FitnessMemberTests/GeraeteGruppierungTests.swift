import Foundation
import Testing
@testable import FitnessMember

struct GeraeteGruppierungTests {
    /// Eine Station aus JSON -- `BootstrapResponse.Machine` hat keinen Memberwise-Init.
    /// `uebungen`: (id, [Hauptmuskel]).
    private func eintrag(_ id: String, uebungen: [(String, String)], zuletzt: Date? = nil) throws -> GeraeteAuswahl.Eintrag {
        let uebungenJSON = uebungen.map { u in
            """
            { "id": "\(u.0)", "name": "\(u.0)", "volumeKind": "reps", "targetMin": 8, "targetMax": 12,
              "muscles": [{ "key": "\(u.1)", "name": "\(u.1)", "role": "primary" }] }
            """
        }.joined(separator: ", ")
        let json = """
        { "id": "\(id)", "studioId": "s1", "label": "Gerät \(id)", "locationNote": null,
          "status": "active", "tokenHashes": ["h"], "visitCount": 0,
          "equipmentModel": { "id": "em-\(id)", "name": "\(id)", "manufacturer": null,
            "category": "kraft", "photoPath": null, "loadUnit": "kg", "loadStep": 2.5,
            "loadMin": 5, "loadMax": 100, "settingDefinitions": [] },
          "exercises": [\(uebungenJSON)] }
        """
        let station = Station(maschine: try JSONDecoder().decode(BootstrapResponse.Machine.self, from: Data(json.utf8)))
        return GeraeteAuswahl.Eintrag(
            station: station, modellId: "em-\(id)", name: id, gruppe: .geraete, ortsangabe: "",
            zuletzt: zuletzt.map { GeraeteAuswahl.Zuletzt(performedAt: $0, load: 10, loadUnit: .kg) },
            trefferUebung: nil, gesperrt: false, nichtScannbar: false)
    }

    @Test func einGeraetMitEinerGruppeStehtDort() throws {
        let presse = try eintrag("presse", uebungen: [("p", "pectorals")])
        #expect(GeraeteGruppierung.heimat(von: presse.station) == .brust)
    }

    @Test func mehrereHauptgruppenMachenEsVielseitig() throws {
        let kabel = try eintrag("kabel", uebungen: [("a", "pectorals"), ("b", "lats"), ("c", "abs")])
        #expect(GeraeteGruppierung.heimat(von: kabel.station) == .vielseitig)
        #expect(GeraeteGruppierung.gruppen(von: kabel.station) == [.brust, .ruecken, .rumpf])
    }

    @Test func zweiUebungenDerselbenGruppeBleibenInDerGruppe() throws {
        let latzug = try eintrag("latzug", uebungen: [("a", "lats"), ("b", "upper_back")])
        #expect(GeraeteGruppierung.heimat(von: latzug.station) == .ruecken)
    }

    @Test func ohneMuskelnSteheEsUnterWeitere() throws {
        let band = try eintrag("laufband", uebungen: [("a", "deep_core")])
        #expect(GeraeteGruppierung.heimat(von: band.station) == .weitere)
    }

    @Test func alleZeigtJedesGeraetEinmalVielseitigZuletzt() throws {
        let brust = try eintrag("brust", uebungen: [("a", "pectorals")])
        let kabel = try eintrag("kabel", uebungen: [("a", "pectorals"), ("b", "abs")])
        let bauch = try eintrag("bauch", uebungen: [("a", "abs")])
        let abschnitte = GeraeteGruppierung.gruppieren([kabel, brust, bauch])
        #expect(abschnitte.map(\.gruppe) == [.brust, .rumpf, .vielseitig])
        #expect(abschnitte.flatMap(\.eintraege).map(\.name) == ["brust", "bauch", "kabel"])
    }

    @Test func einFilterZeigtAuchDieVielseitigenGeraeteDieDieGruppeBedienen() throws {
        let brust = try eintrag("brust", uebungen: [("a", "pectorals")])
        let kabel = try eintrag("kabel", uebungen: [("a", "pectorals"), ("b", "abs")])
        let bauch = try eintrag("bauch", uebungen: [("a", "abs")])
        let rumpf = GeraeteGruppierung.gruppieren([brust, kabel, bauch], nur: .rumpf)
        #expect(rumpf.count == 1)
        #expect(rumpf[0].eintraege.map(\.name) == ["kabel", "bauch"])
    }

    @Test func derFilterVielseitigZeigtNurDieVielseitigen() throws {
        let brust = try eintrag("brust", uebungen: [("a", "pectorals")])
        let kabel = try eintrag("kabel", uebungen: [("a", "pectorals"), ("b", "abs")])
        let abschnitte = GeraeteGruppierung.gruppieren([brust, kabel], nur: .vielseitig)
        #expect(abschnitte.flatMap(\.eintraege).map(\.name) == ["kabel"])
    }

    @Test func dieBulletsSindDieGruppenMitGeraeten() throws {
        let brust = try eintrag("brust", uebungen: [("a", "pectorals")])
        let kabel = try eintrag("kabel", uebungen: [("a", "pectorals"), ("b", "abs")])
        #expect(GeraeteGruppierung.vorhandeneGruppen([brust, kabel]) == [.brust, .rumpf, .vielseitig])
        #expect(GeraeteGruppierung.vorhandeneGruppen([]).isEmpty)
    }

    @Test func favoritenSindNurBenutzteDasJuengsteZuerst() throws {
        let alt = try eintrag("alt", uebungen: [("a", "abs")], zuletzt: Date(timeIntervalSince1970: 100))
        let neu = try eintrag("neu", uebungen: [("a", "abs")], zuletzt: Date(timeIntervalSince1970: 900))
        let nie = try eintrag("nie", uebungen: [("a", "abs")])
        #expect(GeraeteGruppierung.favoriten([alt, nie, neu]).map(\.name) == ["neu", "alt"])
    }
}

struct UebungsGruppierungFilterTests {
    private func uebung(_ id: String, _ muskel: String) -> GeraetUebung {
        GeraetUebung(id: id, name: id, volumeKind: .reps, targetMin: 8, targetMax: 12, videoURL: nil,
                     muscles: [GeraetMuskel(key: muskel, name: muskel, role: .primary)])
    }

    private var liste: [GeraetUebung] {
        [uebung("curl", "biceps"), uebung("bank", "pectorals"), uebung("fliege", "pectorals")]
    }

    @Test func derFilterBlendetAndereGruppenAus() {
        let gruppen = UebungsGruppierung.gruppieren(liste, nur: .brust)
        #expect(gruppen.map(\.gruppe) == [.brust])
        #expect(gruppen[0].uebungen.map(\.id) == ["bank", "fliege"])
    }

    @Test func keinFilterZeigtAlles() {
        #expect(UebungsGruppierung.gruppieren(liste, nur: nil).map(\.gruppe) == [.brust, .arme])
    }

    @Test func einFilterOhneTrefferZeigtNichts() {
        #expect(UebungsGruppierung.gruppieren(liste, nur: .beine).isEmpty)
    }

    @Test func vorhandeneGruppenSindDieMitUebungenInFesterReihenfolge() {
        #expect(UebungsGruppierung.vorhandeneGruppen(liste) == [.brust, .arme])
    }
}
