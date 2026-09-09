import Foundation
import Testing
@testable import FitnessMember

/// Die Sechsertabelle aus dem Aufgabenbrief zu Aufgabe 10 (Spec Abschnitt
/// 5.3) -- Zustand zu Hauptaktion und Fusstext, wortwoertlich.
struct KursDetailInhaltTests {
    @Test func abgesagtHatKeineHauptaktion() {
        #expect(KursDetailInhalt.hauptaktion(fuer: .abgesagt, abmeldefristVerstrichen: false, belegungGilt: true) == nil)
        #expect(
            KursDetailInhalt.fusstext(
                fuer: .abgesagt, abmeldenBisUhrzeit: nil, abmeldefristVerstrichen: false, wartelistenplatz: nil, belegungGilt: true)
                == "Dein Studio hat diesen Termin abgesagt.")
    }

    @Test func vorbeiHatKeineHauptaktion() {
        #expect(KursDetailInhalt.hauptaktion(fuer: .vorbei, abmeldefristVerstrichen: false, belegungGilt: true) == nil)
        #expect(
            KursDetailInhalt.fusstext(
                fuer: .vorbei, abmeldenBisUhrzeit: nil, abmeldefristVerstrichen: false, wartelistenplatz: nil, belegungGilt: true)
                == "Dieser Termin ist vorbei.")
    }

    @Test func angemeldetBietetAbmelden() {
        #expect(KursDetailInhalt.hauptaktion(fuer: .angemeldet, abmeldefristVerstrichen: false, belegungGilt: true) == .abmelden)
        #expect(
            KursDetailInhalt.fusstext(
                fuer: .angemeldet, abmeldenBisUhrzeit: "16:00", abmeldefristVerstrichen: false,
                wartelistenplatz: nil, belegungGilt: true)
                == "Abmelden ist bis 16:00 möglich.")
    }

    /// Eine unlesbare Abmeldefrist entfaellt ersatzlos -- eine erfundene
    /// Uhrzeit waere schlimmer als keine (Aufgabenbrief).
    @Test func angemeldetOhneLesbareFristZeigtKeineZeile() {
        #expect(
            KursDetailInhalt.fusstext(
                fuer: .angemeldet, abmeldenBisUhrzeit: nil, abmeldefristVerstrichen: false, wartelistenplatz: nil, belegungGilt: true)
                == nil)
    }

    /// Review-Fund: nach Fristablauf verschwindet "Abmelden" ganz -- kein
    /// deaktivierter Knopf, der Wirkung vortaeuscht --, und der Fusstext
    /// sagt, was gilt (der Platz bleibt reserviert), statt weiter eine
    /// Uhrzeit zu nennen, die der Server nicht mehr einloest.
    @Test func angemeldetNachVerstrichenerFristVerliertDenKnopf() {
        #expect(KursDetailInhalt.hauptaktion(fuer: .angemeldet, abmeldefristVerstrichen: true, belegungGilt: true) == nil)
        #expect(
            KursDetailInhalt.fusstext(
                fuer: .angemeldet, abmeldenBisUhrzeit: "16:00", abmeldefristVerstrichen: true,
                wartelistenplatz: nil, belegungGilt: true)
                == "Die Abmeldefrist ist verstrichen. Dein Platz bleibt reserviert.")
    }

    /// `.warteliste` bleibt von der Abmeldefrist unberuehrt --
    /// `cancel_course_booking` (0038_kurse_nachlese.sql) prueft sie
    /// ausdruecklich nur fuer einen gebuchten (nicht gewartelisteten)
    /// Platz.
    @Test func wartelisteBietetVerlassenUnabhaengigVonDerFrist() {
        #expect(KursDetailInhalt.hauptaktion(fuer: .warteliste, abmeldefristVerstrichen: false, belegungGilt: true) == .wartelisteVerlassen)
        #expect(KursDetailInhalt.hauptaktion(fuer: .warteliste, abmeldefristVerstrichen: true, belegungGilt: true) == .wartelisteVerlassen)
        #expect(
            KursDetailInhalt.fusstext(
                fuer: .warteliste, abmeldenBisUhrzeit: nil, abmeldefristVerstrichen: true, wartelistenplatz: 3, belegungGilt: true)
                == "Du stehst auf Platz 3.")
    }

    /// Ohne Netz ist die Position nicht bekannt (GespeicherterTermin
    /// traegt sie nicht) -- statt einer erfundenen Position (oder gar
    /// nichts) steht der Satz ohne Nummer da. Nie stumm.
    @Test func wartelisteOhneBekanntePositionNenntKeineNummer() {
        #expect(
            KursDetailInhalt.fusstext(
                fuer: .warteliste, abmeldenBisUhrzeit: nil, abmeldefristVerstrichen: false, wartelistenplatz: nil, belegungGilt: true)
                == "Du stehst auf der Warteliste.")
    }

    // MARK: - Ohne frische Belegung
    //
    // `.frei` und `.voll` leiten sich beide allein aus `freeSeats` ab, die
    // Wartelistenposition aendert sich ohne Zutun des Mitglieds. Beides
    // darf aus einem alten Abruf nicht weitererzaehlt werden -- siehe
    // KurseHerkunft.zeigtBelegung.

    @Test func ohneFrischeBelegungBehauptetNichtsUeberDenFuellstand() {
        #expect(
            KursDetailInhalt.fusstext(
                fuer: .voll, abmeldenBisUhrzeit: nil, abmeldefristVerstrichen: false,
                wartelistenplatz: nil, belegungGilt: false)
                == "Wie viele Plätze frei sind, wissen wir gerade nicht — bei einem vollen Kurs kommst du auf die Warteliste.")
        #expect(
            KursDetailInhalt.fusstext(
                fuer: .frei, abmeldenBisUhrzeit: "16:00", abmeldefristVerstrichen: false,
                wartelistenplatz: nil, belegungGilt: false)
                == "Wie viele Plätze frei sind, wissen wir gerade nicht — bei einem vollen Kurs kommst du auf die Warteliste. Abmelden ist bis 16:00 möglich.")
    }

    /// "Auf die Warteliste" waere eine Behauptung ueber einen Fuellstand
    /// von vorhin. `.anmelden` stimmt in beiden Faellen: dieselbe Route
    /// legt Buchung oder Wartelistenplatz an, der Server entscheidet.
    @Test func ohneFrischeBelegungHeisstDieHauptaktionAnmelden() {
        #expect(
            KursDetailInhalt.hauptaktion(fuer: .voll, abmeldefristVerstrichen: false, belegungGilt: false)
                == .anmelden)
        #expect(
            KursDetailInhalt.hauptaktion(fuer: .frei, abmeldefristVerstrichen: false, belegungGilt: false)
                == .anmelden)
    }

    /// Die uebrigen vier Zustaende haengen nicht an freeSeats und bleiben
    /// unveraendert -- `belegungGilt` darf sie nicht mitreissen.
    @Test func ohneFrischeBelegungBleibenDieUebrigenZustaendeGleich() {
        for zustand in [KursZustand.abgesagt, .vorbei, .angemeldet, .warteliste] {
            #expect(
                KursDetailInhalt.hauptaktion(fuer: zustand, abmeldefristVerstrichen: false, belegungGilt: false)
                    == KursDetailInhalt.hauptaktion(fuer: zustand, abmeldefristVerstrichen: false, belegungGilt: true))
            #expect(
                KursDetailInhalt.fusstext(
                    fuer: zustand, abmeldenBisUhrzeit: "16:00", abmeldefristVerstrichen: false,
                    wartelistenplatz: 3, belegungGilt: false)
                    == KursDetailInhalt.fusstext(
                        fuer: zustand, abmeldenBisUhrzeit: "16:00", abmeldefristVerstrichen: false,
                        wartelistenplatz: 3, belegungGilt: true))
        }
    }

    @Test func freiBietetAnmelden() {
        #expect(KursDetailInhalt.hauptaktion(fuer: .frei, abmeldefristVerstrichen: false, belegungGilt: true) == .anmelden)
        #expect(
            KursDetailInhalt.fusstext(
                fuer: .frei, abmeldenBisUhrzeit: "16:00", abmeldefristVerstrichen: false, wartelistenplatz: nil, belegungGilt: true)
                == "Abmelden ist bis 16:00 möglich.")
    }

    @Test func voll() {
        #expect(KursDetailInhalt.hauptaktion(fuer: .voll, abmeldefristVerstrichen: false, belegungGilt: true) == .aufWarteliste)
        #expect(
            KursDetailInhalt.fusstext(
                fuer: .voll, abmeldenBisUhrzeit: nil, abmeldefristVerstrichen: false, wartelistenplatz: nil, belegungGilt: true)
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

/// `KursDetailInhalt.abmeldefristVerstrichen(startsAt:fristStunden:jetzt:)`
/// -- derselbe Termin, feste Zeitpunkte vor/nach der Frist und der
/// Grenzfall auf die Sekunde. Kein `Date()`.
struct KursDetailAbmeldefristVerstrichenTests {
    /// 2026-09-04T18:00:00Z -- Kursbeginn. Zwei Stunden Frist ergeben
    /// 2026-09-04T16:00:00Z als spaetesten Abmeldezeitpunkt.
    private let beginn = "2026-09-04T18:00:00Z"
    private let fristStunden = 2

    @Test func vorDerFristNichtVerstrichen() {
        let jetzt = ISO8601DateFormatter().date(from: "2026-09-04T15:59:59Z")!
        #expect(
            !KursDetailInhalt.abmeldefristVerstrichen(startsAt: beginn, fristStunden: fristStunden, jetzt: jetzt))
    }

    /// Grenzfall: exakt auf die Sekunde gilt die Frist bereits als
    /// verstrichen (>=), derselbe Vergleich wie beim Kursbeginn selbst.
    @Test func genauAmGrenzzeitpunktVerstrichen() {
        let jetzt = ISO8601DateFormatter().date(from: "2026-09-04T16:00:00Z")!
        #expect(
            KursDetailInhalt.abmeldefristVerstrichen(startsAt: beginn, fristStunden: fristStunden, jetzt: jetzt))
    }

    @Test func nachDerFristVerstrichen() {
        let jetzt = ISO8601DateFormatter().date(from: "2026-09-04T16:00:01Z")!
        #expect(
            KursDetailInhalt.abmeldefristVerstrichen(startsAt: beginn, fristStunden: fristStunden, jetzt: jetzt))
    }

    /// Ein unlesbarer Beginn liefert `false`, nicht `true` -- sonst
    /// verschwaende "Abmelden" wegen eines Datenfehlers statt nur die
    /// Uhrzeit-Zeile.
    @Test func unlesbarerBeginnGiltAlsNichtVerstrichen() {
        #expect(
            !KursDetailInhalt.abmeldefristVerstrichen(
                startsAt: "keine-gueltige-zeit", fristStunden: fristStunden, jetzt: Date(timeIntervalSince1970: 0)))
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
