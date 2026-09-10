import Foundation
import Testing
@testable import FitnessMember

/// Liste und Suche fuer Geraete ohne Aufkleber.
///
/// Diese Suite haelt die Regeln fest, die im Entwurf nur als Bild
/// existieren: die Entdopplung zwischen den Gruppen und die Reihenfolge
/// der Treffer. Beide waeren sonst beim naechsten Anfassen weg.
struct GeraeteAuswahlTests {

    // MARK: - Bausteine

    private func zeit(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)!
    }

    /// BootstrapResponse ist Decodable ohne Memberwise-Init: der einzige
    /// Weg, eine zu bauen, fuehrt ueber JSON. Deshalb baut dieser Helfer
    /// den Maschinen-JSON als Text, statt einen Wert zu erzeugen.
    private func maschineJSON(
        id: String, name: String, label: String, ort: String?,
        studio: String = "s1", status: String = "active",
        tags: [String] = ["hash"], besuche: Int = 0,
        uebungen: [(String, String)] = [("u1", "Latzug breit")]
    ) -> String {
        let ortJSON = ort.map { "\"\($0)\"" } ?? "null"
        let tagsJSON = tags.map { "\"\($0)\"" }.joined(separator: ", ")
        let uebungenJSON = uebungen.map {
            """
            { "id": "\($0.0)", "name": "\($0.1)", "targetRepsMin": 8, "targetRepsMax": 12 }
            """
        }.joined(separator: ", ")
        return """
        {
          "id": "\(id)", "studioId": "\(studio)", "label": "\(label)",
          "locationNote": \(ortJSON), "status": "\(status)",
          "tokenHashes": [\(tagsJSON)], "visitCount": \(besuche),
          "equipmentModel": {
            "id": "em-\(id)", "name": "\(name)", "manufacturer": "Technogym",
            "photoPath": null, "weightStepKg": 2.5, "minWeightKg": 5,
            "maxWeightKg": 100, "settingDefinitions": []
          },
          "exercises": [\(uebungenJSON)]
        }
        """
    }

    private func bootstrap(
        maschinen: [String],
        saetze: [(machine: String, uebung: String, kg: Double, wann: String)] = []
    ) -> BootstrapResponse {
        let saetzeJSON = saetze.map {
            """
            { "machineId": "\($0.machine)", "exerciseId": "\($0.uebung)",
              "weightKg": \($0.kg), "reps": 10, "rir": null,
              "performedAt": "\($0.wann)" }
            """
        }.joined(separator: ", ")
        return GeraetTestdaten.dekodiere("""
        {
          "member": { "displayName": "Tim" },
          "studios": [
            { "id": "s1", "name": "Gym Ost", "timezone": "Europe/Berlin" },
            { "id": "s2", "name": "Gym West", "timezone": "Europe/Berlin" }
          ],
          "machines": [\(maschinen.joined(separator: ", "))],
          "calibrations": [],
          "lastSets": [\(saetzeJSON)]
        }
        """)
    }

    // MARK: - Zwei Gruppen ohne Suchtext

    /// Der Kern der Gruppierung: benutzte Geraete oben, alles andere
    /// darunter -- und was oben steht, steht unten NICHT noch einmal.
    /// Ohne diese Regel an einem Ort baut sie jemand spaeter andersherum.
    @Test func benutzteGeraeteStehenObenUndNichtNochmalUnten() {
        let daten = bootstrap(
            maschinen: [
                maschineJSON(id: "m1", name: "Latzug", label: "14", ort: "Rueckwand", besuche: 3),
                maschineJSON(id: "m2", name: "Bauchtrainer", label: "21", ort: "Freiflaeche"),
            ],
            saetze: [(machine: "m1", uebung: "u1", kg: 45, wann: "2026-09-07T10:00:00Z")])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "")

        #expect(gruppen.zuletzt.map(\.machineId) == ["m1"])
        #expect(gruppen.alle.map(\.machineId) == ["m2"])
    }

    /// Mehr als drei, und die Gruppe verdraengt die Liste, die sie
    /// abkuerzen soll.
    @Test func hoechstensDreiStehenUnterZuletzt() {
        let daten = bootstrap(
            maschinen: (1...5).map {
                maschineJSON(id: "m\($0)", name: "Geraet \($0)", label: "\($0)", ort: nil, besuche: 1)
            },
            saetze: (1...5).map {
                (machine: "m\($0)", uebung: "u1", kg: 40, wann: "2026-09-0\($0)T10:00:00Z")
            })

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "")

        #expect(gruppen.zuletzt.count == 3)
        #expect(gruppen.alle.count == 2)
    }

    @Test func zuletztIstNachJuengstemSatzSortiert() {
        let daten = bootstrap(
            maschinen: [
                maschineJSON(id: "alt", name: "Alt", label: "1", ort: nil, besuche: 1),
                maschineJSON(id: "neu", name: "Neu", label: "2", ort: nil, besuche: 1),
            ],
            saetze: [
                (machine: "alt", uebung: "u1", kg: 40, wann: "2026-09-01T10:00:00Z"),
                (machine: "neu", uebung: "u1", kg: 50, wann: "2026-09-09T10:00:00Z"),
            ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "")

        #expect(gruppen.zuletzt.map(\.machineId) == ["neu", "alt"])
        #expect(gruppen.zuletzt.first?.zuletzt?.gewichtKg == 50)
    }

    @Test func alleSindAlphabetischNachGeraetenamen() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Rudern sitzend", label: "9", ort: nil),
            maschineJSON(id: "m2", name: "Bauchtrainer", label: "21", ort: nil),
            maschineJSON(id: "m3", name: "Latzug", label: "14", ort: nil),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "")

        #expect(gruppen.alle.map(\.name) == ["Bauchtrainer", "Latzug", "Rudern sitzend"])
    }

    /// Sichtbar, aber ans Ende. Auszublenden hiesse, das Mitglied sucht am
    /// Geraet weiter, statt zu wissen, dass es gesperrt ist.
    @Test func gesperrteGeraeteStehenAmEnde() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Aaa", label: "1", ort: nil, status: "maintenance"),
            maschineJSON(id: "m2", name: "Zzz", label: "2", ort: nil),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "")

        #expect(gruppen.alle.map(\.name) == ["Zzz", "Aaa"])
        #expect(gruppen.alle.last?.gesperrt == true)
    }

    /// Leere tokenHashes heissen "kein AKTIVER Tag" -- getBootstrap liest
    /// machine_tags mit status = active. Die Marke sagt deshalb, was die
    /// App weiss, nicht was am Geraet klebt.
    @Test func geraeteOhneAktivenTagSindMarkiert() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Beinbeuger", label: "5", ort: nil, tags: []),
            maschineJSON(id: "m2", name: "Latzug", label: "14", ort: nil),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "")

        #expect(gruppen.alle.first(where: { $0.name == "Beinbeuger" })?.nichtScannbar == true)
        #expect(gruppen.alle.first(where: { $0.name == "Latzug" })?.nichtScannbar == false)
    }

    @Test func dieOrtsangabeIstLabelUndPlatz() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Latzug", label: "Gerät 14", ort: "Rückwand rechts"),
            maschineJSON(id: "m2", name: "Bauchtrainer", label: "Gerät 21", ort: nil),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "")

        #expect(gruppen.alle[0].ortsangabe == "Gerät 21")
        #expect(gruppen.alle[1].ortsangabe == "Gerät 14 · Rückwand rechts")
    }

    @Test func geraeteFremderStudiosFehlen() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Latzug", label: "14", ort: nil),
            maschineJSON(id: "m2", name: "Fremd", label: "99", ort: nil, studio: "s2"),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "")

        #expect(gruppen.alle.map(\.name) == ["Latzug"])
    }

    // MARK: - Suche

    @Test func mitSuchtextGibtEsNurNochEineListe() {
        let daten = bootstrap(
            maschinen: [maschineJSON(id: "m1", name: "Latzug", label: "14", ort: nil, besuche: 1)],
            saetze: [(machine: "m1", uebung: "u1", kg: 45, wann: "2026-09-07T10:00:00Z")])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "lat")

        #expect(gruppen.zuletzt.isEmpty)
        #expect(gruppen.alle.map(\.name) == ["Latzug"])
    }

    /// Die Reihenfolge aus Blatt 03, die dort nur als Bild existierte:
    /// Geraetetreffer vor Uebungstreffern, darin Historie zuerst, dann
    /// alphabetisch. Ohne diesen Test sortiert der naechste nach Alphabet.
    @Test func trefferReihenfolgeGeraetVorUebungUndHistorieZuerst() {
        let daten = bootstrap(
            maschinen: [
                maschineJSON(id: "m1", name: "Beinbeuger", label: "5", ort: nil),
                maschineJSON(id: "m2", name: "Beinpresse", label: "3", ort: nil, besuche: 2),
                maschineJSON(id: "m3", name: "Bauchtrainer", label: "21", ort: nil,
                             uebungen: [("u9", "Beinheben hängend")]),
            ],
            saetze: [(machine: "m2", uebung: "u1", kg: 90, wann: "2026-09-07T10:00:00Z")])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "bein")

        #expect(gruppen.alle.map(\.name) == ["Beinpresse", "Beinbeuger", "Bauchtrainer"])
    }

    /// Gesperrt zaehlt auch bei einem Treffer mehr als jede andere Regel.
    /// "Aaa" traefe zweimal (Name UND Historie) und wuerde ohne die
    /// Sperr-Prioritaet vor "Aab" stehen -- die Sperr-Prioritaet in
    /// `trefferReihenfolge` ist eine eigene, von `alphabetischGesperrteAnsEnde`
    /// unabhaengige Zeile, die kein anderer Test durchlaeuft.
    @Test func gesperrteGeraeteStehenAuchBeiTrefferAmEnde() {
        let daten = bootstrap(
            maschinen: [
                maschineJSON(id: "m1", name: "Aaa", label: "1", ort: nil, status: "maintenance", besuche: 2),
                maschineJSON(id: "m2", name: "Aab", label: "2", ort: nil),
            ],
            saetze: [(machine: "m1", uebung: "u1", kg: 40, wann: "2026-09-07T10:00:00Z")])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "aa")

        #expect(gruppen.alle.map(\.name) == ["Aab", "Aaa"])
        #expect(gruppen.alle.last?.gesperrt == true)
    }

    /// Die Uebungszeile erklaert, warum ein Geraet in der Trefferliste
    /// steht, dessen Name nichts mit der Eingabe zu tun hat. Bei einem
    /// Geraetetreffer erklaert sie nichts und darf deshalb fehlen -- auch
    /// wenn das Geraet selbst noch eine passende Uebung im Programm hat.
    /// Die Beinpresse hier traefe auf BEIDEN Wegen ("bein" im Namen UND in
    /// "Beinstrecken"); nur so zeigt der Test, dass der Geraetetreffer den
    /// Uebungstreffer unterdrueckt, statt bloss zu bestaetigen, dass keine
    /// ihrer Uebungen zufaellig passt.
    @Test func dieUebungszeileStehtNurBeimReinenUebungstreffer() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Beinpresse", label: "3", ort: nil,
                         uebungen: [("u2", "Beinstrecken")]),
            maschineJSON(id: "m2", name: "Bauchtrainer", label: "21", ort: nil,
                         uebungen: [("u9", "Beinheben hängend")]),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "bein")

        #expect(gruppen.alle.first(where: { $0.name == "Beinpresse" })?.trefferUebung == nil)
        #expect(gruppen.alle.first(where: { $0.name == "Bauchtrainer" })?.trefferUebung == "Beinheben hängend")
    }

    @Test func gesuchtWirdAuchInNummerUndPlatz() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Latzug", label: "Gerät 14", ort: "Rückwand rechts"),
            maschineJSON(id: "m2", name: "Bauchtrainer", label: "Gerät 21", ort: "Freifläche"),
        ])

        let ueberNummer = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "14")
        let ueberPlatz = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "frei")

        #expect(ueberNummer.alle.map(\.name) == ["Latzug"])
        #expect(ueberPlatz.alle.map(\.name) == ["Bauchtrainer"])
    }

    @Test func grossschreibungUndUmlauteSindEgal() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Rückenstrecker", label: "22", ort: nil),
        ])

        for eingabe in ["RÜCKEN", "rucken", "Ruecken".replacingOccurrences(of: "ue", with: "ü")] {
            let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: eingabe)
            #expect(gruppen.alle.count == 1, "\(eingabe) sollte treffen")
        }
    }

    @Test func nurLeerraumGiltAlsKeineSuche() {
        let daten = bootstrap(
            maschinen: [maschineJSON(id: "m1", name: "Latzug", label: "14", ort: nil, besuche: 1)],
            saetze: [(machine: "m1", uebung: "u1", kg: 45, wann: "2026-09-07T10:00:00Z")])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "   ")

        #expect(gruppen.zuletzt.count == 1)
    }

    @Test func ohneTrefferSindBeideGruppenLeer() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Latzug", label: "14", ort: nil),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "beinpresse xr")

        #expect(gruppen.zuletzt.isEmpty)
        #expect(gruppen.alle.isEmpty)
    }
}
