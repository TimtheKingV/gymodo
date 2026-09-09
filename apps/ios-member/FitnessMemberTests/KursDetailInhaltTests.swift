import Foundation
import Testing
@testable import FitnessMember

/// Die Sechsertabelle aus dem Aufgabenbrief zu Aufgabe 10 (Spec Abschnitt
/// 5.3) -- Zustand zu Hauptaktion und Fusstext, wortwoertlich.
struct KursDetailInhaltTests {
    @Test func abgesagtHatKeineHauptaktion() {
        #expect(KursDetailInhalt.hauptaktion(fuer: .abgesagt) == nil)
        #expect(
            KursDetailInhalt.fusstext(fuer: .abgesagt, abmeldenBisUhrzeit: nil, wartelistenplatz: nil)
                == "Dein Studio hat diesen Termin abgesagt.")
    }

    @Test func vorbeiHatKeineHauptaktion() {
        #expect(KursDetailInhalt.hauptaktion(fuer: .vorbei) == nil)
        #expect(
            KursDetailInhalt.fusstext(fuer: .vorbei, abmeldenBisUhrzeit: nil, wartelistenplatz: nil)
                == "Dieser Termin ist vorbei.")
    }

    @Test func angemeldetBietetAbmelden() {
        #expect(KursDetailInhalt.hauptaktion(fuer: .angemeldet) == .abmelden)
        #expect(
            KursDetailInhalt.fusstext(fuer: .angemeldet, abmeldenBisUhrzeit: "16:00", wartelistenplatz: nil)
                == "Abmelden ist bis 16:00 möglich.")
    }

    /// Eine unlesbare Abmeldefrist entfaellt ersatzlos -- eine erfundene
    /// Uhrzeit waere schlimmer als keine (Aufgabenbrief).
    @Test func angemeldetOhneLesbareFristZeigtKeineZeile() {
        #expect(
            KursDetailInhalt.fusstext(fuer: .angemeldet, abmeldenBisUhrzeit: nil, wartelistenplatz: nil) == nil)
    }

    @Test func wartelisteBietetVerlassen() {
        #expect(KursDetailInhalt.hauptaktion(fuer: .warteliste) == .wartelisteVerlassen)
        #expect(
            KursDetailInhalt.fusstext(fuer: .warteliste, abmeldenBisUhrzeit: nil, wartelistenplatz: 3)
                == "Du stehst auf Platz 3.")
    }

    /// Ohne Netz ist die Position nicht bekannt (GespeicherterTermin
    /// traegt sie nicht) -- die Zeile entfaellt, statt eine erfundene
    /// Position zu zeigen.
    @Test func wartelisteOhneBekanntePositionZeigtKeineZeile() {
        #expect(
            KursDetailInhalt.fusstext(fuer: .warteliste, abmeldenBisUhrzeit: nil, wartelistenplatz: nil) == nil)
    }

    @Test func freiBietetAnmelden() {
        #expect(KursDetailInhalt.hauptaktion(fuer: .frei) == .anmelden)
        #expect(
            KursDetailInhalt.fusstext(fuer: .frei, abmeldenBisUhrzeit: "16:00", wartelistenplatz: nil)
                == "Abmelden ist bis 16:00 möglich.")
    }

    @Test func voll() {
        #expect(KursDetailInhalt.hauptaktion(fuer: .voll) == .aufWarteliste)
        #expect(
            KursDetailInhalt.fusstext(fuer: .voll, abmeldenBisUhrzeit: nil, wartelistenplatz: nil)
                == "Alle Plätze sind vergeben.")
    }

    @Test func anmeldenUndAufDieWartelisteRufenBuchen() {
        #expect(KursDetailHauptaktion.anmelden.istBuchen)
        #expect(KursDetailHauptaktion.aufWarteliste.istBuchen)
    }

    @Test func abmeldenUndWartelisteVerlassenRufenStornieren() {
        #expect(!KursDetailHauptaktion.abmelden.istBuchen)
        #expect(!KursDetailHauptaktion.wartelisteVerlassen.istBuchen)
    }
}

/// Die schmale Zustandsauswertung eines ohne Netz gespeicherten Termins
/// (`GespeicherterTermin`) -- dieselbe Auswertungsreihenfolge wie
/// `KursZustandRechner.zustand(fuer:)`, nur ohne `.frei`/`.voll`.
struct KursDetailOfflineZustandTests {
    private let jetzt = Date(timeIntervalSince1970: 1_757_000_000)

    private func termin(
        startVersatzStunden: Double = 3, status: String = "planned", ownStatus: String = "booked"
    ) -> GespeicherterTermin {
        GespeicherterTermin(
            CourseWeekSession(
                sessionId: "k1", templateId: "t1", name: "Kraftzirkel", description: nil,
                startsAt: ISO8601DateFormatter().string(
                    from: jetzt.addingTimeInterval(startVersatzStunden * 3600)),
                localDay: "2026-09-08", durationMin: 60, capacity: 16,
                room: "Kursraum 2", instructorName: "Marek T.", status: status,
                bookedCount: 12, waitlistCount: 0, freeSeats: 4,
                ownStatus: ownStatus, ownBookingId: "b1", ownWaitlistPosition: nil))
    }

    @Test func abgesagtSchlaegtAlles() {
        let abgesagtUndAngemeldet = termin(status: "cancelled", ownStatus: "booked")
        #expect(KursDetailOfflineZustand.zustand(fuer: abgesagtUndAngemeldet, jetzt: jetzt) == .abgesagt)
    }

    @Test func vorbeiSchlaegtDenEigenenStatus() {
        let vorbeiUndAngemeldet = termin(startVersatzStunden: -2, ownStatus: "booked")
        #expect(KursDetailOfflineZustand.zustand(fuer: vorbeiUndAngemeldet, jetzt: jetzt) == .vorbei)
    }

    @Test func angemeldet() {
        #expect(KursDetailOfflineZustand.zustand(fuer: termin(ownStatus: "booked"), jetzt: jetzt) == .angemeldet)
    }

    @Test func warteliste() {
        #expect(
            KursDetailOfflineZustand.zustand(fuer: termin(ownStatus: "waitlisted"), jetzt: jetzt) == .warteliste)
    }
}
