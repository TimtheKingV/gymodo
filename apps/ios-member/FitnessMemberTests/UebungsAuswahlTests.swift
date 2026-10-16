import Foundation
import Testing
@testable import FitnessMember

struct UebungsAuswahlTests {
    /// Eine Station aus JSON -- `BootstrapResponse.Machine` hat keinen Memberwise-Init.
    /// `uebungen`: (id, name, [(muskel, rolle)]).
    private func station(id: String, modell: String, status: String = "active",
                         uebungen: [(String, String, [(String, String)])]) throws -> Station {
        let uebungenJSON = uebungen.map { u in
            let muskeln = u.2.map { "{ \"key\": \"\($0.0)\", \"name\": \"\($0.0)\", \"role\": \"\($0.1)\" }" }
                .joined(separator: ", ")
            return """
            { "id": "\(u.0)", "name": "\(u.1)", "volumeKind": "reps", "targetMin": 8, "targetMax": 12,
              "muscles": [\(muskeln)] }
            """
        }.joined(separator: ", ")
        let json = """
        { "id": "\(id)", "studioId": "s1", "label": "Gerät \(id)", "locationNote": null,
          "status": "\(status)", "tokenHashes": ["h"], "visitCount": 0,
          "equipmentModel": { "id": "em-\(modell)", "name": "\(modell)", "manufacturer": null,
            "category": "kraft", "photoPath": null, "loadUnit": "kg", "loadStep": 2.5,
            "loadMin": 5, "loadMax": 100, "settingDefinitions": [] },
          "exercises": [\(uebungenJSON)] }
        """
        let maschine = try JSONDecoder().decode(BootstrapResponse.Machine.self, from: Data(json.utf8))
        return Station(maschine: maschine)
    }

    private let brust: [(String, String)] = [("pectorals", "primary")]
    private let arm: [(String, String)] = [("biceps", "primary")]

    @Test func eineUebungAnMehrerenGeraetenErscheintEinmalMitAllenGeraeten() throws {
        let a = try station(id: "a", modell: "Kabel A", uebungen: [("curl", "Curl", arm)])
        let b = try station(id: "b", modell: "Kabel B", uebungen: [("curl", "Curl", arm), ("bank", "Bank", brust)])
        let eintraege = UebungsAuswahl.eintraege(stationen: [a, b])
        #expect(eintraege.map(\.uebung.id) == ["curl", "bank"])
        #expect(eintraege[0].stationen.map(\.schluessel) == [a.schluessel, b.schluessel])
        #expect(eintraege[0].geraeteText == "Kabel A · Kabel B")
        #expect(eintraege[1].geraeteText == "Kabel B")
    }

    @Test func gleichesModellStehtImGeraeteTextNureinmal() throws {
        let a = try station(id: "a", modell: "Beinpresse", uebungen: [("p", "Presse", [])])
        let b = try station(id: "b", modell: "Beinpresse", uebungen: [("p", "Presse", [])])
        #expect(UebungsAuswahl.eintraege(stationen: [a, b])[0].geraeteText == "Beinpresse")
    }

    @Test func gesperrteGeraeteZaehlenNicht() throws {
        let aktiv = try station(id: "a", modell: "A", uebungen: [("curl", "Curl", arm)])
        let gesperrt = try station(id: "b", modell: "B", status: "retired",
                                   uebungen: [("curl", "Curl", arm), ("bank", "Bank", brust)])
        let eintraege = UebungsAuswahl.eintraege(stationen: [aktiv, gesperrt])
        #expect(eintraege.map(\.uebung.id) == ["curl"])
        #expect(eintraege[0].stationen.count == 1)
    }

    @Test func dieUebungTraegtIhreMuskeln() throws {
        let a = try station(id: "a", modell: "A", uebungen: [("bank", "Bank", brust)])
        #expect(UebungsAuswahl.eintraege(stationen: [a])[0].uebung.muscles.map(\.key) == ["pectorals"])
    }

    @Test func zuletztReihenfolgeNimmtDieGeraeteUebergreifendenEinheiten() throws {
        let a = try station(id: "a", modell: "A", uebungen: [("x", "X", []), ("y", "Y", []), ("z", "Z", [])])
        let eintraege = UebungsAuswahl.eintraege(stationen: [a])
        let heute: [String: Date] = ["z": Date(timeIntervalSince1970: 100)]
        let sortiert = UebungsAuswahl.zuletzt(eintraege, heute: heute, einheiten: ["y": 4, "x": 1])
        #expect(sortiert.map(\.uebung.id) == ["z", "y", "x"])
    }

    @Test func einGeraetGehtDirekt() throws {
        let a = try station(id: "a", modell: "A", uebungen: [("curl", "Curl", arm)])
        let eintrag = UebungsAuswahl.eintraege(stationen: [a])[0]
        #expect(UebungsAuswahl.ziel(fuer: eintrag, einheiten: [:]) == .direkt(a))
    }

    @Test func mehrereGeraeteOhneHistorieFragen() throws {
        let a = try station(id: "a", modell: "A", uebungen: [("curl", "Curl", arm)])
        let b = try station(id: "b", modell: "B", uebungen: [("curl", "Curl", arm)])
        let eintrag = UebungsAuswahl.eintraege(stationen: [a, b])[0]
        #expect(UebungsAuswahl.ziel(fuer: eintrag, einheiten: [:]) == .fragen([a, b]))
        #expect(UebungsAuswahl.ziel(fuer: eintrag, einheiten: [a.schluessel: 0, b.schluessel: 0]) == .fragen([a, b]))
    }

    @Test func mehrereGeraeteMitHistorieNehmenDasBekannteMitDenMeistenEinheiten() throws {
        let a = try station(id: "a", modell: "A", uebungen: [("curl", "Curl", arm)])
        let b = try station(id: "b", modell: "B", uebungen: [("curl", "Curl", arm)])
        let eintrag = UebungsAuswahl.eintraege(stationen: [a, b])[0]
        #expect(UebungsAuswahl.ziel(fuer: eintrag, einheiten: [a.schluessel: 1, b.schluessel: 3]) == .direkt(b))
        #expect(UebungsAuswahl.ziel(fuer: eintrag, einheiten: [a.schluessel: 2]) == .direkt(a))
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

struct AuswahlmodusEinstellungTests {
    @Test func vorgabeIstUebungenUndDerSchluesselBleibt() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        #expect(Einstellungen.auswahlmodusKey == "auswahlmodus")
        #expect(Einstellungen.auswahlmodus(defaults) == .uebungen)
    }

    @Test func gespeicherteWahlGiltUnbekanntesFaelltZurueck() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("geraete", forKey: Einstellungen.auswahlmodusKey)
        #expect(Einstellungen.auswahlmodus(defaults) == .geraete)
        defaults.set("x", forKey: Einstellungen.auswahlmodusKey)
        #expect(Einstellungen.auswahlmodus(defaults) == .uebungen)
    }
}
