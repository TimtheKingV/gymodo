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
        kategorie: String = "kraft", einheit: String = "kg", gruppe: String? = nil,
        uebungen: [(String, String)] = [("u1", "Latzug breit")]
    ) -> String {
        let gruppeJSON = gruppe.map { ", \"equipmentGroup\": \"\($0)\"" } ?? ""
        let ortJSON = ort.map { "\"\($0)\"" } ?? "null"
        let tagsJSON = tags.map { "\"\($0)\"" }.joined(separator: ", ")
        let uebungenJSON = uebungen.map {
            """
            { "id": "\($0.0)", "name": "\($0.1)", "volumeKind":"reps","targetMin":8, "targetMax":12 }
            """
        }.joined(separator: ", ")
        return """
        {
          "id": "\(id)", "studioId": "\(studio)", "label": "\(label)",
          "locationNote": \(ortJSON), "status": "\(status)",
          "tokenHashes": [\(tagsJSON)], "visitCount": \(besuche),
          "equipmentModel": {
            "id": "em-\(id)", "name": "\(name)", "manufacturer": "Technogym",
            "category":"\(kategorie)","photoPath": null, "loadUnit":"\(einheit)","loadStep":2.5, "loadMin":5,
            "loadMax":100, "settingDefinitions": []\(gruppeJSON)
          },
          "exercises": [\(uebungenJSON)]
        }
        """
    }

    private func typJSON(id: String, name: String, kategorie: String = "kraft",
                         gruppe: String? = nil, abgeloest: Bool = false,
                         uebungen: [(String, String)] = [("gu1", "Gymtavo-Uebung")]) -> String {
        let gruppeJSON = gruppe.map { "\"equipmentGroup\": \"\($0)\", " } ?? ""
        let uebungenJSON = uebungen.map {
            """
            { "id": "\($0.0)", "name": "\($0.1)", "volumeKind":"reps","targetMin":8, "targetMax":12 }
            """
        }.joined(separator: ", ")
        return """
        { "id": "\(id)", "name": "\(name)", "manufacturer": "Gymtavo", "photoPath": null,
          "category": "\(kategorie)", "loadUnit": "kg", "loadStep": 2.5, "loadMin": 5,
          "loadMax": 100, \(gruppeJSON)"retired": \(abgeloest),
          "settingDefinitions": [], "exercises": [\(uebungenJSON)] }
        """
    }

    private func bootstrap(
        maschinen: [String],
        saetze: [(machine: String, uebung: String, kg: Double, wann: String)] = [],
        typen: [String] = [],
        typSaetze: [(modell: String, uebung: String, kg: Double, wann: String)] = [],
        cardioSatzJSON: String? = nil
    ) -> BootstrapResponse {
        let typSaetzeJSON = typSaetze.map {
            """
            { "equipmentModelId": "\($0.modell)", "exerciseId": "\($0.uebung)",
              "load":\($0.kg), "volume":10, "rir": null,
              "performedAt": "\($0.wann)" }
            """
        }.joined(separator: ", ")
        let katalogJSON = typen.isEmpty ? "null"
            : "{ \"studioId\": \"s1\", \"equipmentTypes\": [\(typen.joined(separator: ", "))] }"
        let saetzeJSON = saetze.map {
            """
            { "machineId": "\($0.machine)", "exerciseId": "\($0.uebung)",
              "load":\($0.kg), "volume":10, "rir": null,
              "performedAt": "\($0.wann)" }
            """
        }.joined(separator: ", ")
        let alleSaetzeJSON = [saetzeJSON, cardioSatzJSON].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        return GeraetTestdaten.dekodiere("""
        {
          "member": { "displayName": "Tim", "goals": {"weeklyDays": null, "targetWeight": null} },
          "studios": [
            { "id": "s1", "name": "Gym Ost", "timezone": "Europe/Berlin" },
            { "id": "s2", "name": "Gym West", "timezone": "Europe/Berlin" }
          ],
          "machines": [\(maschinen.joined(separator: ", "))],
          "calibrations": [],
          "lastSets": [\(alleSaetzeJSON)],
          "catalog": \(katalogJSON),
          "lastTypeSets": [\(typSaetzeJSON)]
        }
        """)
    }

    // MARK: - Zuletzt und Kacheln ohne Suchtext

    /// Benutzte Geraete stehen oben -- und bleiben in ihrer Kachel. Bis zur
    /// Testnotiz 12.10. stand darunter eine Liste, die sie wegliess; eine
    /// Kachel dagegen zaehlt und oeffnet ihre ganze Gruppe (#3), sonst
    /// fehlte das zuletzt benutzte Geraet genau dort, wo man es sucht.
    @Test func benutzteGeraeteStehenObenUndInIhrerKachel() {
        let daten = bootstrap(
            maschinen: [
                maschineJSON(id: "m1", name: "Latzug", label: "14", ort: "Rueckwand", besuche: 3),
                maschineJSON(id: "m2", name: "Bauchtrainer", label: "21", ort: "Freiflaeche"),
            ],
            saetze: [(machine: "m1", uebung: "u1", kg: 45, wann: "2026-09-07T10:00:00Z")])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "")

        #expect(gruppen.zuletzt.map(\.id) == ["geraet:m1"])
        #expect(gruppen.kachel(.geraete).map(\.id) == ["geraet:m2", "geraet:m1"])
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

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "")

        #expect(gruppen.zuletzt.count == 3)
        #expect(gruppen.kachel(.geraete).count == 5)
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

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "")

        #expect(gruppen.zuletzt.map(\.id) == ["geraet:neu", "geraet:alt"])
        #expect(gruppen.zuletzt.first?.zuletzt?.load == 50)
    }

    @Test func alleSindAlphabetischNachGeraetenamen() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Rudern sitzend", label: "9", ort: nil),
            maschineJSON(id: "m2", name: "Bauchtrainer", label: "21", ort: nil),
            maschineJSON(id: "m3", name: "Latzug", label: "14", ort: nil),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "")

        #expect(gruppen.kachel(.geraete).map(\.name) == ["Bauchtrainer", "Latzug", "Rudern sitzend"])
    }

    /// Sichtbar, aber ans Ende. Auszublenden hiesse, das Mitglied sucht am
    /// Geraet weiter, statt zu wissen, dass es gesperrt ist.
    @Test func gesperrteGeraeteStehenAmEnde() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Aaa", label: "1", ort: nil, status: "inactive"),
            maschineJSON(id: "m2", name: "Zzz", label: "2", ort: nil),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "")

        #expect(gruppen.kachel(.geraete).map(\.name) == ["Zzz", "Aaa"])
        #expect(gruppen.kachel(.geraete).last?.gesperrt == true)
    }

    /// Leere tokenHashes heissen "kein AKTIVER Tag" -- getBootstrap liest
    /// machine_tags mit status = active. Die Marke sagt deshalb, was die
    /// App weiss, nicht was am Geraet klebt.
    @Test func geraeteOhneAktivenTagSindMarkiert() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Beinbeuger", label: "5", ort: nil, tags: []),
            maschineJSON(id: "m2", name: "Latzug", label: "14", ort: nil),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "")

        #expect(gruppen.kachel(.geraete).first(where: { $0.name == "Beinbeuger" })?.nichtScannbar == true)
        #expect(gruppen.kachel(.geraete).first(where: { $0.name == "Latzug" })?.nichtScannbar == false)
    }

    @Test func dieOrtsangabeIstLabelUndPlatz() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Latzug", label: "Gerät 14", ort: "Rückwand rechts"),
            maschineJSON(id: "m2", name: "Bauchtrainer", label: "Gerät 21", ort: nil),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "")

        #expect(gruppen.kachel(.geraete)[0].ortsangabe == "Gerät 21")
        #expect(gruppen.kachel(.geraete)[1].ortsangabe == "Gerät 14 · Rückwand rechts")
    }

    /// `maschineJSON` baut die Modell-ID als `"em-\(id)"` -- der Schluessel,
    /// unter dem der Server das Foto signiert (Aufgabe 4).
    @Test func eintragTraegtDasModell() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Latzug", label: "14", ort: nil),
        ])

        let g = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "")

        #expect(g.kachel(.geraete).first?.modellId == "em-m1")
    }

    @Test func geraeteFremderStudiosFehlen() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Latzug", label: "14", ort: nil),
            maschineJSON(id: "m2", name: "Fremd", label: "99", ort: nil, studio: "s2"),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "")

        #expect(gruppen.kachel(.geraete).map(\.name) == ["Latzug"])
    }

    // MARK: - Suche

    @Test func mitSuchtextGibtEsNurNochEineListe() {
        let daten = bootstrap(
            maschinen: [maschineJSON(id: "m1", name: "Latzug", label: "14", ort: nil, besuche: 1)],
            saetze: [(machine: "m1", uebung: "u1", kg: 45, wann: "2026-09-07T10:00:00Z")])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "lat")

        #expect(gruppen.zuletzt.isEmpty)
        #expect(gruppen.treffer.map(\.name) == ["Latzug"])
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

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "bein")

        #expect(gruppen.treffer.map(\.name) == ["Beinpresse", "Beinbeuger", "Bauchtrainer"])
    }

    /// Gesperrt zaehlt auch bei einem Treffer mehr als jede andere Regel.
    /// "Aaa" traefe zweimal (Name UND Historie) und wuerde ohne die
    /// Sperr-Prioritaet vor "Aab" stehen -- die Sperr-Prioritaet in
    /// `trefferReihenfolge` ist eine eigene, von `alphabetischGesperrteAnsEnde`
    /// unabhaengige Zeile, die kein anderer Test durchlaeuft.
    @Test func gesperrteGeraeteStehenAuchBeiTrefferAmEnde() {
        let daten = bootstrap(
            maschinen: [
                maschineJSON(id: "m1", name: "Aaa", label: "1", ort: nil, status: "inactive", besuche: 2),
                maschineJSON(id: "m2", name: "Aab", label: "2", ort: nil),
            ],
            saetze: [(machine: "m1", uebung: "u1", kg: 40, wann: "2026-09-07T10:00:00Z")])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "aa")

        #expect(gruppen.treffer.map(\.name) == ["Aab", "Aaa"])
        #expect(gruppen.treffer.last?.gesperrt == true)
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

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "bein")

        #expect(gruppen.treffer.first(where: { $0.name == "Beinpresse" })?.trefferUebung == nil)
        #expect(gruppen.treffer.first(where: { $0.name == "Bauchtrainer" })?.trefferUebung?.name == "Beinheben hängend")
    }

    /// Ein Tipp auf einen Uebungstreffer oeffnet genau diese Uebung
    /// (Testnotiz 14.10., 18:45 #2) -- dafuer braucht der Treffer ihre ID,
    /// nicht nur den Namen fuer die Zeile.
    @Test func derUebungstrefferTraegtDieIdDerUebung() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m2", name: "Kabelzug", label: "21", ort: nil,
                         uebungen: [("u1", "Trizepsdrücken"), ("u9", "Hoher Bizepscurl")]),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "bizeps")

        #expect(gruppen.treffer.first?.trefferUebung?.id == "u9")
    }

    /// Mit Suchtext stehen die Treffer oben, nicht unter dem laufenden
    /// Training (Testnotiz 14.10., 18:45 #1). Nur Leerzeichen zaehlen wie
    /// kein Suchtext -- wie in gruppen(...).
    @Test func derKopfFehltNurMitSuchtext() {
        #expect(GeraeteAuswahl.zeigtKopf(suchtext: ""))
        #expect(GeraeteAuswahl.zeigtKopf(suchtext: "  "))
        #expect(!GeraeteAuswahl.zeigtKopf(suchtext: "bauch"))
    }

    @Test func gesuchtWirdAuchInNummerUndPlatz() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Latzug", label: "Gerät 14", ort: "Rückwand rechts"),
            maschineJSON(id: "m2", name: "Bauchtrainer", label: "Gerät 21", ort: "Freifläche"),
        ])

        let ueberNummer = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "14")
        let ueberPlatz = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "frei")

        #expect(ueberNummer.treffer.map(\.name) == ["Latzug"])
        #expect(ueberPlatz.treffer.map(\.name) == ["Bauchtrainer"])
    }

    @Test func grossschreibungUndUmlauteSindEgal() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Rückenstrecker", label: "22", ort: nil),
        ])

        for eingabe in ["RÜCKEN", "rucken", "Ruecken".replacingOccurrences(of: "ue", with: "ü")] {
            let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: eingabe)
            #expect(gruppen.treffer.count == 1, "\(eingabe) sollte treffen")
        }
    }

    @Test func nurLeerraumGiltAlsKeineSuche() {
        let daten = bootstrap(
            maschinen: [maschineJSON(id: "m1", name: "Latzug", label: "14", ort: nil, besuche: 1)],
            saetze: [(machine: "m1", uebung: "u1", kg: 45, wann: "2026-09-07T10:00:00Z")])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "   ")

        #expect(gruppen.zuletzt.count == 1)
    }

    @Test func ohneTrefferSindBeideGruppenLeer() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Latzug", label: "14", ort: nil),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "beinpresse xr")

        #expect(gruppen.zuletzt.isEmpty)
        #expect(gruppen.treffer.isEmpty)
        #expect(gruppen.istLeer)
    }

    // MARK: - Kraft und Cardio (Cardio Schnitt 3, seit 12.10. als Kacheln)

    @Test func ohneSuchtextStehenKraftUndCardioGetrennt() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Rudergerät", label: "4", ort: nil, kategorie: "cardio", einheit: "level"),
            maschineJSON(id: "m2", name: "Latzug", label: "14", ort: nil),
            maschineJSON(id: "m3", name: "Laufband", label: "2", ort: nil, kategorie: "cardio", einheit: "kmh"),
            maschineJSON(id: "m4", name: "Beinpresse", label: "7", ort: nil),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "")

        #expect(gruppen.kachel(.geraete).map(\.name) == ["Beinpresse", "Latzug"])
        #expect(gruppen.kachel(.cardio).map(\.name) == ["Laufband", "Rudergerät"])
        #expect(gruppen.treffer.isEmpty)
    }

    @Test func eineLeereKategorieBleibtLeer() {
        // Ein reines Kraftstudio hat keine Cardio-Gruppe -- die Ansicht
        // zeigt dann keine leere Ueberschrift.
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Latzug", label: "14", ort: nil),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "")

        #expect(gruppen.kachel(.geraete).count == 1)
        #expect(gruppen.kategorien.map(\.gruppe) == [.geraete])
    }

    @Test func zuletztStehtUeberDenKachelnUndBleibtDarin() {
        let daten = bootstrap(
            maschinen: [
                maschineJSON(id: "m1", name: "Laufband", label: "2", ort: nil, besuche: 2,
                             kategorie: "cardio", einheit: "kmh"),
                maschineJSON(id: "m2", name: "Ergometer", label: "3", ort: nil, kategorie: "cardio", einheit: "watt"),
            ],
            saetze: [(machine: "m1", uebung: "u1", kg: 8.5, wann: "2026-09-07T10:00:00Z")])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "")

        #expect(gruppen.zuletzt.map(\.name) == ["Laufband"])
        #expect(gruppen.kachel(.cardio).map(\.name) == ["Ergometer", "Laufband"])
        // Die Zeile schreibt die Belastung in der Einheit des Geraets.
        #expect(gruppen.zuletzt.first?.zuletzt == GeraeteAuswahl.Zuletzt(
            performedAt: zeit("2026-09-07T10:00:00Z"), load: 8.5, loadUnit: .kmh))
    }

    @Test func zuletztEinesCardioSatzesNenntDieCardioWerte() {
        let daten = bootstrap(
            maschinen: [maschineJSON(id: "m1", name: "Rudergerät", label: "4", ort: nil, besuche: 2,
                                     kategorie: "cardio", einheit: "level")],
            cardioSatzJSON: """
            { "machineId": "m1", "exerciseId": "u1", "load": null, "volume": null, "rir": null,
              "performedAt": "2026-09-07T10:00:00Z", "cardio": { "zeit": 510, "strecke": 2000 } }
            """)

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "")

        let zuletzt = gruppen.zuletzt.first?.zuletzt
        #expect(zuletzt?.cardio == CardioWerte(zeit: 510, strecke: 2000))
        #expect(zuletzt?.werte == "8:30 · 2,0 km")
    }

    @Test func zuletztEinesKraftSatzesNenntDieBelastungMitEinheit() {
        let z = GeraeteAuswahl.Zuletzt(performedAt: Date(), load: 8.5, loadUnit: .kmh)
        #expect(z.werte == "8,5 km/h")
    }

    @Test func mitSuchtextIstDieListeFlachUeberAlleKacheln() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Laufband", label: "2", ort: "Lauf-Ecke", kategorie: "cardio", einheit: "kmh"),
            maschineJSON(id: "m2", name: "Latzug", label: "14", ort: "Lauf-Ecke"),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "lauf")

        #expect(gruppen.treffer.map(\.name) == ["Latzug", "Laufband"])
        #expect(gruppen.kategorien.isEmpty)
    }

    // MARK: - Stationen (Spec 6)

    private var zweiMaschinenUndTypen: BootstrapResponse {
        bootstrap(
            maschinen: [maschineJSON(id: "m1", name: "Latzug", label: "14", ort: nil)],
            typen: [typJSON(id: "t1", name: "Beinpresse"), typJSON(id: "t2", name: "Kabelzug")])
    }

    @Test func studioMitGeraetenZeigtKeineKatalogtypen() {
        let g = GeraeteAuswahl.gruppen(bootstrap: zweiMaschinenUndTypen, ort: .studio("s1"), suchtext: "")
        #expect(g.kategorien.flatMap(\.eintraege).map(\.id) == ["geraet:m1"])
    }

    @Test func studioOhneGeraeteZeigtAlleTypenMitStudioId() {
        let daten = bootstrap(maschinen: [], typen: [typJSON(id: "t1", name: "Beinpresse"),
                                                     typJSON(id: "t2", name: "Kabelzug")])
        let g = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "")
        #expect(g.kachel(.geraete).map(\.id) == ["typ:t1", "typ:t2"])
        #expect(g.kachel(.geraete).allSatisfy { $0.station.studioId == "s1" })
        // Ein Typ ist kein Geraet ohne Sticker.
        #expect(g.kachel(.geraete).allSatisfy { !$0.nichtScannbar && !$0.gesperrt })
    }

    @Test func freiesTrainingZeigtAlleTypenOhneStudioId() {
        let g = GeraeteAuswahl.gruppen(bootstrap: zweiMaschinenUndTypen, ort: .freiesTraining, suchtext: "")
        #expect(g.kachel(.geraete).map(\.id) == ["typ:t1", "typ:t2"])
        #expect(g.kachel(.geraete).allSatisfy { $0.station.studioId == nil })
    }

    @Test func zuletztEnthaeltEinenFreienSatzAmTyp() {
        let daten = bootstrap(
            maschinen: [],
            typen: [typJSON(id: "t1", name: "Beinpresse"), typJSON(id: "t2", name: "Kabelzug")],
            typSaetze: [(modell: "t2", uebung: "gu1", kg: 30, wann: "2026-09-07T10:00:00Z")])
        let g = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .freiesTraining, suchtext: "")
        #expect(g.zuletzt.map(\.id) == ["typ:t2"])
        #expect(g.kachel(.geraete).map(\.id) == ["typ:t1", "typ:t2"])
        #expect(g.zuletzt.first?.zuletzt == GeraeteAuswahl.Zuletzt(
            performedAt: zeit("2026-09-07T10:00:00Z"), load: 30, loadUnit: .kg))
    }

    @Test func dieSucheFindetEinenTypUeberEineGymtavoUebung() {
        let daten = bootstrap(maschinen: [], typen: [
            typJSON(id: "t1", name: "Beinpresse", uebungen: [("gu1", "Wadenheben")]),
            typJSON(id: "t2", name: "Kabelzug"),
        ])
        let g = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .freiesTraining, suchtext: "waden")
        #expect(g.treffer.map(\.id) == ["typ:t1"])
        #expect(g.treffer.first?.trefferUebung?.name == "Wadenheben")
    }

    @Test func uebungenEinesStudioGeraetsKommenUnveraendertAusMachines() {
        // Der Server mischt Gymtavo-Uebungen schon in machines[].exercises;
        // die App ergaenzt nichts aus dem Katalog.
        let daten = bootstrap(
            maschinen: [maschineJSON(id: "m1", name: "Latzug", label: "14", ort: nil,
                                     uebungen: [("u1", "Latzug breit")])],
            typen: [typJSON(id: "t1", name: "Latzug", uebungen: [("gu9", "Nackendruecken")])])
        let g = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "nacken")
        #expect(g.treffer.isEmpty)
        let alle = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "")
        #expect(alle.kachel(.geraete).first?.station.exercises.map(\.id) == ["u1"])
    }
    // MARK: - Kacheln und Abloesung (Testnotiz 12.10., #1-#5)

    private var katalogMitGruppen: BootstrapResponse {
        bootstrap(maschinen: [], typen: [
            typJSON(id: "t5", name: "Laufband", kategorie: "cardio", gruppe: "cardio"),
            typJSON(id: "t2", name: "Kabelzug", gruppe: "kabelzug",
                    uebungen: [("k1", "Face Pull"), ("k2", "Kabel-Flys")]),
            typJSON(id: "t3", name: "Langhantel", gruppe: "freihantel"),
            typJSON(id: "t4", name: "Kurzhantel", gruppe: "freihantel"),
            typJSON(id: "t1", name: "Beinpresse", gruppe: "geraete"),
            typJSON(id: "t9", name: "Hoher Kabelzug + Seil", gruppe: "kabelzug", abgeloest: true,
                    uebungen: [("k1", "Face Pull")]),
        ])
    }

    /// #3/#5: feste Reihenfolge, und eine Gruppe ohne Geraet (Eigengewicht,
    /// Kettlebell, Gummiband) erscheint gar nicht.
    @Test func kachelnInFesterReihenfolgeOhneLeere() {
        let g = GeraeteAuswahl.gruppen(bootstrap: katalogMitGruppen, ort: .freiesTraining, suchtext: "")
        #expect(g.kategorien.map(\.gruppe) == [.geraete, .freihantel, .kabelzug, .cardio])
        #expect(g.kachel(.freihantel).map(\.name) == ["Kurzhantel", "Langhantel"])
    }

    /// #1: der abgeloeste Typ steht in keiner Kachel und keinem Treffer --
    /// ein alter Block auf ihn laesst sich aber weiter oeffnen.
    @Test func einAbgeloesterTypFehltInListeUndSucheBleibtAberAufloesbar() {
        let daten = katalogMitGruppen
        let g = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .freiesTraining, suchtext: "")
        #expect(g.kachel(.kabelzug).map(\.id) == ["typ:t2"])
        let suche = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .freiesTraining, suchtext: "kabelzug")
        #expect(suche.treffer.map(\.id) == ["typ:t2"])
        #expect(daten.station(schluessel: "typ:t9", studioId: nil)?.equipmentModel.name == "Hoher Kabelzug + Seil")
    }

    /// #3: Kabelzug ist ein Geraet -- der Tipp oeffnet gleich die Uebungen.
    /// Freihantel hat drei -- der Tipp zeigt die Liste.
    @Test func eineKachelMitEinemGeraetOeffnetEsDirekt() throws {
        let g = GeraeteAuswahl.gruppen(bootstrap: katalogMitGruppen, ort: .freiesTraining, suchtext: "")
        let kabel = try #require(g.kategorien.first { $0.gruppe == .kabelzug })
        let hantel = try #require(g.kategorien.first { $0.gruppe == .freihantel })
        #expect(GeraeteAuswahl.ziel(kabel) == .station(kabel.eintraege[0].station))
        #expect(GeraeteAuswahl.ziel(hantel) == .liste(.freihantel))
    }

    /// Ein gesperrtes Einzelgeraet oeffnet nichts -- die Liste zeigt dann
    /// wenigstens, warum.
    @Test func eineKachelMitGesperrtemEinzelgeraetZeigtDieListe() throws {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Kabelzug", label: "3", ort: nil, status: "inactive", gruppe: "kabelzug"),
        ])
        let g = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "")
        let kabel = try #require(g.kategorien.first)
        #expect(GeraeteAuswahl.ziel(kabel) == .liste(.kabelzug))
    }

    @Test func dieKachelZaehltGeraeteOderBeiEinemGeraetDessenUebungen() throws {
        let g = GeraeteAuswahl.gruppen(bootstrap: katalogMitGruppen, ort: .freiesTraining, suchtext: "")
        #expect(GeraeteAuswahl.kachelText(try #require(g.kategorien.first { $0.gruppe == .kabelzug })) == "2 Übungen")
        #expect(GeraeteAuswahl.kachelText(try #require(g.kategorien.first { $0.gruppe == .freihantel })) == "2 Geräte")
        #expect(GeraeteAuswahl.kachelText(try #require(g.kategorien.first { $0.gruppe == .geraete })) == "1 Übung")
    }

    /// Die Kategorieliste: nur die Gruppe, alphabetisch, ohne Zuletzt und
    /// ohne Kacheln -- und ihre Suche bleibt in der Gruppe.
    @Test func dieKategorielisteZeigtNurIhreGruppe() {
        let daten = katalogMitGruppen
        let liste = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .freiesTraining, suchtext: "", gruppe: .freihantel)
        #expect(liste.liste.map(\.name) == ["Kurzhantel", "Langhantel"])
        #expect(liste.zuletzt.isEmpty)
        #expect(liste.kategorien.isEmpty)
        let suche = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .freiesTraining, suchtext: "e", gruppe: .freihantel)
        #expect(suche.treffer.map(\.name) == ["Kurzhantel", "Langhantel"])
    }

    /// Ein Studiogeraet ohne Gruppe vom Server (Server vor 0051) landet
    /// nach seiner Kategorie.
    @Test func einStudiogeraetOhneGruppeLandetNachKategorie() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Laufband", label: "2", ort: nil, kategorie: "cardio", einheit: "kmh"),
            maschineJSON(id: "m2", name: "Kabelturm", label: "5", ort: nil, gruppe: "kabelzug"),
        ])
        let g = GeraeteAuswahl.gruppen(bootstrap: daten, ort: .studio("s1"), suchtext: "")
        #expect(g.kategorien.map(\.gruppe) == [.kabelzug, .cardio])
    }
}

private extension GeraeteAuswahl.Gruppen {
    /// Die Eintraege einer Kachel -- leer, wenn es sie nicht gibt.
    func kachel(_ gruppe: Geraetegruppe) -> [GeraeteAuswahl.Eintrag] {
        kategorien.first { $0.gruppe == gruppe }?.eintraege ?? []
    }
}
