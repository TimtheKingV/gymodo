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
        #expect(PlanTabZustand(gewaehlterFilter: .einheiten).geltenderFilter(sichtbar: []) == .alle)
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

    @Test func ohneProfilTageGiltDasPlanraster() {
        #expect(PlanTabZustand.anzeigeRaster(planRaster: planRaster, einheiten: ["A", "B"], profil: nil) == planRaster)
        #expect(PlanTabZustand.anzeigeRaster(planRaster: planRaster, einheiten: ["A", "B"], profil: profil())
            == planRaster)
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

    @Test func alsNaechstesSindDieZweiFolgendenTermine() {
        let termine: [Date: [PlanTermin]] = [
            Self.tag(2026, 10, 28): [.einheit(key: "A", erledigt: false)],
            Self.tag(2026, 10, 30): [.einheit(key: "B", erledigt: false)],
            Self.tag(2026, 11, 1): [.cardio(arten: [], erledigt: false)],
        ]
        let naechste = PlanTabZustand.alsNaechstes(termine: termine, nach: Self.tag(2026, 10, 29), anzahl: 2)
        #expect(naechste.map(\.tag) == [Self.tag(2026, 10, 30), Self.tag(2026, 11, 1)])
        #expect(naechste.first?.termin == .einheit(key: "B", erledigt: false))
    }

    // MARK: - Einplanen (PlanWochentage)

    @Test func einTagGehoertHoechstensEinerArt() {
        var tage = PlanWochentage(raster: planRaster)
        tage.umschalten(3, fuer: .kurs) // Mi war Kraft A
        #expect(tage.kurs == [1, 3])
        #expect(tage.kraft == [5])
        tage.umschalten(3, fuer: .kurs) // zurueck: Mi frei
        #expect(tage.kurs == [1])
        #expect(tage.art(an: 3) == nil)
    }

    @Test func ohneKrafttagUngueltigUndProfilSendetAlleTage() {
        var tage = PlanWochentage(kraft: [2], kurs: [], cardio: [7])
        tage.umschalten(2, fuer: .cardio)
        #expect(!tage.istGueltig)
        let alt = TrainingsplanProfil(minutes: 45, experience: "neu", focus: ["po"], cardioArten: ["laufen"])
        let neu = PlanWochentage(kraft: [4, 2], kurs: [1], cardio: [7]).profil(aus: alt)
        #expect(neu.kraftTage == [2, 4])
        #expect(neu.kursTage == [1])
        #expect(neu.cardioTage == [7])
        #expect(neu.cardioArten == ["laufen"])
        #expect(neu.minutes == 45)
    }
}
