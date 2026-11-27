import AVFoundation
import Foundation
import Koerperbild
import Sensorik
import Testing
@testable import FitnessMember

/// Das Kamera-Modell des Flows mit einer Test-Bildquelle (`TestBildquelle` aus den KameraAblaufModellTests)
/// und einer Uhr, die der Test vorstellt. Der Leerlauf-Takt ist aus; `leerlaufPruefen()` ruft der Test selbst.
@MainActor
struct FlowKameraModellTests {
    /// Kniebeuge: 2 s senken, 1 s heben, Hub 90 Grad (170 -> 80).
    private static let kniebeuge = #","kamera":{"profil":"ganzkoerper_stehend","signal":"knie","seite":"links","beginntMit":"senken"},"tempo":{"senkenS":2,"haltenS":0,"hebenS":1}"#
    /// Eine zweite Kamera-Uebung mit anderer Vorgabe und anderem Tempo.
    private static let curl = #","kamera":{"profil":"oberkoerper","signal":"ellbogen","seite":"beide","beginntMit":"heben"},"tempo":{"senkenS":1,"haltenS":0,"hebenS":1}"#
    private static let tempo = Uebungstempo(senken: 2, halten: 0, heben: 1, beginntMit: .senken)
    private static let oben = 170.0
    private static let hub = 90.0
    private static let rate = 30.0
    private static let text = "Kamera sieht dich gerade nicht"

    private static func uebung(id: String, name: String, extra: String = "") -> String {
        #"{"id":"\#(id)","name":"\#(name)","volumeKind":"reps","targetMin":8,"targetMax":12\#(extra)}"#
    }

    private static let bootstrap: BootstrapResponse = GeraetTestdaten.dekodiere("""
    {"member":{"displayName":null,"goals":{"weeklyDays":null,"targetWeight":null}},
     "studios":[{"id":"s1","name":"Keller-Gym","timezone":"Europe/Berlin"}],
     "machines":[],"calibrations":[],"lastSets":[],
     "catalog":{"studioId":"s1","equipmentTypes":[
       {"id":"em2","name":"Eigengewicht","manufacturer":null,"photoPath":null,"category":"kraft","loadUnit":"kg",
        "loadStep":1,"loadMin":0,"loadMax":null,"settingDefinitions":[],
        "exercises":[\(uebung(id: "knie", name: "Kniebeuge", extra: kniebeuge)),
                     \(uebung(id: "curl", name: "Curl", extra: curl)),
                     \(uebung(id: "video", name: "Plank"))]}]}}
    """)

    private static let uebungen = FlowUebungen(bootstrap: bootstrap, testprofile: false)

    private static func schritt(_ position: Int, _ exerciseId: String?, name: String) -> FlowSchritt {
        FlowSchritt(position: position, name: name, beschreibung: nil, workS: 40, restS: 20, istWarmup: false,
                    exerciseId: exerciseId)
    }

    /// 0 Kniebeuge (Kamera), 1 Plank (Video), 2 Kniebeuge (Kamera), 3 Curl (Kamera), 4 ohne Verweis.
    private static let flowMitKamera = Flow(
        id: "f1", studioId: "s1", key: "k", titel: "HIIT", beschreibung: nil, level: nil,
        schritte: [schritt(1, "knie", name: "Kniebeuge"), schritt(2, "video", name: "Plank"),
                   schritt(3, "knie", name: "Kniebeuge"), schritt(4, "curl", name: "Curl"),
                   schritt(5, nil, name: "Auslaufen")],
        dauerS: 300)

    private static let flowOhneKamera = Flow(
        id: "f2", studioId: "s1", key: "k2", titel: "Ruhig", beschreibung: nil, level: nil,
        schritte: [schritt(1, "video", name: "Plank"), schritt(2, nil, name: "Auslaufen")], dauerS: 120)

    /// Linke Seite im Bild, Kniewinkel `winkel` (Hueft-Knie-Fuss).
    private static func skelett(knie winkel: Double) -> Skelett {
        let a = winkel * .pi / 180
        let punkte: [Gelenk: Punkt] = [
            .schulterL: Punkt(x: 0.5, y: 0.2, sicherheit: 1),
            .hueftL: Punkt(x: 0.5, y: 0.5, sicherheit: 1),
            .knieL: Punkt(x: 0.5, y: 0.7, sicherheit: 1),
            .fussL: Punkt(x: 0.5 + 0.2 * sin(a), y: 0.7 - 0.2 * cos(a), sicherheit: 1),
        ]
        return Skelett(punkte: punkte, seitenverhaeltnis: 1)
    }

    @MainActor private final class Aufbau {
        let quelle = TestBildquelle()
        var erlaubnis: Kameraerlaubnis = .erlaubt
        var antwortAufAnfrage: Kameraerlaubnis = .erlaubt
        private(set) var anfragen = 0
        /// Fuer welche Starts die Quelle gebaut wurde.
        private(set) var gebautFuer: [KameraStart] = []
        /// Die Uhr des Modells und der Bilder.
        var t = 100.0
        var modell: FlowKameraModell!

        init(flow: Flow = FlowKameraModellTests.flowMitKamera,
             uebungen: FlowUebungen = FlowKameraModellTests.uebungen, leerlaufTakt: Duration? = nil) {
            modell = FlowKameraModell(
                flow: flow, uebungen: uebungen,
                quelle: { [unowned self] start in
                    gebautFuer.append(start)
                    return quelle
                },
                erlaubnis: { [unowned self] in erlaubnis },
                anfragen: { [unowned self] in
                    anfragen += 1
                    erlaubnis = antwortAufAnfrage
                    return antwortAufAnfrage
                },
                uhr: { [unowned self] in t },
                leerlaufTakt: leerlaufTakt)
        }

        /// Bilder fuer `sekunden`; `winkel` nil heisst: kein Skelett.
        func bilder(sekunden: Double, winkel: (Double) -> Double?) {
            let ende = t + sekunden
            while t < ende - 1e-9 {
                quelle.liefere(t: t, skelett: winkel(t).map { FlowKameraModellTests.skelett(knie: $0) })
                t += 1 / FlowKameraModellTests.rate
            }
        }

        func steht(sekunden: Double) { bilder(sekunden: sekunden) { _ in FlowKameraModellTests.oben } }

        /// Kniebeugen nach der Soll-Welle ab jetzt.
        func kniebeugen(sekunden: Double) {
            let los = t
            let welle = Sollwelle(vorgabe: FlowKameraModellTests.tempo.vorgabe)
            bilder(sekunden: sekunden) { FlowKameraModellTests.oben - FlowKameraModellTests.hub * welle.lage(bei: max(0, $0 - los)) }
        }

        /// Aufstellen bestanden: Kamera erlaubt, 1,1 s sicher im Bild.
        func bereitMitKamera() async {
            await modell.aufstellenBeginnen()
            steht(sekunden: 1.1)
        }

        func folge(_ zustand: FlowZustand, pausiert: Bool = false) async {
            await modell.folge(zustand, pausiert: pausiert)
        }

        /// Vom Vorlauf in die Arbeitsphase von `schritt` und `sekunden` Kniebeugen.
        func zaehleKniebeugen(schritt: Int, sekunden: Double) async {
            await folge(.pause(naechster: schritt, restS: 5))
            steht(sekunden: 5)
            await folge(.arbeit(schritt: schritt, restS: 40))
            kniebeugen(sekunden: sekunden)
        }
    }

    // MARK: Start

    @Test func flowOhneKameraSchrittIstSofortBereitOhneErlaubnisfrage() async {
        let a = Aufbau(flow: Self.flowOhneKamera)
        #expect(a.modell.start == .bereit)
        #expect(!a.modell.mitKamera)
        await a.modell.aufstellenBeginnen()
        await a.folge(.countdown(restS: 3))
        await a.folge(.arbeit(schritt: 0, restS: 40))
        await a.folge(.pause(naechster: 1, restS: 5))
        await a.folge(.arbeit(schritt: 1, restS: 40))
        await a.folge(.fertig)
        #expect(a.modell.start == .bereit)
        #expect(a.anfragen == 0)
        #expect(a.quelle.startAufrufe == 0)
        #expect(a.modell.zaehler == nil)
        #expect(a.modell.gezaehlt.isEmpty)
    }

    @Test func flowMitKameraSchrittBeginntMitAufstellen() {
        let a = Aufbau()
        #expect(a.modell.start == .aufstellen)
        #expect(!a.modell.mitKamera)
        #expect(a.quelle.startAufrufe == 0)
    }

    @Test func erlaubnisVerweigertDannOhneKameraStarten() async {
        let a = Aufbau()
        a.erlaubnis = .verweigert
        await a.modell.aufstellenBeginnen()
        #expect(a.modell.start == .erlaubnisFehlt)
        #expect(a.anfragen == 0)
        #expect(a.quelle.startAufrufe == 0)
        #expect(!a.modell.mitKamera)

        a.modell.ohneKameraStarten()
        #expect(a.modell.start == .ohneKamera)
        #expect(!a.modell.mitKamera)
    }

    @Test func erlaubnisAnfrageAbgelehntIstErlaubnisFehlt() async {
        let a = Aufbau()
        a.erlaubnis = .offen
        a.antwortAufAnfrage = .verweigert
        await a.modell.aufstellenBeginnen()
        #expect(a.anfragen == 1)
        #expect(a.modell.start == .erlaubnisFehlt)
        #expect(a.quelle.startAufrufe == 0)
    }

    @Test func aufstellenBestehtNachEinerSekundeUndStopptDieQuelle() async {
        let a = Aufbau()
        a.erlaubnis = .offen
        await a.modell.aufstellenBeginnen()
        #expect(a.anfragen == 1)
        #expect(a.modell.start == .aufstellen)
        #expect(a.quelle.laeuft)
        // Geprueft wird stehend mit ganzkoerper_stehend, unabhaengig vom ersten Kamera-Schritt.
        #expect(a.gebautFuer.last?.vorgabe.profil == .ganzkoerperStehend)

        a.steht(sekunden: 0.9)
        #expect(a.modell.start == .aufstellen)
        #expect(a.modell.letztesSkelett != nil)
        a.steht(sekunden: 0.2)
        #expect(a.modell.start == .bereit)
        #expect(a.modell.mitKamera)
        #expect(!a.quelle.laeuft)
        #expect(a.quelle.stoppAufrufe >= 1)
    }

    @Test func aufstellenOhneSkelettBestehtNicht() async {
        let a = Aufbau()
        await a.modell.aufstellenBeginnen()
        a.bilder(sekunden: 3) { _ in nil }
        #expect(a.modell.start == .aufstellen)
        a.modell.ohneKameraStarten()
        #expect(a.modell.start == .ohneKamera)
        #expect(!a.quelle.laeuft)
    }

    #if DEBUG
    /// Mit Testprofilen kennt der erste Kamera-Schritt seinen Katalogschluessel; das Aufstellen
    /// baut die Quelle schon damit, und der erste Kamera-Schritt nutzt dieselbe Quelle weiter.
    @Test func aufstellenGibtDerQuelleDenKatalogschluesselDesErstenKameraSchritts() async {
        let bootstrap: BootstrapResponse = GeraetTestdaten.dekodiere("""
        {"member":{"displayName":null,"goals":{"weeklyDays":null,"targetWeight":null}},
         "studios":[{"id":"s1","name":"Keller-Gym","timezone":"Europe/Berlin"}],
         "machines":[],"calibrations":[],"lastSets":[],
         "catalog":{"studioId":"s1","equipmentTypes":[
           {"id":"em2","name":"Eigengewicht","manufacturer":null,"photoPath":null,"category":"kraft","loadUnit":"kg",
            "loadStep":1,"loadMin":0,"loadMax":null,"settingDefinitions":[],
            "exercises":[\(Self.uebung(id: "lunge", name: "Ausfallschritt – rückwärts"))]}]}}
        """)
        let flow = Flow(id: "f3", studioId: "s1", key: "k3", titel: "Lunge", beschreibung: nil, level: nil,
                        schritte: [Self.schritt(1, "lunge", name: "Ausfallschritt rückwärts")], dauerS: 60)
        let a = Aufbau(flow: flow, uebungen: FlowUebungen(bootstrap: bootstrap, testprofile: true))
        await a.modell.aufstellenBeginnen()
        #expect(a.gebautFuer.count == 1)
        #expect(a.gebautFuer.first?.katalogKey == "bw_reverse_lunge")
        a.steht(sekunden: 1.1)
        await a.folge(.pause(naechster: 0, restS: 5))
        #expect(a.gebautFuer.count == 1)
    }
    #endif

    @Test func quelleWirftBeimAufstellenIstKameraFehlt() async {
        let a = Aufbau()
        a.quelle.startFehler = BildquellenFehler.nichtVerfuegbar
        await a.modell.aufstellenBeginnen()
        #expect(a.modell.start == .kameraFehlt)
        a.modell.ohneKameraStarten()
        #expect(a.modell.start == .ohneKamera)
    }

    // MARK: Vorlauf und Arbeit

    @Test func kameraStartetFuenfSekundenVorEndeDerPauseUndZaehltInDerArbeit() async {
        let a = Aufbau()
        await a.bereitMitKamera()
        await a.folge(.pause(naechster: 2, restS: 6))
        #expect(!a.quelle.laeuft)
        let startsVorher = a.quelle.startAufrufe

        await a.folge(.pause(naechster: 2, restS: 5))
        #expect(a.quelle.laeuft)
        #expect(a.quelle.startAufrufe == startsVorher + 1)
        #expect(a.modell.zaehler == nil)
        #expect(a.gebautFuer.last?.exerciseId == "knie")
        a.steht(sekunden: 5)
        #expect(a.modell.letztesSkelett != nil)

        await a.folge(.arbeit(schritt: 2, restS: 40))
        #expect(a.modell.zaehler != nil)
        #expect(a.quelle.startAufrufe == startsVorher + 1)
        a.kniebeugen(sekunden: 10)
        #expect((a.modell.zaehler?.wiederholungen ?? 0) >= 2)
        #expect(a.modell.hinweis == nil)
        #expect(a.modell.ziel.ebene === a.quelle.anzeige)
    }

    @Test func countdownIstDerVorlaufVorSchrittEins() async {
        let a = Aufbau()
        await a.bereitMitKamera()
        await a.folge(.countdown(restS: 3))
        #expect(a.quelle.laeuft)
        #expect(a.modell.zaehler == nil)
        await a.folge(.arbeit(schritt: 0, restS: 40))
        #expect(a.modell.zaehler != nil)
    }

    @Test func pauseNachDemSchrittStopptUndMerktDieZahl() async {
        let a = Aufbau()
        await a.bereitMitKamera()
        await a.zaehleKniebeugen(schritt: 2, sekunden: 10)
        let zahl = a.modell.zaehler?.wiederholungen ?? -1
        #expect(zahl >= 2)

        await a.folge(.pause(naechster: 3, restS: 20))
        #expect(!a.quelle.laeuft)
        #expect(a.modell.zaehler == nil)
        #expect(a.modell.gezaehlt[2] == zahl)
        #expect(a.modell.letztesSkelett == nil)
    }

    @Test func videoSchrittHatKeineKamera() async {
        let a = Aufbau()
        await a.bereitMitKamera()
        await a.folge(.pause(naechster: 1, restS: 3))
        #expect(!a.quelle.laeuft)
        await a.folge(.arbeit(schritt: 1, restS: 40))
        #expect(!a.quelle.laeuft)
        #expect(a.modell.zaehler == nil)
        await a.folge(.arbeit(schritt: 4, restS: 40))
        #expect(!a.quelle.laeuft)
        #expect(a.modell.gezaehlt.isEmpty)
    }

    /// Review Focus 4
    @Test func zweiKameraSchritteHintereinanderMitEigenerVorgabe() async {
        let a = Aufbau()
        await a.bereitMitKamera()
        await a.zaehleKniebeugen(schritt: 2, sekunden: 10)
        let erste = a.modell.zaehler?.wiederholungen ?? -1
        #expect(erste >= 2)
        #expect(a.modell.zaehler?.vorgabe.profil == .ganzkoerperStehend)

        await a.folge(.pause(naechster: 3, restS: 5))
        #expect(a.modell.gezaehlt[2] == erste)
        #expect(a.modell.zaehler == nil)
        #expect(a.quelle.laeuft)
        #expect(a.gebautFuer.last?.exerciseId == "curl")
        a.steht(sekunden: 5)

        await a.folge(.arbeit(schritt: 3, restS: 40))
        let zweiter = a.modell.zaehler
        #expect(zweiter?.wiederholungen == 0)
        #expect(zweiter?.vorgabe.profil == .oberkoerper)
        #expect(zweiter?.vorgabe.signal == .ellbogen)
        #expect(zweiter?.tempo == Uebungstempo(senken: 1, halten: 0, heben: 1, beginntMit: .heben))
        a.steht(sekunden: 2)

        await a.folge(.arbeit(schritt: 4, restS: 40))
        #expect(a.modell.gezaehlt[2] == erste)
        #expect(a.modell.gezaehlt[3] == 0)
        #expect(a.modell.gezaehlt.count == 2)
        #expect(!a.quelle.laeuft)
    }

    // MARK: Fehler

    /// Review Focus 3
    @Test func quelleWirftBeimStartGibtHinweisUndVersuchtEsBeimNaechstenSchritt() async {
        let a = Aufbau()
        await a.bereitMitKamera()
        a.quelle.startFehler = BildquellenFehler.nichtVerfuegbar
        let startsVorher = a.quelle.startAufrufe

        await a.folge(.countdown(restS: 3))
        #expect(a.quelle.startAufrufe == startsVorher + 1)
        #expect(!a.quelle.laeuft)
        #expect(a.modell.hinweis == Self.text)

        // Im selben Schritt kein neuer Versuch; die Uhr laeuft, der Zaehler steht bereit.
        await a.folge(.countdown(restS: 2))
        await a.folge(.arbeit(schritt: 0, restS: 40))
        #expect(a.quelle.startAufrufe == startsVorher + 1)
        #expect(a.modell.zaehler != nil)
        #expect(a.modell.hinweis == Self.text)

        await a.folge(.pause(naechster: 1, restS: 20))
        #expect(a.modell.gezaehlt[0] == nil)
        #expect(a.modell.hinweis == nil)

        a.quelle.startFehler = nil
        await a.folge(.pause(naechster: 2, restS: 5))
        #expect(a.quelle.startAufrufe == startsVorher + 2)
        #expect(a.quelle.laeuft)
        #expect(a.modell.hinweis == nil)
    }

    /// Review Focus 3
    @Test func ausfallNachDemStartGibtHinweisUndVersuchtEsBeimNaechstenSchritt() async {
        let a = Aufbau()
        await a.bereitMitKamera()
        await a.zaehleKniebeugen(schritt: 0, sekunden: 7)
        let zahl = a.modell.zaehler?.wiederholungen ?? -1
        let startsVorher = a.quelle.startAufrufe

        a.quelle.beiFehler?()
        #expect(!a.quelle.laeuft)
        #expect(a.modell.hinweis == Self.text)
        // Ein zweiter Ausfall-Ruf ist wirkungslos.
        a.quelle.beiFehler?()
        await a.folge(.arbeit(schritt: 0, restS: 30))
        #expect(a.quelle.startAufrufe == startsVorher)
        #expect(a.modell.zaehler?.wiederholungen == zahl)

        await a.folge(.pause(naechster: 1, restS: 20))
        #expect(a.modell.gezaehlt[0] == zahl)
        await a.folge(.pause(naechster: 2, restS: 5))
        #expect(a.quelle.startAufrufe == startsVorher + 1)
        #expect(a.quelle.laeuft)
        #expect(a.modell.hinweis == nil)
    }

    @Test func nichtErkanntGibtHinweisUndErkennungNimmtIhnZurueck() async {
        let a = Aufbau()
        await a.bereitMitKamera()
        await a.folge(.pause(naechster: 0, restS: 5))
        await a.folge(.arbeit(schritt: 0, restS: 40))
        a.bilder(sekunden: 3.2) { _ in nil }
        #expect(a.modell.hinweis == Self.text)
        a.steht(sekunden: 1.5)
        #expect(a.modell.hinweis == nil)
    }

    @Test func ohneBilderLaeuftDieWelleUndDerHinweisKommt() async {
        let a = Aufbau()
        await a.bereitMitKamera()
        a.quelle.startFehler = BildquellenFehler.nichtVerfuegbar
        await a.folge(.pause(naechster: 0, restS: 5))
        a.quelle.startFehler = nil
        await a.folge(.arbeit(schritt: 0, restS: 40))
        // Keine Bilder: der Leerlauf speist die Uhr in den Zaehler.
        for _ in 0..<14 {
            a.t += 0.25
            a.modell.leerlaufPruefen()
        }
        #expect((a.modell.zaehler?.sollzeit ?? 0) >= 3.4)
        #expect(a.modell.zaehler?.erkannt == false)
        #expect(a.modell.hinweis == Self.text)
    }

    @Test func leerlaufStoertLaufendeBilderNicht() async {
        let a = Aufbau()
        await a.bereitMitKamera()
        await a.zaehleKniebeugen(schritt: 0, sekunden: 4)
        let sollzeit = a.modell.zaehler?.sollzeit ?? 0
        a.modell.leerlaufPruefen()
        #expect(a.modell.zaehler?.sollzeit == sollzeit)
        #expect(a.modell.zaehler?.erkannt == true)
    }

    // MARK: Anhalten

    /// Review Focus 2
    @Test func angehaltenZaehltNichtWeiterFortgesetztSchon() async {
        let a = Aufbau()
        await a.bereitMitKamera()
        await a.zaehleKniebeugen(schritt: 0, sekunden: 7)
        let vorher = a.modell.zaehler?.wiederholungen ?? -1
        #expect(vorher >= 1)

        await a.folge(.arbeit(schritt: 0, restS: 33), pausiert: true)
        a.kniebeugen(sekunden: 9)
        a.modell.leerlaufPruefen()
        #expect(a.modell.zaehler?.wiederholungen == vorher)
        #expect(a.quelle.laeuft)

        await a.folge(.arbeit(schritt: 0, restS: 33), pausiert: false)
        a.steht(sekunden: 1.5)
        a.kniebeugen(sekunden: 10)
        #expect((a.modell.zaehler?.wiederholungen ?? 0) > vorher)
    }

    // MARK: Hintergrund und Ende

    /// Review Focus 1
    @Test func sprungAusDerArbeitUeberEinenSchrittHinweg() async {
        let a = Aufbau()
        await a.bereitMitKamera()
        await a.zaehleKniebeugen(schritt: 0, sekunden: 7)
        let zahl = a.modell.zaehler?.wiederholungen ?? -1
        a.modell.schliessen()
        #expect(!a.quelle.laeuft)
        #expect(a.modell.letztesSkelett == nil)

        await a.folge(.pause(naechster: 2, restS: 15))
        #expect(!a.quelle.laeuft)
        #expect(a.modell.gezaehlt[0] == zahl)
        #expect(a.modell.zaehler == nil)
    }

    @Test func hintergrundImSchrittStartetBeimZurueckkommenNeuUndZaehltWeiter() async {
        let a = Aufbau()
        await a.bereitMitKamera()
        await a.zaehleKniebeugen(schritt: 0, sekunden: 7)
        let zahl = a.modell.zaehler?.wiederholungen ?? -1
        let startsVorher = a.quelle.startAufrufe

        a.modell.schliessen()
        #expect(!a.quelle.laeuft)
        a.t += 2
        await a.folge(.arbeit(schritt: 0, restS: 25))
        #expect(a.quelle.laeuft)
        #expect(a.quelle.startAufrufe == startsVorher + 1)
        #expect(a.modell.zaehler?.wiederholungen == zahl)
    }

    /// Fix-Runde 1: In `.inactive` tickt die Uhr weiter; `folge` darf die Kamera dann nicht wieder starten.
    @Test func nichtAktivStartetDieKameraNichtUndRueckkehrStartetSieOhneSperre() async {
        let a = Aufbau()
        await a.bereitMitKamera()
        await a.folge(.pause(naechster: 0, restS: 5))
        #expect(a.quelle.laeuft)
        let startsVorher = a.quelle.startAufrufe

        a.modell.szeneAktiv(false)
        #expect(!a.quelle.laeuft)
        await a.folge(.pause(naechster: 0, restS: 4))
        await a.folge(.arbeit(schritt: 0, restS: 40))
        #expect(!a.quelle.laeuft)
        #expect(a.quelle.startAufrufe == startsVorher)
        // Ein Ausfall, der waehrend des Hintergrunds eintrifft, sperrt den Schritt nicht.
        a.quelle.beiFehler?()

        a.modell.szeneAktiv(true)
        await a.folge(.arbeit(schritt: 0, restS: 39))
        #expect(a.quelle.laeuft)
        #expect(a.quelle.startAufrufe == startsVorher + 1)
        #expect(a.modell.hinweis == nil)
        a.steht(sekunden: 1.5)
        a.kniebeugen(sekunden: 7)
        #expect((a.modell.zaehler?.wiederholungen ?? 0) >= 1)
    }

    /// Fix-Runde 1: Ein Start, der in `.inactive` mit Fehler zurueckkommt, sperrt den Schritt nicht.
    @Test func fehlerWaehrendNichtAktivSperrtDenSchrittNicht() async {
        let a = Aufbau()
        await a.bereitMitKamera()
        await a.folge(.pause(naechster: 0, restS: 5))
        a.modell.szeneAktiv(false)
        a.quelle.startFehler = BildquellenFehler.nichtVerfuegbar
        await a.folge(.arbeit(schritt: 0, restS: 40))
        #expect(a.modell.hinweis == nil)
        a.quelle.startFehler = nil
        a.modell.szeneAktiv(true)
        await a.folge(.arbeit(schritt: 0, restS: 39))
        #expect(a.quelle.laeuft)
    }

    @Test func aufstellenStartetNichtWaehrendNichtAktiv() async {
        let a = Aufbau()
        a.modell.szeneAktiv(false)
        await a.modell.aufstellenBeginnen()
        #expect(a.quelle.startAufrufe == 0)
        #expect(a.modell.start == .aufstellen)
        a.modell.szeneAktiv(true)
        await a.modell.aufstellenBeginnen()
        #expect(a.quelle.laeuft)
    }

    /// Fix-Runde 1: `schliessen()` beendet den Leerlauf-Takt; die naechste Arbeitsphase startet ihn wieder.
    @Test func schliessenBeendetDenLeerlaufUndFolgeStartetIhnWieder() async {
        let a = Aufbau(leerlaufTakt: .seconds(60))
        await a.bereitMitKamera()
        await a.zaehleKniebeugen(schritt: 0, sekunden: 2)
        #expect(a.modell.leerlaufLaeuft)
        a.modell.schliessen()
        #expect(!a.modell.leerlaufLaeuft)
        await a.folge(.arbeit(schritt: 0, restS: 30))
        #expect(a.modell.leerlaufLaeuft)
        await a.folge(.pause(naechster: 1, restS: 20))
        #expect(!a.modell.leerlaufLaeuft)
    }

    @Test func fertigStopptDieKamera() async {
        let a = Aufbau()
        await a.bereitMitKamera()
        await a.zaehleKniebeugen(schritt: 3, sekunden: 3)
        #expect(a.quelle.laeuft)
        await a.folge(.fertig)
        #expect(!a.quelle.laeuft)
        #expect(a.modell.zaehler == nil)
        #expect(a.modell.gezaehlt[3] != nil)
    }

    @Test func ohneKameraWirdDieQuelleNieGestartet() async {
        let a = Aufbau()
        a.modell.ohneKameraStarten()
        #expect(!a.modell.mitKamera)
        await a.folge(.countdown(restS: 3))
        await a.folge(.arbeit(schritt: 0, restS: 40))
        await a.folge(.pause(naechster: 2, restS: 5))
        await a.folge(.arbeit(schritt: 2, restS: 40))
        await a.folge(.fertig)
        #expect(a.quelle.startAufrufe == 0)
        #expect(a.modell.zaehler == nil)
        #expect(a.modell.gezaehlt.isEmpty)
    }

    // MARK: Reine Helfer

    @Test func sollJeZustand() {
        let kamera: (Int) -> Bool = { [0, 2, 3].contains($0) }
        #expect(FlowKameraPlan.soll(.countdown(restS: 3), kameraSchritt: kamera) == .vorlauf(0))
        #expect(FlowKameraPlan.soll(.pause(naechster: 2, restS: 6), kameraSchritt: kamera) == .aus)
        #expect(FlowKameraPlan.soll(.pause(naechster: 2, restS: 5), kameraSchritt: kamera) == .vorlauf(2))
        #expect(FlowKameraPlan.soll(.pause(naechster: 1, restS: 2), kameraSchritt: kamera) == .aus)
        #expect(FlowKameraPlan.soll(.arbeit(schritt: 3, restS: 1), kameraSchritt: kamera) == .zaehlen(3))
        #expect(FlowKameraPlan.soll(.arbeit(schritt: 1, restS: 30), kameraSchritt: kamera) == .aus)
        #expect(FlowKameraPlan.soll(.fertig, kameraSchritt: kamera) == .aus)
    }

    @Test func fertigZeilenInSchrittfolge() {
        let zeilen = FlowKameraPlan.fertigZeilen(schritte: Self.flowMitKamera.schritte, gezaehlt: [3: 8, 0: 14, 9: 1])
        #expect(zeilen == [FlowFertigZeile(schrittIndex: 0, name: "Kniebeuge", wiederholungen: 14),
                           FlowFertigZeile(schrittIndex: 3, name: "Curl", wiederholungen: 8)])
        #expect(FlowKameraPlan.fertigZeilen(schritte: Self.flowMitKamera.schritte, gezaehlt: [:]).isEmpty)
    }
}
