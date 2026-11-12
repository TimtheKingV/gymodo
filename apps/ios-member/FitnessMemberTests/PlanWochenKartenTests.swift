import Foundation
import Testing
@testable import FitnessMember

/// Die Texte der Wochenkarten im Plan-Tab (Spec P2 §3 Punkt 4/5): Europe/Berlin,
/// Woche ab Mo 9.11.2026.
struct PlanWochenKartenTests {
    private static let kalender: Calendar = {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: "Europe/Berlin")!
        k.firstWeekday = 1 // Sonntag: die Texte duerfen davon nicht abhaengen
        return k
    }()

    private static func tag(_ t: Int, stunde: Int = 0, minute: Int = 0) -> Date {
        kalender.date(from: DateComponents(year: 2026, month: 11, day: t, hour: stunde, minute: minute))!
    }

    private func position(_ i: Int) -> TrainingsplanPosition {
        TrainingsplanPosition(
            key: "\(i)", baustein: "druecken", rolle: "haupt", exerciseId: "e\(i)", modelId: "m\(i)",
            typ: "mehrgelenk", saetze: 3, wdhVon: 8, wdhBis: 12, reserveVon: 1, reserveBis: 2, pauseSek: 90,
            aufwaermsatz: false, dauerMin: nil, hauptmuskeln: [])
    }

    private var einheiten: [TrainingsplanEinheit] {
        [TrainingsplanEinheit(key: "A", positionen: (0..<6).map(position), geschaetzteMinuten: 55),
         TrainingsplanEinheit(key: "B", positionen: (0..<7).map(position), geschaetzteMinuten: 62.6),
         TrainingsplanEinheit(key: "C", positionen: [position(0)], geschaetzteMinuten: nil)]
    }

    private func karte(
        _ art: WochenKarte.Art, am: Date? = nil, quelle: WochenKarte.Quelle = .keine,
        naechste: Bool = false, minuten: Int? = nil
    ) -> WochenKarte {
        WochenKarte(id: "x", art: art, erledigtAm: am, quelle: quelle, istNaechste: naechste, minuten: minuten)
    }

    private func untertitel(_ k: WochenKarte, herkunft: PlanWochenKarten.CardioHerkunft? = nil) -> String {
        PlanWochenKarten.untertitel(k, einheiten: einheiten, kalender: Self.kalender, herkunft: herkunft)
    }

    private func kurs(_ startsAt: String) -> CourseWeekSession {
        CourseWeekSession(
            sessionId: "k1", templateId: "t", name: "Yoga Flow", description: nil, startsAt: startsAt,
            localDay: String(startsAt.prefix(10)), durationMin: 60, capacity: 10, room: nil, instructorName: nil,
            status: "planned", bookedCount: 3, waitlistCount: 0, freeSeats: 7, ownStatus: "booked",
            ownBookingId: "b", ownWaitlistPosition: nil)
    }

    // MARK: - Kraft

    @Test func kraftErledigtNenntTagUndDauer() {
        let k = karte(.kraft(einheitKey: "A"), am: Self.tag(9, stunde: 18), quelle: .sitzung(id: "s1"), minuten: 58)
        #expect(untertitel(k) == "erledigt Mo, 9. · 58 min")
    }

    @Test func freiesTrainingErledigtOhneDauer() {
        let k = karte(.kraft(einheitKey: nil), am: Self.tag(15, stunde: 23, minute: 30), quelle: .sitzung(id: "s2"))
        #expect(untertitel(k) == "erledigt So, 15.")
    }

    @Test func kraftOffenNenntUebungenUndGeschaetzteMinuten() {
        #expect(untertitel(karte(.kraft(einheitKey: "B"), naechste: true)) == "7 Übungen · ca. 63 min")
        #expect(untertitel(karte(.kraft(einheitKey: "A"))) == "6 Übungen · ca. 55 min")
        #expect(untertitel(karte(.kraft(einheitKey: "C"))) == "1 Übung")
    }

    @Test func kraftTitel() {
        let namen = EinheitNamen(bootstrap: nil)
        #expect(PlanWochenKarten.titel(karte(.kraft(einheitKey: "B")), namen: namen) == "Kraft B")
        #expect(PlanWochenKarten.titel(karte(.kraft(einheitKey: nil), am: Self.tag(9)), namen: namen)
                == "Freies Training")
        #expect(PlanWochenKarten.titel(karte(.cardio, minuten: 30), namen: namen) == "Cardio · 30 min")
        #expect(PlanWochenKarten.titel(karte(.cardio, am: Self.tag(10), quelle: .hand(checkId: "c")), namen: namen)
                == "Cardio")
    }

    // MARK: - Cardio

    @Test func cardioAusDerSitzungNenntHerkunftUndMinuten() {
        let k = karte(.cardio, am: Self.tag(11, stunde: 18), quelle: .sitzung(id: "s3"), minuten: 32)
        #expect(untertitel(k, herkunft: .nachKraft(einheitKey: "B")) == "nach Kraft B · 32 min")
        #expect(untertitel(k, herkunft: .nachKraft(einheitKey: nil)) == "nach freiem Training · 32 min")
        #expect(untertitel(k, herkunft: .geraet("Ruderergometer")) == "Ruderergometer · 32 min")
        #expect(untertitel(k) == "32 min")
    }

    @Test func cardioVonHandNenntDenTag() {
        let k = karte(.cardio, am: Self.tag(10), quelle: .hand(checkId: "c1"))
        #expect(untertitel(k) == "abgehakt Di, 10.")
    }

    @Test func cardioOffen() {
        #expect(untertitel(karte(.cardio, minuten: 30)) == "zählt auch nach dem Krafttraining")
    }

    @Test func herkunftAusSitzungUndPlan() {
        func satz(_ cardio: CardioWerte?) -> SessionSummary.Block.Set {
            SessionSummary.Block.Set(
                setIndex: 0, load: nil, secondaryLoad: nil, volume: nil, rir: nil, problemFlag: false,
                problemReason: nil, performedAt: "2026-11-11T18:00:00+01:00", cardio: cardio)
        }
        func block(_ label: String, _ s: SessionSummary.Block.Set) -> SessionSummary.Block {
            SessionSummary.Block(
                machineId: nil, machineLabel: label, exerciseId: "e", exerciseName: label, loadUnit: .kg,
                secondaryUnit: nil, volumeKind: .reps, sets: [s])
        }
        func sitzung(_ id: String, _ bloecke: [SessionSummary.Block]) -> SessionSummary {
            SessionSummary(
                id: id, startedAt: "2026-11-11T18:00:00+01:00", completedAt: "2026-11-11T19:00:00+01:00",
                completedReason: "manual", machineCount: bloecke.count, setCount: bloecke.count, blocks: bloecke)
        }
        let rudern = block("Ruderergometer", satz(CardioWerte(zeit: 1860)))
        let presse = block("Brustpresse", satz(nil))
        let sitzungen = [sitzung("plan", [presse, rudern]), sitzung("frei", [presse, rudern]),
                         sitzung("nurCardio", [rudern])]
        let erledigt = [ErledigteEinheit(sessionId: "plan", einheitKey: "B", startedAt: "2026-11-11T18:00:00+01:00")]
        #expect(PlanWochenKarten.herkunft(sitzungId: "plan", sitzungen: sitzungen, erledigt: erledigt)
                == .nachKraft(einheitKey: "B"))
        #expect(PlanWochenKarten.herkunft(sitzungId: "frei", sitzungen: sitzungen, erledigt: erledigt)
                == .nachKraft(einheitKey: nil))
        #expect(PlanWochenKarten.herkunft(sitzungId: "nurCardio", sitzungen: sitzungen, erledigt: erledigt)
                == .geraet("Ruderergometer"))
        #expect(PlanWochenKarten.herkunft(sitzungId: "fehlt", sitzungen: sitzungen, erledigt: erledigt) == nil)
    }

    // MARK: - Kurs

    @Test func kursNenntUhrzeitImStudioKalender() {
        let k = karte(.kurs(kurs("2026-11-12T17:00:00Z")), minuten: 60)
        #expect(untertitel(k) == "18:00 · gebucht")
    }

    // MARK: - Kuenftige Woche

    @Test func ausblickNenntDasZiel() {
        #expect(PlanWochenKarten.ausblick(Wochenziel(kraft: 2, cardio: 1, cardioMinuten: 30))
                == "Diese Woche: 2× Kraft, 1× Cardio")
        #expect(PlanWochenKarten.ausblick(Wochenziel(kraft: 3, cardio: 0, cardioMinuten: 30))
                == "Diese Woche: 3× Kraft")
    }

    // MARK: - Wochenziel ohne Serverfeld

    @Test func wochenzielFaelltAufDieKraftTageDesPlansZurueck() {
        let server = Wochenziel(kraft: 3, cardio: 1, cardioMinuten: 40)
        let raster = [Rasterplatz(tag: 1, art: .kraft, einheitKey: "A"), Rasterplatz(tag: 3, art: .cardio, einheitKey: nil),
                      Rasterplatz(tag: 4, art: .kraft, einheitKey: "B"), Rasterplatz(tag: 6, art: .kraft, einheitKey: "A")]
        #expect(PlanKalenderKontext.wochenziel(server: server, raster: raster) == server)
        #expect(PlanKalenderKontext.wochenziel(server: nil, raster: raster)
                == Wochenziel(kraft: 3, cardio: 0, cardioMinuten: 30))
        #expect(PlanKalenderKontext.wochenziel(server: nil, raster: [])
                == Wochenziel(kraft: 2, cardio: 0, cardioMinuten: 30))
    }
}
