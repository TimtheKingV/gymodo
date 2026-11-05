import Foundation
import Testing
@testable import FitnessMember

/// Wochenmodell des Plan-Tabs: Woche Mo 26.10. bis So 1.11.2026 (Europe/Berlin).
struct PlanWocheTests {
    private static let kalender: Calendar = {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: "Europe/Berlin")!
        k.firstWeekday = 1 // Sonntag: das Mapping darf davon nicht abhaengen
        return k
    }()

    private var tage: [Date] {
        (0..<7).map { Self.kalender.date(from: DateComponents(year: 2026, month: 10, day: 26 + $0))! }
    }

    private let raster: [Rasterplatz] = [
        Rasterplatz(tag: 1, art: .kurs, einheitKey: nil),
        Rasterplatz(tag: 3, art: .kraft, einheitKey: "A"),
        Rasterplatz(tag: 5, art: .kraft, einheitKey: "B"),
        Rasterplatz(tag: 7, art: .cardio, einheitKey: nil),
    ]

    private func kurs(_ id: String, tag: String, name: String, status: String = "planned",
                      own: String? = nil) -> CourseWeekSession {
        CourseWeekSession(
            sessionId: id, templateId: "t", name: name, description: nil,
            startsAt: "\(tag)T17:00:00Z", localDay: tag, durationMin: 60, capacity: 10,
            room: nil, instructorName: nil, status: status, bookedCount: 3, waitlistCount: 0,
            freeSeats: 7, ownStatus: own, ownBookingId: own == nil ? nil : "b", ownWaitlistPosition: nil)
    }

    private func termine(
        raster: [Rasterplatz]? = nil, kurse: [CourseWeekSession]? = nil,
        cardio: Set<String> = [], einheiten: Set<String> = [], filter: PlanFilter = .alle
    ) -> [Date: [PlanTermin]] {
        PlanWoche.termine(
            tage: tage, kalender: Self.kalender, raster: raster ?? self.raster,
            kurse: kurse ?? [kurs("k1", tag: "2026-10-26", name: "Zirkel", own: "booked")],
            cardioErledigt: cardio, einheitenErledigt: einheiten, filter: filter)
    }

    @Test func rasterErgibtJeTagGenauEinenTermin() {
        let t = termine()
        let mo = tage[0], mi = tage[2], fr = tage[4], so = tage[6]
        #expect(t[mo]?.count == 1)
        #expect(t[mi] == [.einheit(key: "A", erledigt: false)])
        #expect(t[fr] == [.einheit(key: "B", erledigt: false)])
        #expect(t[so] == [.cardio(arten: [], erledigt: false)])
        #expect(t[tage[1]] == nil)
        guard case .kurs(let titel, _, let angemeldet)? = t[mo]?.first else {
            Issue.record("Montag zeigt keinen Kurs"); return
        }
        #expect(titel == "Zirkel")
        #expect(angemeldet)
    }

    @Test func erledigtesWirdMarkiert() {
        let t = termine(cardio: ["2026-11-01"], einheiten: ["A"])
        #expect(t[tage[2]] == [.einheit(key: "A", erledigt: true)])
        #expect(t[tage[6]] == [.cardio(arten: [], erledigt: true)])
    }

    @Test func kursFilterZeigtAuchNichtGebuchteKurse() {
        let kurse = [
            kurs("k1", tag: "2026-10-26", name: "Zirkel", own: "booked"),
            kurs("k2", tag: "2026-10-28", name: "Yoga"),
            kurs("k3", tag: "2026-10-29", name: "Abgesagt", status: "cancelled"),
        ]
        let t = termine(kurse: kurse, filter: .kurse)
        #expect(t[tage[2]]?.count == 1)
        guard case .kurs(let titel, _, let angemeldet)? = t[tage[2]]?.first else {
            Issue.record("Mittwoch zeigt keinen Kurs"); return
        }
        #expect(titel == "Yoga")
        #expect(!angemeldet)
        #expect(t[tage[3]] == nil)
        #expect(t[tage[4]] == nil)
        #expect(t[tage[6]] == nil)
        #expect(t.values.joined().allSatisfy { if case .kurs = $0 { true } else { false } })
    }

    @Test func gebuchterKursErscheintAuchOhneRasterplatz() {
        let t = termine(kurse: [kurs("k2", tag: "2026-10-27", name: "Yoga", own: "booked")])
        guard case .kurs(let titel, _, let angemeldet)? = t[tage[1]]?.first else {
            Issue.record("Dienstag zeigt keinen Kurs"); return
        }
        #expect(titel == "Yoga" && angemeldet)
        #expect(t[tage[1]]?.count == 1)
    }

    @Test func altplanOhneRasterZeigtGebuchteKurse() {
        let kurse = [kurs("k1", tag: "2026-10-26", name: "Zirkel", own: "booked"),
                     kurs("k2", tag: "2026-10-27", name: "Frei")]
        let t = termine(raster: [], kurse: kurse)
        #expect(t.keys.count == 1)
        #expect(t[tage[0]]?.count == 1)
    }

    @Test func mehrereKurseAmTagNachBeginnSortiertOhneDoppelung() {
        let spaet = kurs("s", tag: "2026-10-26", name: "Spaet", own: "booked")
        var frueh = kurs("f", tag: "2026-10-26", name: "Frueh", own: "booked")
        frueh = CourseWeekSession(
            sessionId: "f", templateId: "t", name: "Frueh", description: nil,
            startsAt: "2026-10-26T08:00:00Z", localDay: "2026-10-26", durationMin: 60, capacity: 10,
            room: nil, instructorName: nil, status: "planned", bookedCount: 1, waitlistCount: 0,
            freeSeats: 9, ownStatus: "booked", ownBookingId: "b", ownWaitlistPosition: nil)
        let t = termine(kurse: [spaet, frueh])
        let titel = (t[tage[0]] ?? []).compactMap { termin -> String? in
            if case .kurs(let n, _, _) = termin { n } else { nil }
        }
        #expect(titel == ["Frueh", "Spaet"])
    }

    @Test func kursRasterplatzOhneBuchungErgibtKeinenTermin() {
        let t = termine(kurse: [kurs("k2", tag: "2026-10-26", name: "Yoga")])
        #expect(t[tage[0]] == nil)
    }

    @Test func einheitenUndCardioFilter() {
        let e = termine(filter: .einheiten)
        #expect(e.keys.count == 2)
        let c = termine(filter: .cardio)
        #expect(c == [tage[6]: [.cardio(arten: [], erledigt: false)]])
    }

    @Test func wochentagsZuordnungHaengtNichtVonFirstWeekdayAb() {
        var montag = Self.kalender
        montag.firstWeekday = 2
        let t = PlanWoche.termine(
            tage: tage, kalender: montag, raster: raster, kurse: [], cardioErledigt: [],
            einheitenErledigt: [], filter: .alle)
        #expect(t[tage[2]] == [.einheit(key: "A", erledigt: false)])
    }

    @Test func sichtbareFilter() {
        #expect(PlanWoche.sichtbareFilter(hatPlan: false, hatKurse: true, hatCardio: false) == [.alle, .kurse])
        #expect(PlanWoche.sichtbareFilter(hatPlan: false, hatKurse: false, hatCardio: false) == [])
        #expect(PlanWoche.sichtbareFilter(hatPlan: true, hatKurse: false, hatCardio: false) == [])
        #expect(PlanWoche.sichtbareFilter(hatPlan: true, hatKurse: true, hatCardio: true)
                == [.alle, .einheiten, .kurse, .cardio])
    }

    @Test func rasterUndProfilDekodierenAeltereAntworten() throws {
        let json = #"[{"tag":1,"art":"kurs"},{"tag":3,"art":"kraft","einheitKey":"A"}]"#
        let r = try JSONDecoder().decode([Rasterplatz].self, from: Data(json.utf8))
        #expect(r == [Rasterplatz(tag: 1, art: .kurs, einheitKey: nil), Rasterplatz(tag: 3, art: .kraft, einheitKey: "A")])
        let alt = try JSONDecoder().decode(
            TrainingsplanProfil.self, from: Data(#"{"minutes":60,"experience":"neu","focus":[]}"#.utf8))
        #expect(alt.kursTage == nil && alt.cardioArten == nil)
        let neu = try JSONDecoder().decode(
            TrainingsplanProfil.self,
            from: Data(#"{"minutes":60,"experience":"neu","focus":[],"kursTage":[1],"cardioTage":[7],"cardioArten":["laufen"],"kraftTage":[3]}"#.utf8))
        #expect(neu.kursTage == [1] && neu.cardioTage == [7] && neu.cardioArten == ["laufen"] && neu.kraftTage == [3])
        let raus = String(decoding: try JSONEncoder().encode(alt), as: UTF8.self)
        #expect(!raus.contains("kursTage"))
    }
}
