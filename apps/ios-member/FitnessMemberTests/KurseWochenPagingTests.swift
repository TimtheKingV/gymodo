import Foundation
import Testing
@testable import FitnessMember

/// Wie viele Wochen sich wischen lassen -- und warum nicht mehr.
struct KurseWochenPagingTests {
    private let zeitzone = "Europe/Berlin"

    private func zeitpunkt(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)!
    }

    private func tagId(_ datum: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: zeitzone)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: datum)
    }

    // MARK: - Welche Wochen das Ladefenster hergibt

    /// Das Fenster reicht bis "jetzt + 14 Tage". Gewischt wird nur in
    /// Wochen, die VOLLSTAENDIG darin liegen -- eine angebrochene dritte
    /// Woche saehe aus wie ein Studio ohne Kursplan.
    @Test func dasFensterTraegtGenauZweiVollstaendigeWochen() {
        // Mittwoch, 9. September 2026, 14:00 Ortszeit.
        let mittwoch = zeitpunkt("2026-09-09T12:00:00Z")

        let montage = KurseWochenBerechnung.wochenMontage(ab: mittwoch, zeitzone: zeitzone)

        #expect(montage.count == 2)
        #expect(tagId(montage[0]) == "2026-09-07")
        #expect(tagId(montage[1]) == "2026-09-14")
    }

    @Test func amMontagBleibtEsBeiZweiWochen() {
        let montag = zeitpunkt("2026-09-07T06:00:00Z")

        let montage = KurseWochenBerechnung.wochenMontage(ab: montag, zeitzone: zeitzone)

        #expect(montage.map(tagId) == ["2026-09-07", "2026-09-14"])
    }

    /// Der Sonntag ist der Grenzfall: die laufende Woche ist fast vorbei,
    /// die uebernaechste ragt am weitesten ins Fenster. Trotzdem ist sie
    /// nicht vollstaendig drin.
    @Test func amSonntagAbendBleibtEsBeiZweiWochen() {
        let sonntag = zeitpunkt("2026-09-13T21:00:00Z")

        let montage = KurseWochenBerechnung.wochenMontage(ab: sonntag, zeitzone: zeitzone)

        #expect(montage.map(tagId) == ["2026-09-07", "2026-09-14"])
    }

    @Test func dieErsteSeiteIstImmerDieLaufendeWoche() {
        for tag in ["2026-09-07", "2026-09-09", "2026-09-13"] {
            let jetzt = zeitpunkt("\(tag)T10:00:00Z")
            let montage = KurseWochenBerechnung.wochenMontage(ab: jetzt, zeitzone: zeitzone)

            #expect(montage.first == KurseWochenBerechnung.montag(enthaelt: jetzt, zeitzone: zeitzone))
        }
    }

    /// Zurueck in vergangene Wochen gibt es nicht -- das Fenster beginnt
    /// am Montag dieser Woche, davor haette der Streifen keine Daten.
    @Test func esGibtKeineSeiteVorDerLaufendenWoche() {
        let mittwoch = zeitpunkt("2026-09-09T12:00:00Z")
        let montag = KurseWochenBerechnung.montag(enthaelt: mittwoch, zeitzone: zeitzone)

        let montage = KurseWochenBerechnung.wochenMontage(ab: mittwoch, zeitzone: zeitzone)

        #expect(montage.allSatisfy { $0 >= montag })
    }

    // MARK: - Die sieben Tage einer beliebigen Woche

    @Test func einAndererMontagLiefertSeineEigenenSiebenTage() {
        let mittwoch = zeitpunkt("2026-09-09T12:00:00Z")
        let naechsterMontag = KurseWochenBerechnung.wochenMontage(ab: mittwoch, zeitzone: zeitzone)[1]

        let tage = KurseWochenBerechnung.wochentage(
            abMontag: naechsterMontag, jetzt: mittwoch, zeitzone: zeitzone)

        #expect(tage.count == 7)
        #expect(tage.map(\.id) == [
            "2026-09-14", "2026-09-15", "2026-09-16", "2026-09-17",
            "2026-09-18", "2026-09-19", "2026-09-20"])
        #expect(tage.first?.kuerzel == "Mo")
    }

    /// In einer kuenftigen Woche ist kein Tag "heute" -- sonst truege der
    /// Streifen dort eine Akzentflaeche ohne Anlass.
    @Test func inEinerKuenftigenWocheIstKeinTagHeute() {
        let mittwoch = zeitpunkt("2026-09-09T12:00:00Z")
        let naechsterMontag = KurseWochenBerechnung.wochenMontage(ab: mittwoch, zeitzone: zeitzone)[1]

        let tage = KurseWochenBerechnung.wochentage(
            abMontag: naechsterMontag, jetzt: mittwoch, zeitzone: zeitzone)

        #expect(tage.allSatisfy { !$0.istHeute })
    }

    @Test func inDerLaufendenWocheIstGenauEinTagHeute() {
        let mittwoch = zeitpunkt("2026-09-09T12:00:00Z")
        let montag = KurseWochenBerechnung.montag(enthaelt: mittwoch, zeitzone: zeitzone)

        let tage = KurseWochenBerechnung.wochentage(
            abMontag: montag, jetzt: mittwoch, zeitzone: zeitzone)

        #expect(tage.filter(\.istHeute).map(\.id) == ["2026-09-09"])
    }
}

/// Welcher Tag gilt -- und was passiert, wenn der gemerkte Tag aus dem
/// Ladefenster herausgefallen ist.
struct KurseGueltigerTagTests {
    private let zeitzone = "Europe/Berlin"

    private func zeitpunkt(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)!
    }

    @Test func ohneAuswahlGiltDerHeutigeTag() {
        let mittwoch = zeitpunkt("2026-09-09T12:00:00Z")

        let tag = KurseWochenBerechnung.gueltigerTag(
            gewaehlt: nil, jetzt: mittwoch, zeitzone: zeitzone)

        #expect(tag == "2026-09-09")
    }

    @Test func einTagAusDenGeladenenWochenBleibtStehen() {
        let mittwoch = zeitpunkt("2026-09-09T12:00:00Z")

        let tag = KurseWochenBerechnung.gueltigerTag(
            gewaehlt: "2026-09-17", jetzt: mittwoch, zeitzone: zeitzone)

        #expect(tag == "2026-09-17")
    }

    /// Bleibt die App ueber den Wochenwechsel offen, faellt der gemerkte
    /// Tag irgendwann hinten aus dem Fenster. Ohne diesen Rueckfall stuende
    /// der Streifen auf einer Woche, zu der es keine Tagesliste mehr gibt
    /// -- ein leerer Screen ohne jede Erklaerung.
    @Test func einTagVorDemFensterFaelltAufHeuteZurueck() {
        let mittwoch = zeitpunkt("2026-09-09T12:00:00Z")

        let tag = KurseWochenBerechnung.gueltigerTag(
            gewaehlt: "2026-09-01", jetzt: mittwoch, zeitzone: zeitzone)

        #expect(tag == "2026-09-09")
    }

    @Test func einTagHinterDemFensterFaelltAufHeuteZurueck() {
        let mittwoch = zeitpunkt("2026-09-09T12:00:00Z")

        let tag = KurseWochenBerechnung.gueltigerTag(
            gewaehlt: "2026-10-05", jetzt: mittwoch, zeitzone: zeitzone)

        #expect(tag == "2026-09-09")
    }

    @Test func einUnlesbarerTagFaelltAufHeuteZurueck() {
        let mittwoch = zeitpunkt("2026-09-09T12:00:00Z")

        let tag = KurseWochenBerechnung.gueltigerTag(
            gewaehlt: "übermorgen", jetzt: mittwoch, zeitzone: zeitzone)

        #expect(tag == "2026-09-09")
    }

    // MARK: - Der Montag zu einem Tag

    @Test func derMontagEinesTagesKommtOhneUmwegUeberDieSiebenTage() {
        let donnerstag = KurseWochenBerechnung.montag(fuerTagId: "2026-09-17", zeitzone: zeitzone)

        let erwartet = KurseWochenBerechnung.montag(
            enthaelt: zeitpunkt("2026-09-17T12:00:00Z"), zeitzone: zeitzone)
        #expect(donnerstag == erwartet)
    }

    @Test func einUnlesbarerTagHatKeinenMontag() {
        #expect(KurseWochenBerechnung.montag(fuerTagId: "kein Datum", zeitzone: zeitzone) == nil)
    }
}
