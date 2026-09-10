import Foundation
import Testing
@testable import FitnessMember

/// Der Punkt unter der Tagesbox. Drei Zustaende, und die Grenze zwischen
/// zwei und drei ist die eigentliche Aussage: gruen heisst "dein Platz
/// steht", nichts anderes.
struct KurseTagesindikatorTests {
    private let jetzt = Date(timeIntervalSince1970: 1_757_000_000)

    private func termin(
        tag: String = "2026-09-08",
        startVersatzStunden: Double = 3,
        status: String = "planned",
        ownStatus: String? = nil
    ) -> CourseWeekSession {
        CourseWeekSession(
            sessionId: UUID().uuidString, templateId: "t1", name: "Kraftzirkel",
            description: nil,
            startsAt: ISO8601DateFormatter().string(
                from: jetzt.addingTimeInterval(startVersatzStunden * 3600)),
            localDay: tag, durationMin: 60, capacity: 16,
            room: nil, instructorName: nil, status: status,
            bookedCount: 12, waitlistCount: 0, freeSeats: 4,
            ownStatus: ownStatus, ownBookingId: ownStatus == nil ? nil : "b1",
            ownWaitlistPosition: ownStatus == "waitlisted" ? 3 : nil)
    }

    @Test func einTagOhneTermineTraegtKeinenPunkt() {
        let indikator = KurseTagesindikator.fuer(
            tagId: "2026-09-09", termine: [termin(tag: "2026-09-08")], jetzt: jetzt)

        #expect(indikator == .keiner)
    }

    @Test func einTagMitTerminenTraegtDenGedecktenPunkt() {
        let indikator = KurseTagesindikator.fuer(
            tagId: "2026-09-08", termine: [termin()], jetzt: jetzt)

        #expect(indikator == .kurse)
    }

    @Test func einBestaetigterPlatzFaerbtDenPunkt() {
        let indikator = KurseTagesindikator.fuer(
            tagId: "2026-09-08",
            termine: [termin(), termin(ownStatus: "booked")], jetzt: jetzt)

        #expect(indikator == .angemeldet)
    }

    /// Die Warteliste ist kein Platz. Sie gruen zu faerben hiesse, dem
    /// Mitglied im Wochenstreifen etwas zu versprechen, was die Karte
    /// darueber ausdruecklich verneint ("Bis dahin ist nichts reserviert").
    @Test func diWartelisteFaerbtDenPunktNicht() {
        let indikator = KurseTagesindikator.fuer(
            tagId: "2026-09-08", termine: [termin(ownStatus: "waitlisted")], jetzt: jetzt)

        #expect(indikator == .kurse)
    }

    /// Nach dem Kurs steht kein Platz mehr -- der Tag traegt dann den
    /// gedeckten Punkt wie jeder andere Tag mit Kursen.
    @Test func einVergangenerEigenerKursFaerbtDenPunktNichtMehr() {
        let indikator = KurseTagesindikator.fuer(
            tagId: "2026-09-08",
            termine: [termin(startVersatzStunden: -2, ownStatus: "booked")], jetzt: jetzt)

        #expect(indikator == .kurse)
    }

    @Test func einAbgesagterEigenerKursFaerbtDenPunktNicht() {
        let indikator = KurseTagesindikator.fuer(
            tagId: "2026-09-08",
            termine: [termin(status: "cancelled", ownStatus: "booked")], jetzt: jetzt)

        #expect(indikator == .kurse)
    }

    /// Ein abgesagter Termin bleibt in der Tagesliste sichtbar -- der Tag
    /// hat also etwas zu zeigen und darf nicht leer wirken.
    @Test func einTagMitNurAbgesagtenTerminenTraegtTrotzdemEinenPunkt() {
        let indikator = KurseTagesindikator.fuer(
            tagId: "2026-09-08", termine: [termin(status: "cancelled")], jetzt: jetzt)

        #expect(indikator == .kurse)
    }

    @Test func ohneJedenTerminTraegtKeinTagEinenPunkt() {
        #expect(KurseTagesindikator.fuer(tagId: "2026-09-08", termine: [], jetzt: jetzt) == .keiner)
    }
}
