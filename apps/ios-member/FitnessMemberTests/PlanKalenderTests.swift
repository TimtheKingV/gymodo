import Foundation
import Testing
@testable import FitnessMember

/// Die Folge auf den Slots (Spec 1.3): Raster Kraft Mo/Di/Do, Cardio Sa,
/// Einheiten A/B/C, Europe/Berlin, Tage Mo 26.10. bis Mo 9.11.2026,
/// Planbeginn Mo 26.10., heute Mi 4.11.
struct PlanKalenderTests {
    private static let kalender: Calendar = {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: "Europe/Berlin")!
        k.firstWeekday = 1 // Sonntag: das Mapping darf davon nicht abhaengen
        return k
    }()

    private static func tag(_ monat: Int, _ t: Int, stunde: Int = 0) -> Date {
        kalender.date(from: DateComponents(year: 2026, month: monat, day: t, hour: stunde))!
    }

    private var tage: [Date] { (0..<15).map { Self.kalender.date(byAdding: .day, value: $0, to: Self.tag(10, 26))! } }

    private let raster: [Rasterplatz] = [
        Rasterplatz(tag: 1, art: .kraft, einheitKey: "A"),
        Rasterplatz(tag: 2, art: .kraft, einheitKey: "B"),
        Rasterplatz(tag: 4, art: .kraft, einheitKey: "C"),
        Rasterplatz(tag: 6, art: .cardio, einheitKey: nil),
    ]

    private func erledigt(_ key: String, _ zeitpunkt: String) -> ErledigteEinheit {
        ErledigteEinheit(sessionId: "s-\(key)-\(zeitpunkt)", einheitKey: key, startedAt: zeitpunkt)
    }

    private func kurs(_ tag: String, stunde: Int, own: String? = "booked") -> CourseWeekSession {
        CourseWeekSession(
            sessionId: "k-\(tag)", templateId: "t", name: "Zirkel", description: nil,
            startsAt: "\(tag)T\(String(format: "%02d", stunde)):00:00Z", localDay: tag, durationMin: 60,
            capacity: 10, room: nil, instructorName: nil, status: "planned", bookedCount: 3, waitlistCount: 0,
            freeSeats: 7, ownStatus: own, ownBookingId: own == nil ? nil : "b", ownWaitlistPosition: nil)
    }

    private func termine(
        raster: [Rasterplatz]? = nil, naechste: String? = nil, erledigt: [ErledigteEinheit] = [],
        trainiertAn: Set<String> = [], beginn: Date? = PlanKalenderTests.tag(10, 26, stunde: 9),
        verlaufAb: Date? = PlanKalenderTests.tag(10, 26),
        heute: Date = PlanKalenderTests.tag(11, 4, stunde: 10), kurse: [CourseWeekSession] = [],
        cardio: Set<String> = [], filter: PlanFilter = .alle
    ) -> [Date: [PlanTermin]] {
        PlanKalender.termine(
            tage: tage, kalender: Self.kalender, raster: raster ?? self.raster, einheiten: ["A", "B", "C"],
            naechsteEinheitKey: naechste, erledigt: erledigt, trainiertAn: trainiertAn, beginn: beginn,
            verlaufAb: verlaufAb, heute: heute, kurse: kurse, cardioErledigt: cardio, filter: filter)
    }

    @Test func verpasstVerschiebtAufNaechstenKraftSlot() {
        let t = termine(naechste: "B", erledigt: [erledigt("A", "2026-11-02T17:00:00Z")],
                        trainiertAn: ["2026-11-02"])
        #expect(t[Self.tag(11, 2)] == [.einheit(key: "A", zustand: .erledigt)])
        #expect(t[Self.tag(11, 3)] == [.einheit(key: "B", zustand: .verpasst(verschobenAuf: Self.tag(11, 5)))])
        #expect(t[Self.tag(11, 4)] == nil)
        #expect(t[Self.tag(11, 5)] == [.einheit(key: "B", zustand: .geplant)])
        #expect(t[Self.tag(11, 7)] == [.cardio(arten: [], zustand: .geplant)])
        #expect(t[Self.tag(11, 9)] == [.einheit(key: "C", zustand: .geplant)])
    }

    @Test func heuteNieVerpasst() {
        let t = termine(heute: Self.tag(11, 5, stunde: 20))
        guard case .einheit(_, let zustand)? = t[Self.tag(11, 5)]?.first else {
            Issue.record("Donnerstag zeigt keine Einheit"); return
        }
        #expect(zustand == .geplant)
    }

    @Test func erledigtAnNichtSlotTag() {
        let t = termine(
            naechste: "C",
            erledigt: [erledigt("A", "2026-11-02T17:00:00Z"), erledigt("B", "2026-11-04T07:00:00+00:00")],
            trainiertAn: ["2026-11-02", "2026-11-04"])
        #expect(t[Self.tag(11, 4)] == nil)
        #expect(t[Self.tag(11, 3)] == [.einheit(key: "B", zustand: .verpasst(verschobenAuf: nil))])
        #expect(t[Self.tag(11, 5)] == [.einheit(key: "C", zustand: .geplant)])
        #expect(t[Self.tag(11, 9)] == [.einheit(key: "A", zustand: .geplant)])
    }

    @Test func zweiTrainingsAmSlotTag() {
        let t = termine(
            naechste: "C",
            erledigt: [erledigt("A", "2026-11-02T08:00:00Z"), erledigt("B", "2026-11-02T17:30:00.123Z")],
            trainiertAn: ["2026-11-02"])
        #expect(t[Self.tag(11, 2)] == [.einheit(key: "A", zustand: .erledigt)])
        #expect(t[Self.tag(11, 3)] == [.einheit(key: "C", zustand: .verpasst(verschobenAuf: Self.tag(11, 5)))])
        #expect(t[Self.tag(11, 5)] == [.einheit(key: "C", zustand: .geplant)])
    }

    @Test func freiesTrainingAmSlotTag() {
        let t = termine(naechste: "B", erledigt: [erledigt("A", "2026-11-02T17:00:00Z")],
                        trainiertAn: ["2026-11-02", "2026-11-03"])
        #expect(t[Self.tag(11, 3)] == nil)
        #expect(t[Self.tag(11, 5)] == [.einheit(key: "B", zustand: .geplant)])
        #expect(t[Self.tag(11, 9)] == [.einheit(key: "C", zustand: .geplant)])
    }

    @Test func vorBeginnKeineSlots() {
        let t = termine(beginn: Self.tag(11, 2, stunde: 18))
        for tag in tage.prefix(7) { #expect(t[tag] == nil) }
        // Am Beginntag selbst zaehlt der Slot.
        #expect(t[Self.tag(11, 2)] == [.einheit(key: "A", zustand: .verpasst(verschobenAuf: Self.tag(11, 5)))])
        #expect(t[Self.tag(11, 5)] == [.einheit(key: "A", zustand: .geplant)])
    }

    @Test func ohneBeginnKeineVergangenheit() {
        let t = termine(beginn: nil)
        #expect(t.keys.allSatisfy { $0 >= Self.tag(11, 4) })
        #expect(t[Self.tag(11, 5)] == [.einheit(key: "A", zustand: .geplant)])
    }

    @Test func ohneKraftSlots() {
        let t = termine(raster: [Rasterplatz(tag: 6, art: .cardio, einheitKey: nil)], naechste: "B",
                        erledigt: [erledigt("A", "2026-11-02T17:00:00Z")])
        #expect(t.values.joined().allSatisfy { if case .cardio = $0 { true } else { false } })
        #expect(t[Self.tag(10, 31)] == [.cardio(arten: [], zustand: .verpasst(verschobenAuf: nil))])
        #expect(t[Self.tag(11, 7)] == [.cardio(arten: [], zustand: .geplant)])
    }

    @Test func cardioVerpasst() {
        let t = termine()
        #expect(t[Self.tag(10, 31)] == [.cardio(arten: [], zustand: .verpasst(verschobenAuf: nil))])
        let abgehakt = termine(cardio: ["2026-10-31"])
        #expect(abgehakt[Self.tag(10, 31)] == [.cardio(arten: [], zustand: .erledigt)])
    }

    @Test func kurseErledigtNachBeginnUndNieVerpasst() {
        let kursRaster = raster + [Rasterplatz(tag: 3, art: .kurs, einheitKey: nil)]
        let kurse = [kurs("2026-11-04", stunde: 8), kurs("2026-11-04", stunde: 18).mitId("spaet")]
        let t = termine(raster: kursRaster, kurse: kurse)
        let zustaende = (t[Self.tag(11, 4)] ?? []).compactMap { termin -> TerminZustand? in
            if case .kurs(_, _, true, let z) = termin { z } else { nil }
        }
        #expect(zustaende == [.erledigt, .geplant])
        // Kurstag der Vorwoche ohne gebuchten Kurs in den Daten: kein Termin.
        #expect(t[Self.tag(10, 28)] == nil)
    }

    @Test func naechsterAbHeute() {
        let t = termine(naechste: "B", erledigt: [erledigt("A", "2026-11-02T17:00:00Z")])
        let n = PlanKalender.naechster(t, ab: Self.tag(11, 4, stunde: 10), kalender: Self.kalender)
        #expect(n?.tag == Self.tag(11, 5))
        #expect(n?.termin == .einheit(key: "B", zustand: .geplant))

        let amDonnerstag = termine(naechste: "B", erledigt: [erledigt("A", "2026-11-02T17:00:00Z")],
                                   heute: Self.tag(11, 5, stunde: 7))
        let heute = PlanKalender.naechster(amDonnerstag, ab: Self.tag(11, 5, stunde: 7), kalender: Self.kalender)
        #expect(heute?.tag == Self.tag(11, 5))
    }

    // MARK: - Verlauf gedeckelt (R7)

    /// Verlauf erst ab Mo 2.11. vollstaendig: Di 27.10., Do 29.10. und Sa 31.10.
    /// sind neutral, Mo 26.10. bleibt erledigt, Di 3.11. ist verpasst.
    @Test func vorVerlaufAbKeinVerpasst() {
        let t = termine(naechste: "C",
                        erledigt: [erledigt("A", "2026-10-26T17:00:00Z"), erledigt("B", "2026-11-02T17:00:00Z")],
                        verlaufAb: Self.tag(11, 2))
        #expect(t[Self.tag(10, 26)] == [.einheit(key: "A", zustand: .erledigt)])
        #expect(t[Self.tag(10, 27)] == nil)
        #expect(t[Self.tag(10, 29)] == nil)
        #expect(t[Self.tag(10, 31)] == nil)
        #expect(t[Self.tag(11, 2)] == [.einheit(key: "B", zustand: .erledigt)])
        guard case .einheit(_, .verpasst)? = t[Self.tag(11, 3)]?.first else {
            Issue.record("Di 3.11. ist nicht verpasst"); return
        }
    }

    @Test func ohneVerlaufKeinVergangenesVerpasst() {
        let t = termine(erledigt: [erledigt("A", "2026-11-02T17:00:00Z")], verlaufAb: nil)
        let vergangen = t.filter { $0.key < Self.tag(11, 4) }.values.flatMap { $0 }
        #expect(!vergangen.contains { if case .verpasst = $0.zustand { true } else { false } })
        #expect(t[Self.tag(11, 2)] == [.einheit(key: "A", zustand: .erledigt)])
        #expect(t[Self.tag(11, 5)] != nil)
    }

    // MARK: - verlaufAb

    private func session(_ id: String, _ start: String) -> SessionSummary {
        SessionSummary(id: id, startedAt: start, completedAt: start, completedReason: "manual",
                       machineCount: 0, setCount: 0, blocks: [])
    }

    @Test func verlaufAbNieGeladenIstNil() {
        #expect(PlanKalender.verlaufAb(sessions: [], gesamt: nil, geladen: false,
                                       beginn: Self.tag(10, 26), kalender: Self.kalender) == nil)
    }

    @Test func verlaufAbVollstaendigIstBeginn() {
        let s = [session("a", "2026-11-02T17:00:00Z")]
        #expect(PlanKalender.verlaufAb(sessions: s, gesamt: 1, geladen: true,
                                       beginn: Self.tag(10, 26, stunde: 9), kalender: Self.kalender)
            == Self.tag(10, 26, stunde: 9))
        // Ohne Gesamtzahl unter dem Deckel: auch vollstaendig.
        #expect(PlanKalender.verlaufAb(sessions: s, gesamt: nil, geladen: true,
                                       beginn: Self.tag(10, 26), kalender: Self.kalender) == Self.tag(10, 26))
    }

    @Test func verlaufAbGedeckeltIstAeltesteEinheit() {
        let s = [session("a", "2026-11-02T17:00:00Z"), session("b", "2026-10-29T06:30:00Z")]
        #expect(PlanKalender.verlaufAb(sessions: s, gesamt: 80, geladen: true,
                                       beginn: Self.tag(10, 1), kalender: Self.kalender) == Self.tag(10, 29))
        let fuenfzig = (0..<50).map { session("s\($0)", "2026-11-02T17:00:00Z") }
            + [session("x", "2026-10-30T10:00:00Z")]
        #expect(PlanKalender.verlaufAb(sessions: fuenfzig, gesamt: nil, geladen: true,
                                       beginn: Self.tag(10, 1), kalender: Self.kalender) == Self.tag(10, 30))
    }
}

private extension CourseWeekSession {
    func mitId(_ id: String) -> CourseWeekSession {
        CourseWeekSession(
            sessionId: id, templateId: templateId, name: name, description: description,
            startsAt: startsAt, localDay: localDay, durationMin: durationMin, capacity: capacity,
            room: room, instructorName: instructorName, status: status, bookedCount: bookedCount,
            waitlistCount: waitlistCount, freeSeats: freeSeats, ownStatus: ownStatus,
            ownBookingId: ownBookingId, ownWaitlistPosition: ownWaitlistPosition)
    }
}
