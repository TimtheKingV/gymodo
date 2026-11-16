import Foundation
import Testing
@testable import FitnessMember

/// Die Wochenrechnung ohne feste Tage (Spec P2 §2 #1–#3, §3, §8):
/// Europe/Berlin, Woche ab Mo 9.11.2026, heute Di 10.11.
struct PlanWochenRechnungTests {
    private static let kalender: Calendar = {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: "Europe/Berlin")!
        k.firstWeekday = 1 // Sonntag: die Rechnung darf davon nicht abhaengen
        return k
    }()

    private static func tag(_ monat: Int, _ t: Int, stunde: Int = 0, minute: Int = 0) -> Date {
        kalender.date(from: DateComponents(year: 2026, month: monat, day: t, hour: stunde, minute: minute))!
    }

    /// Ortszeit Berlin (November = MEZ, +01:00) als ISO-Text.
    private static func zp(_ monat: Int, _ t: Int, _ stunde: Int, _ minute: Int = 0) -> String {
        String(format: "2026-%02d-%02dT%02d:%02d:00+01:00", monat, t, stunde, minute)
    }

    nonisolated(unsafe) private static let iso = ISO8601DateFormatter()

    private static let woche = tag(11, 9)
    private static let dienstag = tag(11, 10, stunde: 10)

    private func ziel(_ kraft: Int, _ cardio: Int = 0, _ minuten: Int = 30) -> Wochenziel {
        Wochenziel(kraft: kraft, cardio: cardio, cardioMinuten: minuten)
    }

    private func sitzung(
        _ id: String, _ start: String, kraftSaetze: Int = 1, cardioMinuten: [Int] = [], beendet: Bool = true
    ) -> SessionSummary {
        func satz(_ i: Int, cardio: CardioWerte?) -> SessionSummary.Block.Set {
            SessionSummary.Block.Set(
                setIndex: i, load: cardio == nil ? 40 : nil, secondaryLoad: nil, volume: cardio == nil ? 10 : nil,
                rir: nil, problemFlag: false, problemReason: nil, performedAt: start, cardio: cardio)
        }
        func block(_ saetze: [SessionSummary.Block.Set], cardio: Bool) -> SessionSummary.Block {
            SessionSummary.Block(
                machineId: nil, machineLabel: cardio ? "Laufband" : "Brustpresse", exerciseId: cardio ? "e-c" : "e-k",
                exerciseName: cardio ? "Laufen" : "Brustpresse", loadUnit: cardio ? .kmh : .kg, secondaryUnit: nil,
                volumeKind: cardio ? .seconds : .reps, sets: saetze)
        }
        var blocks: [SessionSummary.Block] = []
        if kraftSaetze > 0 { blocks.append(block((0..<kraftSaetze).map { satz($0, cardio: nil) }, cardio: false)) }
        if !cardioMinuten.isEmpty {
            blocks.append(block(cardioMinuten.enumerated().map { satz($0.offset, cardio: CardioWerte(zeit: $0.element * 60)) },
                                cardio: true))
        }
        let ende = beendet ? Self.iso.string(from: Zeitpunkt.parse(start)!.addingTimeInterval(3600)) : nil
        return SessionSummary(
            id: id, startedAt: start, completedAt: ende, completedReason: beendet ? "manual" : nil,
            machineCount: blocks.count, setCount: kraftSaetze + cardioMinuten.count, blocks: blocks)
    }

    private func kurs(_ id: String, _ startsAt: String, own: String? = "booked", status: String = "planned")
        -> CourseWeekSession {
        CourseWeekSession(
            sessionId: id, templateId: "t", name: "Zirkel", description: nil, startsAt: startsAt,
            localDay: String(startsAt.prefix(10)), durationMin: 60, capacity: 10, room: nil, instructorName: nil,
            status: status, bookedCount: 3, waitlistCount: 0, freeSeats: 7, ownStatus: own,
            ownBookingId: own == nil ? nil : "b", ownWaitlistPosition: nil)
    }

    private func rechne(
        wocheStart: Date = PlanWochenRechnungTests.woche, heute: Date = PlanWochenRechnungTests.dienstag,
        ziel: Wochenziel, einheiten: [String] = ["A", "B"], naechste: String? = "A",
        sitzungen: [SessionSummary] = [], erledigt: [ErledigteEinheit] = [], checks: [CardioCheck] = [],
        kurse: [CourseWeekSession] = [], filter: PlanFilter = .alle
    ) -> PlanWochenStand {
        PlanWochenRechnung.berechne(
            wocheStart: wocheStart, heute: heute, kalender: Self.kalender, ziel: ziel, einheiten: einheiten,
            naechsteEinheitKey: naechste, sitzungen: sitzungen, erledigt: erledigt, cardioChecks: checks,
            kurse: kurse, filter: filter)
    }

    private func kraftKarten(_ s: PlanWochenStand) -> [WochenKarte] {
        s.karten.filter { if case .kraft = $0.art { true } else { false } }
    }

    private func cardioKarten(_ s: PlanWochenStand) -> [WochenKarte] {
        s.karten.filter { $0.art == .cardio }
    }

    @Test func planEinheitUndFreiesTraining() {
        let s = rechne(
            ziel: ziel(2), naechste: "B",
            sitzungen: [sitzung("s1", Self.zp(11, 9, 18)), sitzung("s2", Self.zp(11, 10, 8))],
            erledigt: [ErledigteEinheit(sessionId: "s1", einheitKey: "A", startedAt: Self.zp(11, 9, 18))])
        #expect(s.phase == .laufend)
        #expect(s.karten.map(\.art) == [.kraft(einheitKey: "A"), .kraft(einheitKey: nil)])
        #expect(s.karten.allSatisfy { $0.erledigtAm != nil })
        #expect(s.karten.map(\.quelle) == [.sitzung(id: "s1"), .sitzung(id: "s2")])
        #expect(s.kraftErledigt == 2)
    }

    @Test func zielUeberschritten() {
        let s = rechne(
            ziel: ziel(1),
            sitzungen: [sitzung("s1", Self.zp(11, 9, 8)), sitzung("s2", Self.zp(11, 9, 18)),
                        sitzung("s3", Self.zp(11, 10, 7))])
        #expect(s.karten.count == 3)
        #expect(s.karten.allSatisfy { $0.erledigtAm != nil })
        #expect(s.kraftErledigt == 3)
    }

    @Test func offeneKartenFolgen() {
        let s = rechne(
            ziel: ziel(3), einheiten: ["A", "B"], naechste: "B",
            sitzungen: [sitzung("s1", Self.zp(11, 9, 18))],
            erledigt: [ErledigteEinheit(sessionId: "s1", einheitKey: "A", startedAt: Self.zp(11, 9, 18))])
        let offen = s.karten.filter { $0.erledigtAm == nil }
        #expect(offen.map(\.art) == [.kraft(einheitKey: "B"), .kraft(einheitKey: "A")])
        #expect(offen.map(\.istNaechste) == [true, false])
        #expect(offen.map(\.quelle) == [.keine, .keine])
        #expect(s.karten.first?.erledigtAm != nil) // erledigt vor offen
    }

    @Test func laufendeSitzungGibtKeinenHaken() {
        let s = rechne(
            ziel: ziel(2),
            sitzungen: [sitzung("s1", Self.zp(11, 10, 9), beendet: false)],
            erledigt: [ErledigteEinheit(sessionId: "s1", einheitKey: "A", startedAt: Self.zp(11, 10, 9))])
        #expect(s.kraftErledigt == 0)
        #expect(s.karten.filter { $0.erledigtAm == nil }.count == 2)
        #expect(s.marken.isEmpty)
    }

    @Test func cardioNachKraft() {
        let s = rechne(
            ziel: ziel(1, 1, 30),
            sitzungen: [sitzung("s1", Self.zp(11, 9, 18), kraftSaetze: 3, cardioMinuten: [20, 12])])
        #expect(s.kraftErledigt == 1)
        #expect(s.cardioErledigt == 1)
        let cardio = cardioKarten(s)
        #expect(cardio.count == 1)
        #expect(cardio.first?.quelle == .sitzung(id: "s1"))
        #expect(cardio.first?.minuten == 32)
        #expect(kraftKarten(s).first?.quelle == .sitzung(id: "s1"))
        #expect(s.karten.allSatisfy { $0.erledigtAm != nil })
    }

    @Test func zweimalZwanzigMinutenReichenNicht() {
        let s = rechne(
            ziel: ziel(2, 1, 30),
            sitzungen: [sitzung("s1", Self.zp(11, 9, 18), cardioMinuten: [20]),
                        sitzung("s2", Self.zp(11, 10, 8), cardioMinuten: [20])])
        #expect(s.cardioErledigt == 0)
        #expect(cardioKarten(s).map(\.erledigtAm) == [nil])

        // Gegenprobe: 2×15 min in EINER Sitzung ergeben einen Haken.
        let eine = rechne(ziel: ziel(1, 1, 30), sitzungen: [sitzung("s3", Self.zp(11, 9, 18), cardioMinuten: [15, 15])])
        #expect(eine.cardioErledigt == 1)
    }

    @Test func handHakenMehrfach() {
        let s = rechne(
            ziel: ziel(0, 1, 30),
            checks: [CardioCheck(id: "c1", day: "2026-11-10", minuten: nil),
                     CardioCheck(id: "c2", day: "2026-11-10", minuten: nil)])
        let cardio = cardioKarten(s)
        #expect(cardio.count == 2)
        #expect(cardio.map(\.quelle) == [.hand(checkId: "c1"), .hand(checkId: "c2")])
        #expect(cardio.allSatisfy { $0.erledigtAm == Self.tag(11, 10) })
        #expect(s.cardioErledigt == 2)
        #expect(s.marken[Self.tag(11, 10)] == [.cardio])
    }

    @Test func nurCardioSitzungIstKeinKraft() {
        let s = rechne(
            ziel: ziel(1, 1, 30),
            sitzungen: [sitzung("s1", Self.zp(11, 9, 18), kraftSaetze: 0, cardioMinuten: [35])])
        #expect(s.kraftErledigt == 0)
        #expect(s.cardioErledigt == 1)
        #expect(kraftKarten(s).map(\.erledigtAm) == [nil])
        #expect(s.marken[Self.tag(11, 9)] == [.cardio])
    }

    @Test func kursVorUndNachBeginn() {
        // Do 12.11., 18:00 Berlin = 17:00Z.
        let k = kurs("k1", "2026-11-12T17:00:00Z")
        let vorher = rechne(ziel: ziel(0), kurse: [k])
        #expect(vorher.marken[Self.tag(11, 12)] == [.kursGebucht])
        #expect(vorher.karten.map(\.art) == [.kurs(k)])
        #expect(vorher.karten.first?.erledigtAm == nil)

        let nachher = rechne(heute: Self.tag(11, 12, stunde: 19), ziel: ziel(0), kurse: [k])
        #expect(nachher.marken[Self.tag(11, 12)] == [.kurs])
        #expect(nachher.karten.first?.erledigtAm == Self.tag(11, 12, stunde: 18))

        let weg = rechne(
            heute: Self.tag(11, 12, stunde: 19), ziel: ziel(0),
            kurse: [kurs("k2", "2026-11-12T17:00:00Z", own: "waitlisted"),
                    kurs("k3", "2026-11-12T17:00:00Z", status: "cancelled"),
                    kurs("k4", "2026-11-12T17:00:00Z", own: nil)])
        #expect(weg.karten.isEmpty)
        #expect(weg.marken.isEmpty)
    }

    @Test func wochenwechselMontagNacht() {
        let sitzungen = [sitzung("so", Self.zp(11, 15, 23, 30)), sitzung("mo", Self.zp(11, 16, 0, 30))]
        let heute = Self.tag(11, 16, stunde: 1)
        let alt = rechne(heute: heute, ziel: ziel(2), sitzungen: sitzungen)
        #expect(alt.phase == .vergangen)
        #expect(alt.karten.map(\.quelle) == [.sitzung(id: "so")])
        #expect(alt.marken.keys.sorted() == [Self.tag(11, 15)])

        let neu = rechne(wocheStart: Self.tag(11, 16), heute: heute, ziel: ziel(1), sitzungen: sitzungen)
        #expect(neu.phase == .laufend)
        #expect(neu.kraftErledigt == 1)
        #expect(kraftKarten(neu).map(\.quelle) == [.sitzung(id: "mo")])
        #expect(neu.marken.keys.sorted() == [Self.tag(11, 16)])
    }

    @Test func vergangeneWocheOhneOffene() {
        let s = rechne(
            wocheStart: Self.tag(11, 2), ziel: ziel(2, 1),
            sitzungen: [sitzung("s1", Self.zp(11, 4, 18))])
        #expect(s.phase == .vergangen)
        #expect(s.karten.count == 1)
        #expect(s.karten.first?.erledigtAm != nil)
    }

    @Test func kuenftigeWocheNurKurse() {
        let k = kurs("k1", "2026-11-18T17:00:00Z")
        let s = rechne(
            wocheStart: Self.tag(11, 16), ziel: ziel(2, 1),
            checks: [CardioCheck(id: "c1", day: "2026-11-10", minuten: nil)], kurse: [k])
        #expect(s.phase == .kuenftig)
        #expect(s.karten.map(\.art) == [.kurs(k)])
        #expect(s.marken == [Self.tag(11, 18): [.kursGebucht]])
    }

    @Test func filterKraft() {
        let s = rechne(
            ziel: ziel(2, 2, 30),
            sitzungen: [sitzung("s1", Self.zp(11, 9, 18), cardioMinuten: [35])],
            checks: [CardioCheck(id: "c1", day: "2026-11-10", minuten: nil)],
            kurse: [kurs("k1", "2026-11-09T18:00:00Z"), kurs("k2", "2026-11-12T17:00:00Z")],
            filter: .kraft)
        #expect(!s.karten.isEmpty)
        #expect(s.karten.allSatisfy { if case .kraft = $0.art { true } else { false } })
        #expect(s.marken == [Self.tag(11, 9): [.kraft]])
    }

    @Test func markenReihenfolge() {
        // Kurs vor dem Training am selben Tag: die Reihenfolge folgt der Art, nicht der Uhrzeit.
        let s = rechne(
            ziel: ziel(1),
            sitzungen: [sitzung("s1", Self.zp(11, 9, 18))],
            kurse: [kurs("k1", "2026-11-09T08:00:00Z")])
        #expect(s.marken[Self.tag(11, 9)] == [.kraft, .kurs])
    }
}
