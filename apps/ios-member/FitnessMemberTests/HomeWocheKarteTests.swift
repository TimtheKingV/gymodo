import Foundation
import Testing
@testable import FitnessMember

/// Die Woche auf Home (Leinwand 2d): sieben Felder Mo–So, heute hervorgehoben,
/// erledigte Termine gedeckt, darunter "1 von 4 Terminen erledigt".
struct HomeWocheKarteTests {
    private var kalender: Calendar {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: "Europe/Berlin")!
        k.locale = Locale(identifier: "de_DE")
        return k
    }

    /// Mittwoch, 28. Oktober 2026, 10:00 in Berlin.
    private var mittwoch: Date {
        kalender.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 10))!
    }

    private let raster = [
        Rasterplatz(tag: 1, art: .kurs, einheitKey: nil),
        Rasterplatz(tag: 3, art: .kraft, einheitKey: "A"),
        Rasterplatz(tag: 5, art: .kraft, einheitKey: "B"),
        Rasterplatz(tag: 7, art: .cardio, einheitKey: nil),
    ]

    private func kurs(tag: String, stunde: Int, ownStatus: String? = "booked", status: String = "planned") -> CourseWeekSession {
        let teile = tag.split(separator: "-").map { Int($0)! }
        let beginn = kalender.date(from: DateComponents(year: teile[0], month: teile[1], day: teile[2], hour: stunde))!
        return CourseWeekSession(
            sessionId: UUID().uuidString, templateId: "t1", name: "Rücken Fit",
            description: nil, startsAt: ISO8601DateFormatter().string(from: beginn),
            localDay: tag, durationMin: 60, capacity: 16,
            room: nil, instructorName: nil, status: status,
            bookedCount: 12, waitlistCount: 0, freeSeats: 4,
            ownStatus: ownStatus, ownBookingId: ownStatus == nil ? nil : "b1",
            ownWaitlistPosition: nil)
    }

    // MARK: - Felder

    @Test func siebenFelderMontagBisSonntag() {
        let felder = HomeWoche.zeilen(raster: raster, erledigt: [], heute: mittwoch, kalender: kalender)
        #expect(felder.map(\.tag) == [1, 2, 3, 4, 5, 6, 7])
        #expect(felder.map(\.art) == [.kurs, nil, .kraft, nil, .kraft, nil, .cardio])
        #expect(felder.map(\.label) == ["K", "", "A", "", "B", "", ""])
    }

    @Test func mittwochIstHeute() {
        let felder = HomeWoche.zeilen(raster: raster, erledigt: [], heute: mittwoch, kalender: kalender)
        #expect(felder.filter(\.istHeute).map(\.tag) == [3])
    }

    @Test func erledigtKommtAusDerMenge() {
        let felder = HomeWoche.zeilen(raster: raster, erledigt: [1], heute: mittwoch, kalender: kalender)
        #expect(felder.filter(\.erledigt).map(\.tag) == [1])
    }

    @Test func erledigtNurAnTagenMitTermin() {
        // Ein erledigter Tag ohne Termin (etwa ein Kurs, der nicht im Raster steht und
        // nicht nachgereicht wurde) zaehlt nicht.
        let felder = HomeWoche.zeilen(raster: raster, erledigt: [2], heute: mittwoch, kalender: kalender)
        #expect(felder.filter(\.erledigt).isEmpty)
    }

    // MARK: - Erledigt

    @Test func montagErledigtMitBesuchterAnmeldung() {
        let tage = HomeWoche.erledigteTage(
            raster: raster, kurse: [kurs(tag: "2026-10-26", stunde: 18)], cardioErledigt: [],
            heute: mittwoch, kalender: kalender)
        #expect(tage == [1])
    }

    @Test func ohneAnmeldungNichtsErledigt() {
        let tage = HomeWoche.erledigteTage(
            raster: raster, kurse: [kurs(tag: "2026-10-26", stunde: 18, ownStatus: nil)], cardioErledigt: [],
            heute: mittwoch, kalender: kalender)
        #expect(tage.isEmpty)
    }

    @Test func warteslisteUndAbgesagtZaehlenNicht() {
        let tage = HomeWoche.erledigteTage(
            raster: raster,
            kurse: [kurs(tag: "2026-10-26", stunde: 18, ownStatus: "waitlisted"),
                    kurs(tag: "2026-10-26", stunde: 19, status: "cancelled")],
            cardioErledigt: [], heute: mittwoch, kalender: kalender)
        #expect(tage.isEmpty)
    }

    @Test func kuenftigeAnmeldungIstNochNichtErledigt() {
        let raster = raster + [Rasterplatz(tag: 4, art: .kurs, einheitKey: nil)]
        let tage = HomeWoche.erledigteTage(
            raster: raster, kurse: [kurs(tag: "2026-10-29", stunde: 18)], cardioErledigt: [],
            heute: mittwoch, kalender: kalender)
        #expect(tage.isEmpty)
    }

    @Test func cardioErledigtAusDenChecks() {
        let tage = HomeWoche.erledigteTage(
            raster: raster, kurse: [], cardioErledigt: ["2026-11-01", "2026-10-25"],
            heute: mittwoch, kalender: kalender)
        #expect(tage == [7])
    }

    @Test func krafttageHabenKeineQuelle() {
        // Einheiten haben keine "erledigt"-Datenquelle (Ruling): nie gedeckt.
        let tage = HomeWoche.erledigteTage(
            raster: raster, kurse: [], cardioErledigt: ["2026-10-28"], heute: mittwoch, kalender: kalender)
        #expect(tage.isEmpty)
    }

    // MARK: - Gebuchte Kurse

    @Test func gebuchterKursAusserhalbDesRastersErscheint() {
        let ergaenzt = HomeWoche.mitGebuchtenKursen(
            raster: raster, kurse: [kurs(tag: "2026-10-27", stunde: 18)], heute: mittwoch, kalender: kalender)
        let felder = HomeWoche.zeilen(raster: ergaenzt, erledigt: [], heute: mittwoch, kalender: kalender)
        #expect(felder[1].art == .kurs)
        #expect(felder[1].label == "K")
    }

    @Test func kursAusAndererWocheUndUngebuchterBleibenDraussen() {
        let ergaenzt = HomeWoche.mitGebuchtenKursen(
            raster: raster,
            kurse: [kurs(tag: "2026-11-03", stunde: 18), kurs(tag: "2026-10-27", stunde: 18, ownStatus: nil)],
            heute: mittwoch, kalender: kalender)
        #expect(ergaenzt == raster)
    }

    @Test func gebuchterKursAnEinemKrafttagLaesstDieEinheitStehen() {
        let ergaenzt = HomeWoche.mitGebuchtenKursen(
            raster: raster, kurse: [kurs(tag: "2026-10-28", stunde: 18)], heute: mittwoch, kalender: kalender)
        let felder = HomeWoche.zeilen(raster: ergaenzt, erledigt: [], heute: mittwoch, kalender: kalender)
        #expect(felder[2].art == .kraft)
        #expect(felder[2].label == "A")
    }

    // MARK: - Zusammenfassung

    @Test func zusammenfassungZaehltTermine() {
        let felder = HomeWoche.zeilen(raster: raster, erledigt: [1], heute: mittwoch, kalender: kalender)
        #expect(HomeWoche.zusammenfassung(felder) == "1 von 4 Terminen erledigt")
        #expect(HomeWoche.legende(felder) == "K Kurs")
    }

    @Test func zusammenfassungEinzahlUndLeer() {
        let einer = HomeWoche.zeilen(
            raster: [Rasterplatz(tag: 2, art: .kraft, einheitKey: "A")], erledigt: [], heute: mittwoch, kalender: kalender)
        #expect(HomeWoche.zusammenfassung(einer) == "0 von 1 Termin erledigt")
        #expect(HomeWoche.legende(einer) == nil)

        let leer = HomeWoche.zeilen(raster: [], erledigt: [], heute: mittwoch, kalender: kalender)
        #expect(HomeWoche.zusammenfassung(leer) == "Diese Woche ist nichts geplant")
    }

    @Test func sprechtextNenntTagArtUndStand() {
        let felder = HomeWoche.zeilen(raster: raster, erledigt: [1], heute: mittwoch, kalender: kalender)
        #expect(HomeWoche.sprechtext(felder[0]) == "Montag, Kurs, erledigt")
        #expect(HomeWoche.sprechtext(felder[1]) == "Dienstag, nichts geplant")
        #expect(HomeWoche.sprechtext(felder[2]) == "Mittwoch, heute, Einheit A")
        #expect(HomeWoche.sprechtext(felder[6]) == "Sonntag, Cardio")
    }

    // MARK: - Als nächstes

    @Test func alsNaechstesIstDerNaechsteTerminNachHeute() {
        let naechster = HomeWoche.alsNaechstes(
            raster: raster, kurse: [], cardioErledigt: [], heute: mittwoch, kalender: kalender)
        #expect(naechster == HomeNaechster(titel: "Einheit B", tag: "Fr", sprechTag: "Freitag", ziel: .einheit(key: "B")))
    }

    @Test func alsNaechstesCardioFuehrtZumTag() {
        let freitag = kalender.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 10))!
        let naechster = HomeWoche.alsNaechstes(
            raster: raster, kurse: [], cardioErledigt: [], heute: freitag, kalender: kalender)
        let sonntag = kalender.date(from: DateComponents(year: 2026, month: 11, day: 1))!
        #expect(naechster == HomeNaechster(titel: "Cardio", tag: "So", sprechTag: "Sonntag", ziel: .tag(sonntag)))
    }

    @Test func alsNaechstesReichtInDieNaechsteWoche() {
        let sonntag = kalender.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 10))!
        // Der Kurs am Montag steht nur im Raster, ohne Anmeldung: kein Termin.
        // Der naechste ist die Einheit A am Mittwoch der Folgewoche.
        let naechster = HomeWoche.alsNaechstes(
            raster: raster, kurse: [], cardioErledigt: [], heute: sonntag, kalender: kalender)
        #expect(naechster?.ziel == .einheit(key: "A"))
        #expect(naechster?.tag == "Mi")
    }

    @Test func alsNaechstesGebuchterKursFuehrtZumTag() {
        let naechster = HomeWoche.alsNaechstes(
            raster: raster, kurse: [kurs(tag: "2026-10-29", stunde: 18)], cardioErledigt: [],
            heute: mittwoch, kalender: kalender)
        let donnerstag = kalender.date(from: DateComponents(year: 2026, month: 10, day: 29))!
        #expect(naechster == HomeNaechster(titel: "Rücken Fit", tag: "Do", sprechTag: "Donnerstag", ziel: .tag(donnerstag)))
    }

    @Test func ohneTermineKeinAlsNaechstes() {
        #expect(HomeWoche.alsNaechstes(raster: [], kurse: [], cardioErledigt: [], heute: mittwoch, kalender: kalender) == nil)
    }

    // MARK: - Cardio-Checks teilen

    @Test func cardioLadenErsetztNurDenGeladenenBereich() {
        let alt: Set<String> = ["2026-10-20", "2026-10-27", "2026-11-03"]
        let neu = CardioChecksStore.zusammenfuehren(
            alt: alt, neu: ["2026-10-28"], von: "2026-10-26", bis: "2026-11-01")
        #expect(neu == ["2026-10-20", "2026-10-28", "2026-11-03"])
    }
}
