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

    @Test func beginnGenauJetztGiltSchonAlsVorbei() {
        // Der Grenzfall auf die Sekunde: <= schlaegt <, nicht umgekehrt.
        #expect(KursZustandRechner.zustand(fuer: termin(startVersatzStunden: 0), jetzt: jetzt) == .vorbei)
    }

    // Die beiden Ueberschneidungen, die vorher nur durch die
    // Auswertungsreihenfolge im Code bewiesen waren, nicht durch einen
    // eigenen Testfall.

    @Test func vergangenerKursAufDerWartelisteGiltAlsVorbei() {
        let vorbeiUndWarteliste = termin(startVersatzStunden: -2, freeSeats: 0, ownStatus: "waitlisted")

        #expect(KursZustandRechner.zustand(fuer: vorbeiUndWarteliste, jetzt: jetzt) == .vorbei)
    }

    @Test func vollerKursMitEigenerBuchungGiltAlsAngemeldet() {
        let vollUndAngemeldet = termin(freeSeats: 0, ownStatus: "booked")

        #expect(KursZustandRechner.zustand(fuer: vollUndAngemeldet, jetzt: jetzt) == .angemeldet)
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

struct KursZeitpunktTests {
    // startsAt kommt aus einer Postgres timestamptz (course_week), nicht
    // aus einem clientseitig erzeugten String -- anders als performedAt
    // in Sub-Projekt 2 muss das Parsen deshalb Sekundenbruchteile
    // vertragen, auch wenn sie im Regelfall fehlen (Kurse beginnen auf
    // die Minute).

    @Test func parstOhneSekundenbruchteile() throws {
        #expect(KursZeitpunkt.parse("2026-09-08T18:00:00Z") != nil)
    }

    @Test func parstMitSekundenbruchteilenGenauSoGenau() throws {
        let ohne = try #require(KursZeitpunkt.parse("2026-09-08T18:00:00Z"))
        let mit = try #require(KursZeitpunkt.parse("2026-09-08T18:00:00.500Z"))

        #expect(mit.timeIntervalSince(ohne) == 0.5)
    }

    @Test func liefertNilBeiUnlesbaremText() {
        #expect(KursZeitpunkt.parse("kein Datum") == nil)
    }
}

struct KursZeitTests {
    // Fester Zeitpunkt und feste Zeitzone -- sonst ist der Test auf dem
    // Geraet des Entwicklers gruen und anderswo rot (Sommerzeit).
    private let zeitpunkt = ISO8601DateFormatter().date(from: "2026-08-27T10:00:00Z")!

    @Test func uhrzeitInDerStudioZeitzone() {
        #expect(KursZeit.uhrzeit(zeitpunkt, zeitzone: "Europe/Berlin") == "12:00")
    }

    @Test func uhrzeitFolgtDerUebergebenenZeitzoneNichtDemGeraet() {
        // Beweist, dass die Zeitzone tatsaechlich ein Parameter ist und
        // nicht z.B. .current durchschlaegt.
        #expect(KursZeit.uhrzeit(zeitpunkt, zeitzone: "UTC") == "10:00")
    }

    @Test func datumAusgeschriebenOhneJahrOhnePunktBeimWochentag() {
        // designsystem.md SS10: "Mi, 27. August" -- Wochentag stand-alone
        // ohne Punkt, kein Jahr.
        #expect(KursZeit.datumAusgeschrieben(zeitpunkt, zeitzone: "Europe/Berlin") == "Do, 27. August")
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
