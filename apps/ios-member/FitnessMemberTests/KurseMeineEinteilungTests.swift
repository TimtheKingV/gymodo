import Foundation
import Testing
@testable import FitnessMember

/// `KurseMeineEinteilung.bilden` -- die Zuordnung gespeicherter eigener
/// Termine zu den drei Abschnitten des Screens. Kein `Date()`, keine
/// `TimeZone.current`: `jetzt` und `zeitzone` kommen immer fest vorgegeben.
///
/// Referenzwoche wie KurseWochenBerechnungTests: 2026-09-07 ist ein
/// Montag, 2026-09-10 ein Donnerstag (die Woche von `jetzt`); 2026-09-14
/// ist der Montag der Folgewoche.
struct KurseMeineEinteilungTests {
    private let zeitzone = "Europe/Berlin"
    /// Donnerstag, 2026-09-10, 12:00 Uhr Europe/Berlin (10:00 UTC).
    private let jetzt = ISO8601DateFormatter().date(from: "2026-09-10T10:00:00Z")!

    private func termin(
        sessionId: String = "k1", startsAt: String, status: String = "planned", ownStatus: String = "booked"
    ) -> GespeicherterTermin {
        GespeicherterTermin(
            CourseWeekSession(
                sessionId: sessionId, templateId: "t1", name: "Kurs \(sessionId)", description: nil,
                startsAt: startsAt, localDay: "2026-09-10", durationMin: 60, capacity: 16,
                room: "Kursraum 1", instructorName: "Trainer", status: status,
                bookedCount: 12, waitlistCount: 0, freeSeats: 4,
                ownStatus: ownStatus, ownBookingId: "b1", ownWaitlistPosition: nil))
    }

    @Test func angemeldetInDieserWocheLandetUnterAngemeldet() {
        let t = termin(startsAt: "2026-09-10T18:00:00Z", ownStatus: "booked")
        let einteilung = KurseMeineEinteilung.bilden(aus: [t], jetzt: jetzt, zeitzone: zeitzone)

        #expect(einteilung.angemeldet.map(\.termin.sessionId) == ["k1"])
        #expect(einteilung.warteliste.isEmpty)
        #expect(einteilung.spaeter.isEmpty)
    }

    @Test func wartelisteInDieserWocheLandetUnterWarteliste() {
        let t = termin(startsAt: "2026-09-10T19:15:00Z", ownStatus: "waitlisted")
        let einteilung = KurseMeineEinteilung.bilden(aus: [t], jetzt: jetzt, zeitzone: zeitzone)

        #expect(einteilung.warteliste.map(\.termin.sessionId) == ["k1"])
        #expect(einteilung.angemeldet.isEmpty)
        #expect(einteilung.spaeter.isEmpty)
    }

    /// Ein gebuchter Termin in der Folgewoche landet unter "Später"
    /// -- nicht unter "Angemeldet", obwohl der eigene Status derselbe ist.
    @Test func angemeldetInDerFolgewocheLandetUnterSpaeter() {
        let t = termin(startsAt: "2026-09-15T09:00:00Z", ownStatus: "booked")
        let einteilung = KurseMeineEinteilung.bilden(aus: [t], jetzt: jetzt, zeitzone: zeitzone)

        #expect(einteilung.spaeter.map(\.termin.sessionId) == ["k1"])
        #expect(einteilung.angemeldet.isEmpty)
        #expect(einteilung.warteliste.isEmpty)
    }

    /// Dieselbe Regel gilt fuer die Warteliste: die Wochenzugehoerigkeit
    /// schlaegt den eigenen Status.
    @Test func wartelisteInDerFolgewocheLandetEbenfallsUnterSpaeter() {
        let t = termin(startsAt: "2026-09-16T09:00:00Z", ownStatus: "waitlisted")
        let einteilung = KurseMeineEinteilung.bilden(aus: [t], jetzt: jetzt, zeitzone: zeitzone)

        #expect(einteilung.spaeter.map(\.termin.sessionId) == ["k1"])
        #expect(einteilung.warteliste.isEmpty)
    }

    /// Abgesagt schlaegt jeden eigenen Status (KursDetailOfflineZustand) --
    /// und faellt hier komplett aus allen drei Abschnitten heraus.
    @Test func abgesagtErscheintInKeinemAbschnitt() {
        let t = termin(startsAt: "2026-09-10T18:00:00Z", status: "cancelled", ownStatus: "booked")
        let einteilung = KurseMeineEinteilung.bilden(aus: [t], jetzt: jetzt, zeitzone: zeitzone)

        #expect(einteilung.istLeer)
    }

    /// Ein bereits begonnener Termin ist keine offene Anmeldung mehr.
    @Test func vorbeiErscheintInKeinemAbschnitt() {
        let t = termin(startsAt: "2026-09-10T08:00:00Z", ownStatus: "booked")
        let einteilung = KurseMeineEinteilung.bilden(aus: [t], jetzt: jetzt, zeitzone: zeitzone)

        #expect(einteilung.istLeer)
    }

    /// Ein unlesbarer Beginn faellt ganz weg -- ein erratener Abschnitt
    /// waere schlimmer als ein fehlender Eintrag.
    @Test func unlesbarerBeginnErscheintInKeinemAbschnitt() {
        let t = termin(startsAt: "keine-gueltige-zeit", ownStatus: "booked")
        let einteilung = KurseMeineEinteilung.bilden(aus: [t], jetzt: jetzt, zeitzone: zeitzone)

        #expect(einteilung.istLeer)
    }

    @Test func jederAbschnittIstZeitlichAufsteigendSortiert() {
        let spaeter = termin(sessionId: "spaeter", startsAt: "2026-09-11T18:00:00Z", ownStatus: "booked")
        let frueher = termin(sessionId: "frueher", startsAt: "2026-09-10T18:00:00Z", ownStatus: "booked")
        let einteilung = KurseMeineEinteilung.bilden(aus: [spaeter, frueher], jetzt: jetzt, zeitzone: zeitzone)

        #expect(einteilung.angemeldet.map(\.termin.sessionId) == ["frueher", "spaeter"])
    }

    /// Seit das Ladefenster bis "jetzt plus 14 Tage" reicht (Spec 5.1),
    /// kommen auch Termine der UEBERnaechsten Woche im Cache an. Sie
    /// gehoeren in denselben Abschnitt -- deshalb heisst er "Später" und
    /// nicht mehr "Nächste Woche".
    @Test func einTerminInDerUebernaechstenWocheLandetEbenfallsUnterSpaeter() {
        // Donnerstag der uebernaechsten Woche, noch innerhalb von
        // jetzt + 14 Tagen (jetzt ist Do 2026-09-10).
        let t = termin(startsAt: "2026-09-22T09:00:00Z", ownStatus: "booked")
        let einteilung = KurseMeineEinteilung.bilden(aus: [t], jetzt: jetzt, zeitzone: zeitzone)

        #expect(einteilung.spaeter.map(\.termin.sessionId) == ["k1"])
        #expect(einteilung.angemeldet.isEmpty)
    }

    @Test func leereEingabeErgibtEineLeereEinteilung() {
        let einteilung = KurseMeineEinteilung.bilden(aus: [], jetzt: jetzt, zeitzone: zeitzone)
        #expect(einteilung.istLeer)
    }
}

/// `KurseMeineAbmeldeZustand.fuer` -- Review-Fund M2: mehrere Zeilen
/// koennen gleichzeitig ihre Abmeldung versuchen, und jede muss ihren
/// EIGENEN Zustand tragen, unabhaengig von den anderen.
struct KurseMeineAbmeldeZustandTests {
    @Test func ohneLaufendenVersuchUndOhneFehlerIstBereit() {
        let zustand = KurseMeineAbmeldeZustand.fuer(sessionId: "a", laufende: [], fehlermeldungen: [:])
        #expect(zustand == .bereit)
    }

    /// Zwei Zeilen gleichzeitig in Arbeit -- jede erscheint fuer ihre
    /// eigene sessionId als "laeuft", eine dritte, unbeteiligte Zeile
    /// bleibt "bereit".
    @Test func zweiGleichzeitigLaufendeVersucheStimmenJeFuerSich() {
        let laufende: Set<String> = ["a", "b"]

        #expect(KurseMeineAbmeldeZustand.fuer(sessionId: "a", laufende: laufende, fehlermeldungen: [:]) == .laeuft)
        #expect(KurseMeineAbmeldeZustand.fuer(sessionId: "b", laufende: laufende, fehlermeldungen: [:]) == .laeuft)
        #expect(KurseMeineAbmeldeZustand.fuer(sessionId: "c", laufende: laufende, fehlermeldungen: [:]) == .bereit)
    }

    /// Ein Fehler gehoert zu GENAU seiner sessionId -- eine andere Zeile
    /// mit einem eigenen Fehler bleibt davon unberuehrt.
    @Test func fehlerGehoertZuSeinerEigenenZeile() {
        let fehlermeldungen = ["a": "Der Platz ist bereits vergeben.", "b": "Keine Verbindung."]

        #expect(
            KurseMeineAbmeldeZustand.fuer(sessionId: "a", laufende: [], fehlermeldungen: fehlermeldungen)
                == .fehlgeschlagen("Der Platz ist bereits vergeben."))
        #expect(
            KurseMeineAbmeldeZustand.fuer(sessionId: "b", laufende: [], fehlermeldungen: fehlermeldungen)
                == .fehlgeschlagen("Keine Verbindung."))
        #expect(KurseMeineAbmeldeZustand.fuer(sessionId: "c", laufende: [], fehlermeldungen: fehlermeldungen) == .bereit)
    }

    /// Laeuft ein NEUER Versuch fuer eine Zeile, deren voriger Versuch
    /// fehlgeschlagen war, gewinnt "laeuft" -- der alte Fehler wird beim
    /// Neustart des Versuchs geloescht (KurseMeineView.abmelden), diese
    /// Ableitung selbst priorisiert `laufende` ohnehin zuerst.
    @Test func laufenderVersuchGewinntGegenEinenAltenFehlerDerselbenZeile() {
        let zustand = KurseMeineAbmeldeZustand.fuer(
            sessionId: "a", laufende: ["a"], fehlermeldungen: ["a": "Keine Verbindung."])
        #expect(zustand == .laeuft)
    }
}
