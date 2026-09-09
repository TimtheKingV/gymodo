import Foundation
import Testing
@testable import FitnessMember

struct KursZustandTests {
    private let jetzt = Date(timeIntervalSince1970: 1_757_000_000)

    private func termin(
        startVersatzStunden: Double = 3,
        status: String = "planned",
        freeSeats: Int = 4,
        ownStatus: String? = nil
    ) -> CourseWeekSession {
        CourseWeekSession(
            sessionId: "k1", templateId: "t1", name: "Kraftzirkel",
            description: nil,
            startsAt: ISO8601DateFormatter().string(
                from: jetzt.addingTimeInterval(startVersatzStunden * 3600)),
            localDay: "2026-09-08", durationMin: 60, capacity: 16,
            room: "Kursraum 2", instructorName: "Marek T.", status: status,
            bookedCount: 12, waitlistCount: 0, freeSeats: freeSeats,
            ownStatus: ownStatus, ownBookingId: ownStatus == nil ? nil : "b1",
            ownWaitlistPosition: ownStatus == "waitlisted" ? 3 : nil
        )
    }

    // Die sechs Zeilen der Tabelle aus Spec Abschnitt 5.3, in ihrer
    // Auswertungsreihenfolge.

    @Test func abgesagtSchlaegtAlles() {
        let abgesagtUndAngemeldet = termin(status: "cancelled", ownStatus: "booked")

        #expect(KursZustandRechner.zustand(fuer: abgesagtUndAngemeldet, jetzt: jetzt) == .abgesagt)
    }

    @Test func vorbeiSchlaegtDenEigenenStatus() {
        let vorbeiUndAngemeldet = termin(startVersatzStunden: -2, ownStatus: "booked")

        #expect(KursZustandRechner.zustand(fuer: vorbeiUndAngemeldet, jetzt: jetzt) == .vorbei)
    }

    @Test func angemeldet() {
        #expect(KursZustandRechner.zustand(fuer: termin(ownStatus: "booked"), jetzt: jetzt) == .angemeldet)
    }

    @Test func warteliste() {
        #expect(KursZustandRechner.zustand(fuer: termin(freeSeats: 0, ownStatus: "waitlisted"), jetzt: jetzt) == .warteliste)
    }

    @Test func freieplaetze() {
        #expect(KursZustandRechner.zustand(fuer: termin(freeSeats: 4), jetzt: jetzt) == .frei)
    }

    @Test func voll() {
        #expect(KursZustandRechner.zustand(fuer: termin(freeSeats: 0), jetzt: jetzt) == .voll)
    }

    @Test func einTerminDerGeradeLaeuftGiltAlsVorbei() {
        // Beginn ist vorbei: anmelden geht nicht mehr, abmelden auch nicht.
        #expect(KursZustandRechner.zustand(fuer: termin(startVersatzStunden: -0.5), jetzt: jetzt) == .vorbei)
    }
}

struct AbmeldefristTests {
    private let jetzt = Date(timeIntervalSince1970: 1_757_000_000)

    @Test func ziehtDieFristVomBeginnAb() throws {
        let beginn = jetzt.addingTimeInterval(3 * 3600)
        let grenze = try #require(KursZustandRechner.abmeldenBis(
            startsAt: ISO8601DateFormatter().string(from: beginn), fristStunden: 2))

        #expect(grenze == beginn.addingTimeInterval(-2 * 3600))
    }

    @Test func beiFristNullIstDerBeginnDieGrenze() throws {
        let beginn = jetzt.addingTimeInterval(3 * 3600)
        let grenze = try #require(KursZustandRechner.abmeldenBis(
            startsAt: ISO8601DateFormatter().string(from: beginn), fristStunden: 0))

        #expect(grenze == beginn)
    }

    @Test func einUnlesbarerBeginnLiefertKeineGrenze() {
        // Lieber keine Uhrzeit als eine erfundene.
        #expect(KursZustandRechner.abmeldenBis(startsAt: "kein Datum", fristStunden: 2) == nil)
    }
}

struct MeineKurseTests {
    @Test func nimmtNurEigeneBuchungenUndWartelistenplaetze() {
        // Aufbau ueber JSON, damit der Test den Vertrag prueft und nicht
        // einen handgeschriebenen Initialisierer.
        let woche = KursTestdaten.woche(ownStatus: ["booked", nil, "waitlisted", nil])

        let meine = KursZustandRechner.meineKurse(aus: woche)

        #expect(meine.count == 2)
        #expect(meine.allSatisfy { $0.ownStatus != nil })
    }

    @Test func behaeltDieZeitlicheReihenfolge() {
        let woche = KursTestdaten.woche(ownStatus: ["booked", "booked"])

        let meine = KursZustandRechner.meineKurse(aus: woche)

        #expect(meine[0].startsAt <= meine[1].startsAt)
    }
}

enum KursTestdaten {
    static func woche(ownStatus: [String?]) -> CourseWeek {
        let termine = ownStatus.enumerated().map { index, status in
            """
            {"sessionId":"k\(index)","templateId":"t1","name":"Kurs \(index)",
             "description":null,"startsAt":"2026-09-1\(index)T18:00:00Z",
             "localDay":"2026-09-1\(index)","durationMin":60,"capacity":16,
             "room":null,"instructorName":null,"status":"planned",
             "bookedCount":1,"waitlistCount":0,"freeSeats":15,
             "ownStatus":\(status.map { "\"\($0)\"" } ?? "null"),
             "ownBookingId":null,"ownWaitlistPosition":null}
            """
        }.joined(separator: ",")
        let json = """
        {"from":"2026-09-10T00:00:00Z","to":"2026-09-17T00:00:00Z",
         "timezone":"Europe/Berlin","cancellationDeadlineHours":2,
         "sessions":[\(termine)]}
        """
        return try! JSONDecoder().decode(CourseWeek.self, from: Data(json.utf8))
    }
}
