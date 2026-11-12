import Foundation
import Testing
@testable import FitnessMember

/// Zustand des Plan-Tabs: Woche Mo 26.10. bis So 1.11.2026 (Europe/Berlin).
struct PlanTabZustandTests {

    private static let kalender: Calendar = {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: "Europe/Berlin")!
        k.firstWeekday = 1 // Sonntag: Vorauswahl darf davon nicht abhaengen
        return k
    }()

    private static func tag(_ jahr: Int, _ monat: Int, _ tag: Int, stunde: Int = 0) -> Date {
        kalender.date(from: DateComponents(year: jahr, month: monat, day: tag, hour: stunde))!
    }

    private var woche: [Date] { (0..<7).map { Self.tag(2026, 10, 26 + $0) } }
    private var naechsteWoche: [Date] {
        (0..<7).map { Self.kalender.date(byAdding: .day, value: 7 + $0, to: Self.tag(2026, 10, 26))! }
    }

    // MARK: - Vorauswahl

    @Test func vorauswahlIstHeuteInDerLaufendenWoche() {
        let heute = Self.tag(2026, 10, 29, stunde: 15)
        #expect(PlanTabZustand.vorauswahl(tage: woche, heute: heute, kalender: Self.kalender)
            == Self.tag(2026, 10, 29))
    }

    @Test func vorauswahlIstMontagInEinerAnderenWoche() {
        let heute = Self.tag(2026, 10, 29, stunde: 15)
        #expect(PlanTabZustand.vorauswahl(tage: naechsteWoche, heute: heute, kalender: Self.kalender)
            == Self.tag(2026, 11, 2))
    }

    @Test func vorauswahlAmSonntagBleibtInDerWoche() {
        let heute = Self.tag(2026, 11, 1, stunde: 23)
        #expect(PlanTabZustand.vorauswahl(tage: woche, heute: heute, kalender: Self.kalender)
            == Self.tag(2026, 11, 1))
    }

    @Test func geltenderTagFaelltAusDerWocheZurueckAufVorauswahl() {
        let heute = Self.tag(2026, 10, 29, stunde: 8)
        let zustand = PlanTabZustand(gewaehlterTag: Self.tag(2026, 10, 19))
        #expect(zustand.geltenderTag(tage: woche, heute: heute, kalender: Self.kalender) == Self.tag(2026, 10, 29))
        let gewaehlt = PlanTabZustand(gewaehlterTag: Self.tag(2026, 10, 31))
        #expect(gewaehlt.geltenderTag(tage: woche, heute: heute, kalender: Self.kalender) == Self.tag(2026, 10, 31))
    }

    // MARK: - Filter

    @Test func unsichtbarerFilterFaelltAufAlleZurueck() {
        let sichtbar = PlanWoche.sichtbareFilter(hatPlan: true, hatKurse: false, hatCardio: true)
        #expect(PlanTabZustand(gewaehlterFilter: .kurse).geltenderFilter(sichtbar: sichtbar) == .alle)
        #expect(PlanTabZustand(gewaehlterFilter: .cardio).geltenderFilter(sichtbar: sichtbar) == .cardio)
        #expect(PlanTabZustand().geltenderFilter(sichtbar: sichtbar) == .alle)
    }

    @Test func ohneFilterleisteGiltAlle() {
        #expect(PlanTabZustand(gewaehlterFilter: .kraft).geltenderFilter(sichtbar: []) == .alle)
    }

    // MARK: - Anzeige-Raster (Profil-Tage vor Planraster)

    private let planRaster: [Rasterplatz] = [
        Rasterplatz(tag: 1, art: .kurs, einheitKey: nil),
        Rasterplatz(tag: 3, art: .kraft, einheitKey: "A"),
        Rasterplatz(tag: 5, art: .kraft, einheitKey: "B"),
        Rasterplatz(tag: 7, art: .cardio, einheitKey: nil),
    ]

    private func profil(kurs: [Int]? = nil, cardio: [Int]? = nil, kraft: [Int]? = nil) -> TrainingsplanProfil {
        TrainingsplanProfil(minutes: 60, experience: "neu", focus: [],
                            kursTage: kurs, cardioTage: cardio, kraftTage: kraft)
    }

    // MARK: - Bestandsplaene ohne Wochenraster (I3)

    @Test func bestandsplanOhneRasterUndLeeresProfilHatKeineKrafttage() {
        // Plaene von vor 1.3.0: wochenraster = [], Profilfelder leer.
        let raster = PlanTabZustand.anzeigeRaster(
            planRaster: [], einheiten: ["A", "B"], profil: profil(kurs: [], cardio: [], kraft: []))
        #expect(PlanTabZustand.hatKrafttage(anzeigeRaster: raster) == false)
        #expect(PlanTabZustand.hatKrafttage(anzeigeRaster: []) == false)
    }

    @Test func nurKursUndCardioSindKeineKrafttage() {
        let raster = PlanTabZustand.anzeigeRaster(
            planRaster: [], einheiten: ["A", "B"], profil: profil(kurs: [1], cardio: [7], kraft: []))
        #expect(raster.map(\.art) == [.kurs, .cardio])
        #expect(PlanTabZustand.hatKrafttage(anzeigeRaster: raster) == false)
    }

    @Test func normalesRasterHatKrafttage() {
        #expect(PlanTabZustand.hatKrafttage(anzeigeRaster: planRaster))
    }

    @Test func ohneProfilTageGiltDasPlanraster() {
        #expect(PlanTabZustand.anzeigeRaster(planRaster: planRaster, einheiten: ["A", "B"], profil: nil) == planRaster)
        #expect(PlanTabZustand.anzeigeRaster(planRaster: planRaster, einheiten: ["A", "B"], profil: profil())
            == planRaster)
    }

    @Test func leereProfilfelderGeltenAlsNichtGesetzt() {
        // So liefert der Server ein Profil ohne Einplanen (DB-Default '{}').
        let p = profil(kurs: [], cardio: [], kraft: [])
        #expect(PlanTabZustand.anzeigeRaster(planRaster: planRaster, einheiten: ["A", "B"], profil: p) == planRaster)
    }

    @Test func nurKursTageGesetztRestAusDemRaster() {
        let p = profil(kurs: [2], cardio: [], kraft: [])
        #expect(PlanTabZustand.anzeigeRaster(planRaster: planRaster, einheiten: ["A", "B"], profil: p) == [
            Rasterplatz(tag: 2, art: .kurs, einheitKey: nil),
            Rasterplatz(tag: 3, art: .kraft, einheitKey: "A"),
            Rasterplatz(tag: 5, art: .kraft, einheitKey: "B"),
            Rasterplatz(tag: 7, art: .cardio, einheitKey: nil),
        ])
    }

    @Test func kraftTageGesetztMachenLeereKursTageZuKeinen() {
        let p = profil(kurs: [], cardio: [7], kraft: [3, 5])
        #expect(PlanTabZustand.anzeigeRaster(planRaster: planRaster, einheiten: ["A", "B"], profil: p) == [
            Rasterplatz(tag: 3, art: .kraft, einheitKey: "A"),
            Rasterplatz(tag: 5, art: .kraft, einheitKey: "B"),
            Rasterplatz(tag: 7, art: .cardio, einheitKey: nil),
        ])
    }

    @Test func gleicheProfilTageAendernNichts() {
        let p = profil(kurs: [1], cardio: [7], kraft: [3, 5])
        #expect(PlanTabZustand.anzeigeRaster(planRaster: planRaster, einheiten: ["A", "B"], profil: p) == planRaster)
    }

    @Test func abweichendeProfilTageGeltenUndBehaltenDieFolge() {
        // Kraft auf Di/Do/Sa verlegt, Kurs auf Mi: die Folge A, B laeuft weiter (A, B, A).
        let p = profil(kurs: [3], cardio: [7], kraft: [2, 4, 6])
        #expect(PlanTabZustand.anzeigeRaster(planRaster: planRaster, einheiten: ["A", "B"], profil: p) == [
            Rasterplatz(tag: 2, art: .kraft, einheitKey: "A"),
            Rasterplatz(tag: 3, art: .kurs, einheitKey: nil),
            Rasterplatz(tag: 4, art: .kraft, einheitKey: "B"),
            Rasterplatz(tag: 6, art: .kraft, einheitKey: "A"),
            Rasterplatz(tag: 7, art: .cardio, einheitKey: nil),
        ])
    }

    @Test func nurEinFeldGesetztDieAnderenKommenAusDemRaster() {
        let p = profil(cardio: [6])
        #expect(PlanTabZustand.anzeigeRaster(planRaster: planRaster, einheiten: ["A", "B"], profil: p) == [
            Rasterplatz(tag: 1, art: .kurs, einheitKey: nil),
            Rasterplatz(tag: 3, art: .kraft, einheitKey: "A"),
            Rasterplatz(tag: 5, art: .kraft, einheitKey: "B"),
            Rasterplatz(tag: 6, art: .cardio, einheitKey: nil),
        ])
    }

    @Test func altplanOhneRasterFolgtDenEinheiten() {
        let p = profil(kraft: [1, 4])
        #expect(PlanTabZustand.anzeigeRaster(planRaster: [], einheiten: ["OK_A", "UK_A"], profil: p) == [
            Rasterplatz(tag: 1, art: .kraft, einheitKey: "OK_A"),
            Rasterplatz(tag: 4, art: .kraft, einheitKey: "UK_A"),
        ])
    }

    // MARK: - Woche, Als naechstes

    @Test func wochenTitelNenntKalenderwocheUndSpanne() {
        #expect(PlanTabZustand.wochenTitel(tage: woche, kalender: Self.kalender) == "KW 44 · 26. Okt – 1. Nov")
    }

    @Test func wochenTitelImSelbenMonatNenntDenMonatEinmal() {
        let tage = (0..<7).map { Self.kalender.date(from: DateComponents(year: 2026, month: 11, day: 9 + $0))! }
        #expect(PlanTabZustand.wochenTitel(tage: tage, kalender: Self.kalender) == "KW 46 · 9.–15. Nov")
    }

    @Test func alsNaechstesSindDieZweiFolgendenTermine() {
        let termine: [Date: [PlanTermin]] = [
            Self.tag(2026, 10, 28): [.einheit(key: "A", zustand: .geplant)],
            Self.tag(2026, 10, 30): [.einheit(key: "B", zustand: .geplant)],
            Self.tag(2026, 11, 1): [.cardio(arten: [], zustand: .geplant)],
        ]
        let naechste = PlanTabZustand.alsNaechstes(termine: termine, nach: Self.tag(2026, 10, 29), anzahl: 2)
        #expect(naechste.map(\.tag) == [Self.tag(2026, 10, 30), Self.tag(2026, 11, 1)])
        #expect(naechste.first?.termin == .einheit(key: "B", zustand: .geplant))
    }

    // MARK: - Woche anpassen (WochenAuswahl)

    private static let basis = TrainingsplanProfil(minutes: 45, experience: "neu", focus: ["po"])

    @Test func wochenAuswahlSendetNurDieZaehler() throws {
        let auswahl = WochenAuswahl(ziel: Wochenziel(kraft: 2, cardio: 1, cardioMinuten: 30), profil: nil)
        let json = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(auswahl.profil(aus: Self.basis))) as! [String: Any]
        #expect(json["kraftProWoche"] as? Int == 2)
        #expect(json["cardioProWoche"] as? Int == 1)
        #expect(json["cardioMinuten"] as? Int == 30)
        #expect(json["minutes"] as? Int == 45)
        #expect(json["kraftTage"] == nil)
        #expect(json["kursTage"] == nil)
        #expect(json["cardioTage"] == nil)
    }

    @Test func wochenAuswahlKlemmtAnDenGrenzen() {
        let tief = WochenAuswahl(ziel: Wochenziel(kraft: 0, cardio: -1, cardioMinuten: 5), profil: nil)
        #expect(tief.kraft == 1 && tief.cardio == 0 && tief.cardioMinuten == 10)
        let hoch = WochenAuswahl(ziel: Wochenziel(kraft: 9, cardio: 9, cardioMinuten: 95), profil: nil)
        #expect(hoch.kraft == 7 && hoch.cardio == 7 && hoch.cardioMinuten == 90)
        let krumm = WochenAuswahl(ziel: Wochenziel(kraft: 2, cardio: 1, cardioMinuten: 33), profil: nil)
        #expect(krumm.cardioMinuten == 35)
    }

    @Test func wochenAuswahlUebernimmtCardioArtenAusDemProfil() {
        let profil = TrainingsplanProfil(
            minutes: 45, experience: "neu", focus: ["po"], cardioArten: ["laufen"], kraftTage: [1, 3])
        var auswahl = WochenAuswahl(ziel: Wochenziel(kraft: 2, cardio: 1, cardioMinuten: 30), profil: profil)
        #expect(auswahl.cardioArten == ["laufen"])
        auswahl.cardioArtUmschalten("schwimmen")
        auswahl.cardioArtUmschalten("laufen")
        let neu = auswahl.profil(aus: profil)
        #expect(neu.cardioArten == ["schwimmen"])
        #expect(neu.kraftTage == nil)
    }

    // MARK: - Ansicht und Woche

    @Test func ansichtVorgabeWoche() {
        #expect(PlanTabZustand().ansicht == .woche)
    }

    /// Mit vergangenen Wochen ist die laufende nicht mehr die erste Seite:
    /// ohne Auswahl steht der Streifen trotzdem auf ihr.
    @Test func wochenIndexOhneAuswahlIstDieLaufendeWoche() {
        let montage = [Self.tag(2026, 10, 19), Self.tag(2026, 10, 26), Self.tag(2026, 11, 2)]
        let heute = Self.tag(2026, 10, 29, stunde: 9)
        #expect(PlanTabZustand.wochenIndex(montage: montage, tag: nil, heute: heute) == 1)
        #expect(PlanTabZustand.wochenIndex(montage: montage, tag: Self.tag(2026, 10, 21), heute: heute) == 0)
        #expect(PlanTabZustand.wochenIndex(montage: montage, tag: Self.tag(2026, 11, 8), heute: heute) == 2)
        // Vor der ersten Seite (alter Sprungtag): die laufende Woche, nicht die aelteste.
        #expect(PlanTabZustand.wochenIndex(montage: montage, tag: Self.tag(2026, 9, 1), heute: heute) == 1)
    }

    // MARK: - Monatsgitter

    /// November 2026 beginnt an einem Sonntag: sechs Vortage aus dem Oktober,
    /// volle Wochen bis So 6.12.; jeder Tag als Tagesbeginn im Plan-Kalender.
    @Test func monatsgitterFuelltVolleWochenImPlanKalender() {
        let tage = PlanMonatsgitterTage.tage(
            monat: Self.tag(2026, 11, 18, stunde: 15), heute: Self.tag(2026, 11, 4, stunde: 9), kalender: Self.kalender)
        #expect(tage.count == 42)
        #expect(tage.first?.datum == Self.tag(2026, 10, 26))
        #expect(tage.first?.zelle.ausserhalb == true)
        #expect(tage[6].datum == Self.tag(2026, 11, 1))
        #expect(tage[6].zelle.ausserhalb == false)
        #expect(tage.filter(\.zelle.istHeute).map(\.datum) == [Self.tag(2026, 11, 4)])
    }
}
