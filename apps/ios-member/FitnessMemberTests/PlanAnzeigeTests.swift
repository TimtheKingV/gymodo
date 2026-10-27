import Foundation
import Testing
@testable import FitnessMember

/// Die Planansicht "heute dran" (Trainingsplan Etappe 3, Task 11, Entwuerfe
/// 2.1-2.3): was die Zeilen zeigen, wie der Fortschritt zaehlt, woher Bild
/// und Pause kommen und wann Karte und Anfaengerangebot erscheinen.
@Suite("PlanAnzeige")
struct PlanAnzeigeTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - Testdaten

    /// Einheit A: Beinpresse (m1, aktiv), Rudern (m2, stillgelegt; m5 bietet
    /// es auch), Seitheben (m3, gibt es nicht mehr, und kein anderes Geraet
    /// bietet es), Cardio 20 Min. Einheit B: eine Position.
    static func plan(studioId: String = "s1", anfaenger: Bool = false, erledigt: Int = 0,
                     minuten: String = "60") -> Trainingsplan {
        func position(_ key: String, _ baustein: String, _ exerciseId: String, _ machineId: String,
                      _ muskeln: [String], pause: Int = 120, dauer: String = "null",
                      wdh: (String, String) = ("8", "12")) -> String {
            let liste = muskeln.map { "\"\($0)\"" }.joined(separator: ",")
            return """
            {"key":"\(key)","baustein":"\(baustein)","rolle":"pflicht","exerciseId":"\(exerciseId)",
             "machineId":"\(machineId)","typ":"mehrgelenk","saetze":3,"wdhVon":\(wdh.0),"wdhBis":\(wdh.1),
             "reserveVon":1,"reserveBis":3,"pauseSek":\(pause),"aufwaermsatz":false,"dauerMin":\(dauer),
             "hauptmuskeln":[\(liste)]}
            """
        }
        let json = """
        {"planId":"p1","studioId":"\(studioId)","version":1,"regelVersion":"1.2.0",
         "struktur":"gk_ab","gruende":["gk_ab","zeit_uebungen"],"naechsteEinheitKey":"A","zuletztEinheitKey":null,
         "einheitenErledigt":\(erledigt),"anfaengerUebergang":\(anfaenger),"alternativen":{},
         "einheiten":[
           {"key":"A","geschaetzteMinuten":\(minuten),"positionen":[
             \(position("A0", "beine_knie", "e1", "m1", ["quads"])),
             \(position("A1", "ziehen", "e2", "m2", ["lats", "upper_back"], pause: 90)),
             \(position("A2", "schulter", "e3", "m3", ["deltoid_lateral"], pause: 75)),
             \(position("A3", "cardio", "c1", "m4", [], pause: 0, dauer: "20", wdh: ("null", "null")))]},
           {"key":"B","geschaetzteMinuten":40,"positionen":[
             \(position("B0", "druecken", "e5", "m1", ["pectorals"]))]}]}
        """
        return try! JSONDecoder().decode(Trainingsplan.self, from: Data(json.utf8))
    }

    static func maschine(_ id: String, status: String = "active", studioId: String = "s1",
                         _ uebungen: [(id: String, name: String, muskel: String?)]) -> BootstrapResponse.Machine {
        let liste = uebungen.map { u in
            let muskeln = u.muskel.map { #"[{"key":"\#($0)","name":"M","role":"primary"},{"key":"biceps","name":"Bizeps","role":"secondary"}]"# } ?? "[]"
            return #"{"id":"\#(u.id)","name":"\#(u.name)","volumeKind":"reps","targetMin":8,"targetMax":12,"muscles":\#(muskeln)}"#
        }.joined(separator: ",")
        return GeraetTestdaten.dekodiere("""
        {"id":"\(id)","studioId":"\(studioId)","label":"Gerät \(id)","locationNote":null,"status":"\(status)",
         "tokenHashes":[],"visitCount":0,
         "equipmentModel":{"id":"em-\(id)","name":"Modell \(id)","manufacturer":null,"category":"kraft","photoPath":null,
           "loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,"settingDefinitions":[]},
         "exercises":[\(liste)]}
        """)
    }

    static func bootstrap(plaene: [Trainingsplan] = [plan()]) -> BootstrapResponse {
        BootstrapResponse(
            member: .init(displayName: nil, plans: plaene),
            studios: [.init(id: "s1", name: "Nord", timezone: "Europe/Berlin"),
                      .init(id: "s2", name: "Süd", timezone: "Europe/Berlin")],
            machines: [
                maschine("m1", [("e1", "Beinpresse", "quads"), ("e5", "Brustpresse", "pectorals")]),
                maschine("m2", status: "inactive", [("e2", "Rudern an der Maschine", "lats")]),
                maschine("m5", [("e2", "Rudern an der Maschine", "lats"), ("e4", "Latzug", "lats")]),
                maschine("m6", [("e6", "Seitheben am Kabel", "deltoid_lateral")]),
                maschine("m4", [("c1", "Fahrrad", nil)]),
                // Ein Geraet in einem anderen Studio zaehlt nie als Ersatz.
                maschine("m9", studioId: "s2", [("e3", "Seitheben an der Maschine", "deltoid_lateral")]),
            ],
            calibrations: [], lastSets: [])
    }

    static func zustand(_ stati: [String: PositionStatus] = [:], ersatz: [String: String] = [:]) -> AblaufZustand {
        let einheit = plan().einheiten[0]
        return AblaufZustand(positionen: einheit.positionen.map {
            AblaufPosition(key: $0.key, exerciseId: $0.exerciseId, hauptmuskeln: $0.hauptmuskeln,
                           cardio: $0.baustein == "cardio", status: stati[$0.key] ?? .offen,
                           ersatzExerciseId: ersatz[$0.key])
        }, ungeplanteGesehen: [])
    }

    static func block(_ machineId: String, _ exerciseId: String, saetze: Int, minute: Double = 0) -> LokalerBlock {
        LokalerBlock(machineId: machineId, exerciseId: exerciseId, saetze: (1...saetze).map { i in
            LokalerSatz(id: UUID(), setIndex: i, load: 50, volume: 10, problemFlag: false, problemReason: nil,
                        performedAt: start.addingTimeInterval((minute + Double(i)) * 60))
        })
    }

    static func zeilen(_ zustand: AblaufZustand? = nil, bloecke: [LokalerBlock] = []) -> [PlanZeilenModell] {
        PlanAnzeige.zeilen(plan: plan(), einheitKey: "A", zustand: zustand, bloecke: bloecke, bootstrap: bootstrap())
    }

    // MARK: - Untertitel

    @Test("Untertitel Mehrgelenk 3 x 8-12 mit Reserve")
    func untertitelMehrgelenk() {
        let zeile = Self.zeilen()[0]
        #expect(zeile.name == "Beinpresse")
        #expect(zeile.untertitel == "3 × 8–12 · Reserve 1–3")
        #expect(zeile.status == .offen)
    }

    @Test("Cardio zeigt Minuten statt Saetze")
    func cardioZeigtMinuten() {
        #expect(Self.zeilen()[3].untertitel == "20 Min")
    }

    @Test("optional nennt die ausloesende Uebung und Muskelgruppe")
    func optionalNenntAusloeser() {
        // Beinpresse ist geplant und loest nichts aus; Latzug teilt die Lats
        // mit dem Rudern (A1) -- er ist der Ausloeser.
        let bloecke = [Self.block("m1", "e1", saetze: 3), Self.block("m5", "e4", saetze: 3, minute: 10)]
        let zeile = Self.zeilen(Self.zustand(["A0": .erledigt, "A1": .optional]), bloecke: bloecke)[1]
        #expect(zeile.status == .optional)
        #expect(zeile.untertitel == "Optional: Latzug zählt für Rücken")
    }

    @Test("optional ohne ableitbaren Ausloeser heisst nur Optional")
    func optionalOhneAusloeser() {
        let zeile = Self.zeilen(Self.zustand(["A1": .optional]))[1]
        #expect(zeile.untertitel == "Optional")
    }

    @Test("getauscht zeigt Heute: Ersatz")
    func getauschtZeigtErsatz() {
        let zeile = Self.zeilen(Self.zustand(["A2": .getauscht], ersatz: ["A2": "e6"]))[2]
        #expect(zeile.status == .getauscht)
        // Der Name bleibt der geplante (aufgeloest auch ueber ein Geraet
        // eines anderen Studios, wie im Bestand).
        #expect(zeile.name == "Seitheben an der Maschine")
        #expect(zeile.untertitel == "Heute: Seitheben am Kabel")
        // Trainiert wird heute der Ersatz: Video und Bild zeigen ihn.
        #expect(zeile.exerciseId == "e6")
        #expect(zeile.vorschaubildModell == "em-m6")
    }

    @Test("erledigt zeigt die Satzzahl der Session")
    func erledigtZeigtSaetze() {
        let zeile = Self.zeilen(Self.zustand(["A0": .erledigt]), bloecke: [Self.block("m1", "e1", saetze: 3)])[0]
        #expect(zeile.status == .erledigt)
        #expect(zeile.untertitel == "3 Sätze")
    }

    // MARK: - Fortschritt und Zeit

    @Test("Fortschritt zaehlt erledigt plus optional")
    func fortschrittZaehltErledigtUndOptional() {
        let zustand = Self.zustand(["A0": .erledigt, "A1": .optional, "A2": .getauscht])
        #expect(PlanAnzeige.fortschritt(plan: Self.plan(), einheitKey: "A", zustand: zustand) == "2 von 4")
        #expect(PlanAnzeige.fortschritt(plan: Self.plan(), einheitKey: "A", zustand: nil) == "0 von 4")
    }

    @Test("Restzeit anteilig nach offenen Positionen")
    func restzeitAnteilig() {
        let plan = Self.plan()
        #expect(PlanAnzeige.restminutenText(plan: plan, einheitKey: "A", zustand: Self.zustand(["A0": .erledigt]))
                == "noch ca. 45 Min")
        let alles = Self.zustand(["A0": .erledigt, "A1": .erledigt, "A2": .optional, "A3": .erledigt])
        #expect(PlanAnzeige.restminutenText(plan: plan, einheitKey: "A", zustand: alles) == nil)
    }

    @Test("Meta und Danach")
    func metaUndDanach() {
        let plan = Self.plan()
        #expect(PlanAnzeige.metaText(plan.einheiten[0]) == "4 Übungen · ca. 60 Min")
        #expect(PlanAnzeige.danachText(plan: plan, einheitKey: "A") == "Danach: Einheit B")
        #expect(PlanAnzeige.danachText(plan: plan, einheitKey: "B") == "Danach: Einheit A")
    }

    // MARK: - Bild

    @Test("stillgelegtes Geraet: Bild vom anderen Geraet derselben Uebung")
    func stillgelegtesGeraetNimmtAnderes() {
        let zeile = Self.zeilen()[1]
        #expect(zeile.name == "Rudern an der Maschine")
        #expect(zeile.vorschaubildModell == "em-m5")
        #expect(Self.zeilen()[0].vorschaubildModell == "em-m1")
    }

    @Test("ohne Ersatzgeraet kein Bild, Zeile bleibt")
    func ohneErsatzgeraetKeinBild() {
        let zeilen = Self.zeilen()
        #expect(zeilen.count == 4)
        #expect(zeilen[2].id == "A2")
        // m3 gibt es nicht mehr, m9 steht in einem anderen Studio.
        #expect(zeilen[2].vorschaubildModell == nil)
    }

    // MARK: - Zusaetzlich gemacht

    @Test("zusaetzlich gemacht listet ungeplante Uebungen mit Satzzahl")
    func zusaetzlichGemacht() {
        let bloecke = [
            Self.block("m1", "e1", saetze: 3),
            Self.block("m5", "e4", saetze: 2, minute: 10),
            Self.block("m6", "e6", saetze: 1, minute: 20),
            // Zweiter Durchgang am Latzug: ein Eintrag, Saetze addiert.
            Self.block("m5", "e4", saetze: 1, minute: 30),
        ]
        let zustand = Self.zustand(["A0": .erledigt, "A1": .optional])
        let zusatz = PlanAnzeige.zusaetzlichGemacht(plan: Self.plan(), einheitKey: "A", zustand: zustand,
                                                    bloecke: bloecke, bootstrap: Self.bootstrap())
        #expect(zusatz.map(\.name) == ["Latzug", "Seitheben am Kabel"])
        #expect(zusatz.map(\.untertitel) == ["3 Sätze · zählt mit", "1 Satz"])
        #expect(zusatz.allSatisfy { $0.status == .erledigt && $0.zusatz })
        #expect(zusatz.first?.vorschaubildModell == "em-m5")

        // Heute getauscht: der Ersatz ist geplant, kein Zusatz.
        let getauscht = Self.zustand(["A2": .getauscht], ersatz: ["A2": "e6"])
        let ohneErsatz = PlanAnzeige.zusaetzlichGemacht(plan: Self.plan(), einheitKey: "A", zustand: getauscht,
                                                        bloecke: bloecke, bootstrap: Self.bootstrap())
        #expect(ohneErsatz.map(\.name) == ["Latzug"])
    }

    // MARK: - Gebundene Planversion

    @Test("laufende Einheit bleibt bei ihrer Planversion")
    func laufendeEinheitBleibtBeiIhrerVersion() {
        // Gebunden ist die Version, in der A1 Latzug (e4) war; der Bootstrap
        // hat inzwischen eine neuere mit Rudern (e2) an A1.
        var zustand = Self.zustand(["A0": .erledigt])
        zustand.positionen[1].exerciseId = "e4"
        let bloecke = [Self.block("m1", "e1", saetze: 3), Self.block("m5", "e4", saetze: 2, minute: 10),
                       Self.block("m5", "e2", saetze: 1, minute: 20)]
        zustand.positionen[1].status = .erledigt
        let zeilen = Self.zeilen(zustand, bloecke: bloecke)
        #expect(zeilen[1].name == "Latzug")
        #expect(zeilen[1].exerciseId == "e4")
        #expect(zeilen[1].untertitel == "2 Sätze")
        // Rudern ist in der gebundenen Version ungeplant, Latzug nicht.
        let zusatz = PlanAnzeige.zusaetzlichGemacht(plan: Self.plan(), einheitKey: "A", zustand: zustand,
                                                    bloecke: bloecke, bootstrap: Self.bootstrap())
        #expect(zusatz.map(\.name) == ["Rudern an der Maschine"])
        // Die Pause folgt der Uebung der gebundenen Version (Dauer je Schluessel).
        #expect(PlanAnzeige.pauseSek(fuer: "e4", plan: Self.plan(), einheitKey: "A", zustand: zustand, profil: 60) == 90)
        #expect(PlanAnzeige.pauseSek(fuer: "e2", plan: Self.plan(), einheitKey: "A", zustand: zustand, profil: 60) == 60)
    }

    // MARK: - Pause (F6)

    @Test("Pause kommt aus der Planposition, sonst aus dem Profil")
    func pauseAusPlanSonstProfil() {
        let plan = Self.plan()
        #expect(PlanAnzeige.pauseSek(fuer: "e2", plan: plan, einheitKey: "A", zustand: Self.zustand(), profil: 60) == 90)
        #expect(PlanAnzeige.pauseSek(fuer: "e4", plan: plan, einheitKey: "A", zustand: Self.zustand(), profil: 60) == 60)
        // Getauscht: die Ersatzuebung erbt die Pause ihrer Position, die
        // geplante gilt dort nicht mehr.
        let getauscht = Self.zustand(["A2": .getauscht], ersatz: ["A2": "e6"])
        #expect(PlanAnzeige.pauseSek(fuer: "e6", plan: plan, einheitKey: "A", zustand: getauscht, profil: 60) == 75)
        #expect(PlanAnzeige.pauseSek(fuer: "e3", plan: plan, einheitKey: "A", zustand: getauscht, profil: 60) == 60)
        // Ohne Plan, Einheit oder Ablauf: wie heute.
        #expect(PlanAnzeige.pauseSek(fuer: "e2", plan: nil, einheitKey: nil, zustand: nil, profil: 45) == 45)
        #expect(PlanAnzeige.pauseSek(fuer: "e2", plan: plan, einheitKey: "B", zustand: nil, profil: 45) == 45)
    }

    // MARK: - Sichtbarkeit

    @Test("Plankarte entfaellt ohne Plan")
    func plankarteEntfaelltOhnePlan() {
        let mit = Self.bootstrap()
        #expect(PlanAnzeige.plan(bootstrap: mit, studioId: "s1")?.planId == "p1")
        // Freies Training, anderes Studio, Studio ohne Plan, kein Bootstrap.
        #expect(PlanAnzeige.plan(bootstrap: mit, studioId: nil) == nil)
        #expect(PlanAnzeige.plan(bootstrap: mit, studioId: "s2") == nil)
        #expect(PlanAnzeige.plan(bootstrap: Self.bootstrap(plaene: []), studioId: "s1") == nil)
        #expect(PlanAnzeige.plan(bootstrap: nil, studioId: "s1") == nil)
        // Ein Plan ohne Einheiten ist keiner.
        let leer = try! JSONDecoder().decode(Trainingsplan.self, from: Data("""
        {"planId":"p2","studioId":"s1","version":1,"regelVersion":"1","struktur":"gk_ab","einheiten":[]}
        """.utf8))
        #expect(PlanAnzeige.plan(bootstrap: Self.bootstrap(plaene: [leer]), studioId: "s1") == nil)
    }

    @Test("Einheit: Ablauf desselben Plans, sonst die naechste")
    func einheitAusAblaufSonstNaechste() {
        let plan = Self.plan()
        #expect(PlanAnzeige.einheitKey(plan: plan, ablaufPlanId: "p1", ablaufEinheitKey: "B", naechsteEinheitKey: "A") == "B")
        #expect(PlanAnzeige.einheitKey(plan: plan, ablaufPlanId: "alt", ablaufEinheitKey: "B", naechsteEinheitKey: nil) == "A")
        #expect(PlanAnzeige.einheitKey(plan: plan, ablaufPlanId: nil, ablaufEinheitKey: nil, naechsteEinheitKey: "B") == "B")
        // Ein unbekannter Schluessel faellt auf die erste Einheit.
        #expect(PlanAnzeige.einheitKey(plan: plan, ablaufPlanId: "p1", ablaufEinheitKey: "Z", naechsteEinheitKey: "Y") == "A")
    }

    // MARK: - Abschluss (2.3)

    @Test("Abschluss nennt erledigt, optional und die naechste Einheit")
    func abschlussText() {
        let zustand = Self.zustand(["A0": .erledigt, "A1": .optional, "A3": .erledigt])
        let abschluss = PlanAnzeige.abschluss(einheitKey: "A", zustand: zustand, naechsteEinheitKey: "B")
        #expect(abschluss.titel == "EINHEIT A")
        #expect(abschluss.zeile == "2 von 4 Übungen erledigt, 1 optional")
        #expect(abschluss.naechstes == "Nächstes Mal ist Einheit B dran.")

        let nichts = PlanAnzeige.abschluss(einheitKey: "A", zustand: Self.zustand(), naechsteEinheitKey: "A")
        #expect(nichts.zeile == "0 von 4 Übungen erledigt")
        #expect(nichts.naechstes == "Nächstes Mal ist wieder Einheit A dran.")
    }

    @Test("Home-Zeile: Meta vor dem Start, Fortschritt danach")
    func heuteDranUntertitel() {
        let plan = Self.plan()
        let vorher = PlanAnzeige.Heute(plan: plan, einheit: plan.einheiten[0], zustand: Self.zustand())
        #expect(PlanAnzeige.heuteDranUntertitel(vorher) == "4 Übungen · ca. 60 Min")
        let mitten = PlanAnzeige.Heute(plan: plan, einheit: plan.einheiten[0], zustand: Self.zustand(["A0": .erledigt]))
        #expect(PlanAnzeige.heuteDranUntertitel(mitten) == "1 von 4")
        // Optional zaehlt mit, deshalb nicht "erledigt".
        let optional = PlanAnzeige.Heute(plan: plan, einheit: plan.einheiten[0], zustand: Self.zustand(["A1": .optional]))
        #expect(PlanAnzeige.heuteDranUntertitel(optional) == "1 von 4")
    }

    @Test("heute nimmt den Ablauf nur, wenn Plan und Einheit passen")
    func heuteNimmtPassendenAblauf() {
        let zustand = Self.zustand(["A0": .erledigt])
        let passt = PlanAnzeige.heute(bootstrap: Self.bootstrap(), studioId: "s1", ablaufPlanId: "p1",
                                      ablaufEinheitKey: "A", ablaufZustand: zustand, naechsteEinheitKey: "A")
        #expect(passt?.zustand == zustand)
        let fremd = PlanAnzeige.heute(bootstrap: Self.bootstrap(), studioId: "s1", ablaufPlanId: "alt",
                                      ablaufEinheitKey: "A", ablaufZustand: zustand, naechsteEinheitKey: "A")
        #expect(fremd?.einheitKey == "A")
        #expect(fremd?.zustand == nil)
        #expect(PlanAnzeige.heute(bootstrap: Self.bootstrap(), studioId: nil, ablaufPlanId: "p1",
                                  ablaufEinheitKey: "A", ablaufZustand: zustand, naechsteEinheitKey: "A") == nil)
    }

    @Test("Anfaengerangebot nur mit Uebergang und nur einmal je Plan")
    func anfaengerangebotSichtbarkeit() {
        #expect(PlanAnzeige.zeigtAnfaengerAngebot(plan: Self.plan(anfaenger: true), gesehen: []))
        #expect(!PlanAnzeige.zeigtAnfaengerAngebot(plan: Self.plan(anfaenger: true), gesehen: ["p1"]))
        #expect(!PlanAnzeige.zeigtAnfaengerAngebot(plan: Self.plan(anfaenger: false), gesehen: []))
        #expect(!PlanAnzeige.zeigtAnfaengerAngebot(plan: nil, gesehen: []))
    }

    @Test("Anfaengerangebot erscheint nach dem Neuladen, einmal")
    func anfaengerangebotNachNeuladen() {
        let vorher = Self.plan(anfaenger: false, erledigt: 7)
        let nachher = Self.plan(anfaenger: true, erledigt: 8)
        var gesehen: Set<String> = []
        // Bootstrap von vor completeSession: noch kein Angebot.
        var karte = PlanAnzeige.anfaengerAngebotNachPruefung(bisher: nil, plan: vorher, gesehen: gesehen)
        #expect(karte == nil)
        // Frischer Bootstrap auf demselben Screen: jetzt ja, mit Zahl 8.
        karte = PlanAnzeige.anfaengerAngebotNachPruefung(bisher: karte, plan: nachher, gesehen: gesehen)
        #expect(karte?.planId == "p1")
        #expect(PlanAnzeige.anfaengerTexte(nachher).label == "EINHEIT 8 VON 8 ALS ANFÄNGER")
        gesehen.insert("p1")
        // Ein weiterer Bootstrap laesst die gezeigte Karte stehen.
        #expect(PlanAnzeige.anfaengerAngebotNachPruefung(bisher: karte, plan: nachher, gesehen: gesehen)?.planId == "p1")
        // "Später" (Karte weg) und spaetere Abschluesse: nie wieder fuer diesen Plan.
        #expect(PlanAnzeige.anfaengerAngebotNachPruefung(bisher: nil, plan: nachher, gesehen: gesehen) == nil)
    }

    @Test("Anfaengerangebot merkt sich den Plan in den UserDefaults")
    func anfaengerangebotGemerkt() {
        let defaults = UserDefaults(suiteName: "PlanAnzeigeTests-\(UUID().uuidString)")!
        #expect(PlanAnzeige.gesehneAnfaengerAngebote(defaults).isEmpty)
        PlanAnzeige.anfaengerAngebotGesehen(planId: "p1", defaults)
        PlanAnzeige.anfaengerAngebotGesehen(planId: "p1", defaults)
        PlanAnzeige.anfaengerAngebotGesehen(planId: "p2", defaults)
        #expect(PlanAnzeige.gesehneAnfaengerAngebote(defaults) == ["p1", "p2"])
    }
}
