import Foundation
import Testing
@testable import FitnessMember

/// Die eigenen Kurse im Wochenstreifen auf Home (Testnotiz 06.10., #1).
/// Gruen fuer einen bestaetigten Platz, Gelb fuer die Warteliste -- so
/// entschieden auf Rueckfrage, im selben Gelb wie die Warteliste auf der
/// Kurse-Seite.
struct HomeKurseTests {
    private let jetzt = Date(timeIntervalSince1970: 1_757_000_000)

    private func termin(
        tag: String = "2026-09-08",
        startVersatzStunden: Double = 3,
        status: String = "planned",
        ownStatus: String? = "booked"
    ) -> GespeicherterTermin {
        GespeicherterTermin(CourseWeekSession(
            sessionId: UUID().uuidString, templateId: "t1", name: "Kraftzirkel",
            description: nil,
            startsAt: ISO8601DateFormatter().string(
                from: jetzt.addingTimeInterval(startVersatzStunden * 3600)),
            localDay: tag, durationMin: 60, capacity: 16,
            room: nil, instructorName: nil, status: status,
            bookedCount: 12, waitlistCount: 0, freeSeats: 4,
            ownStatus: ownStatus, ownBookingId: ownStatus == nil ? nil : "b1",
            ownWaitlistPosition: ownStatus == "waitlisted" ? 3 : nil))
    }

    @Test func ordnetBevorstehendeEigeneTermineIhremTagZu() {
        let montag = termin(tag: "2026-09-08")
        let mittwoch = termin(tag: "2026-09-10", startVersatzStunden: 50, ownStatus: "waitlisted")

        let jeTag = HomeKurse.termineJeTag([montag, mittwoch], jetzt: jetzt)

        #expect(jeTag["2026-09-08"]?.map(\.sessionId) == [montag.sessionId])
        #expect(jeTag["2026-09-10"]?.map(\.sessionId) == [mittwoch.sessionId])
    }

    @Test func abgesagteUndVergangeneTermineFallenWeg() {
        // Dieselbe Regel wie ueberall in Kurse: abgesagt und vorbei
        // schlagen jeden eigenen Status -- daran gibt es nichts abzumelden.
        let jeTag = HomeKurse.termineJeTag(
            [termin(status: "cancelled"), termin(startVersatzStunden: -1)], jetzt: jetzt)

        #expect(jeTag.isEmpty)
    }

    @Test func derPunktIstGruenSobaldEinPlatzBestaetigtIst() {
        #expect(HomeKurse.punkt([termin(ownStatus: "booked")], jetzt: jetzt) == .angemeldet)
        #expect(HomeKurse.punkt([termin(ownStatus: "waitlisted"), termin(ownStatus: "booked")],
                                jetzt: jetzt) == .angemeldet)
    }

    @Test func nurWartelisteGibtDenGelbenPunkt() {
        #expect(HomeKurse.punkt([termin(ownStatus: "waitlisted")], jetzt: jetzt) == .warteliste)
    }

    @Test func ohneTermineKeinPunkt() {
        #expect(HomeKurse.punkt([], jetzt: jetzt) == .keiner)
        #expect(HomeKurse.punkt(nil, jetzt: jetzt) == .keiner)
    }
}
