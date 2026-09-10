import Foundation
import Testing
@testable import FitnessMember

/// Zwei Texte, die der zusammengelegte Kurse-Screen neu braucht: die
/// Tagesueberschrift (die jetzt das Datum tragen muss) und der
/// Abmeldehinweis auf den Karten im Band.
struct KurseWochenInhaltTests {
    private let zeitzone = "Europe/Berlin"

    private func zeitpunkt(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)!
    }

    private func tage(_ jetzt: Date) -> [KurseWochentag] {
        KurseWochenBerechnung.wochentage(enthaelt: jetzt, zeitzone: zeitzone)
    }

    // MARK: - Tagesueberschrift

    /// Mit der Wochenleiste ist die einzige Monatsangabe des Screens
    /// verschwunden. Nach zwei Wischern stuenden sonst nur noch nackte
    /// Tagesnummern da -- die Ueberschrift traegt das Datum jetzt selbst.
    @Test func dieUeberschriftTraegtDasAusgeschriebeneDatum() {
        let mittwoch = zeitpunkt("2026-09-09T12:00:00Z")
        let donnerstag = tage(mittwoch).first { $0.id == "2026-09-10" }!

        let text = KurseWochenInhalt.tagesueberschrift(donnerstag, zeitzone: zeitzone)

        #expect(text == "Do, 10. September")
    }

    @Test func derHeutigeTagBleibtAlsHeuteMarkiert() {
        let mittwoch = zeitpunkt("2026-09-09T12:00:00Z")
        let heute = tage(mittwoch).first { $0.istHeute }!

        let text = KurseWochenInhalt.tagesueberschrift(heute, zeitzone: zeitzone)

        #expect(text == "Heute · Mi, 9. September")
    }

    /// Die Ueberschrift wird in Versalien gesetzt; der Monatsname darf
    /// deshalb nicht abgekuerzt sein, sonst steht dort "SEP.".
    @Test func derMonatStehtAusgeschrieben() {
        let mittwoch = zeitpunkt("2026-09-09T12:00:00Z")
        let sonntag = tage(mittwoch).first { $0.id == "2026-09-13" }!

        #expect(KurseWochenInhalt.tagesueberschrift(sonntag, zeitzone: zeitzone).hasSuffix("September"))
    }

    // MARK: - Abmeldehinweis im Band

    @Test func einBestaetigterPlatzNenntDieFrist() {
        let text = KurseWochenInhalt.abmeldehinweis(
            fuer: .angemeldet, abmeldenBisUhrzeit: "16:00", abmeldefristVerstrichen: false)

        #expect(text == "Abmelden ist bis 16:00 möglich.")
    }

    @Test func nachDerFristSagtDerHinweisWasStattdessenGilt() {
        let text = KurseWochenInhalt.abmeldehinweis(
            fuer: .angemeldet, abmeldenBisUhrzeit: "16:00", abmeldefristVerstrichen: true)

        #expect(text == "Die Abmeldefrist ist verstrichen. Dein Platz bleibt reserviert.")
    }

    /// 0036_kurse_platzvergabe.sql: die Stornofrist "trifft nur das
    /// Mitglied selbst, nur einen BESTAETIGTEN Platz und nur einen Termin,
    /// der stattfindet". Auf der Warteliste gibt es also keine Frist --
    /// eine zu nennen waere eine Falschaussage im Klartext.
    @Test func aufDerWartelisteGiltKeineFrist() {
        let text = KurseWochenInhalt.abmeldehinweis(
            fuer: .warteliste, abmeldenBisUhrzeit: "16:00", abmeldefristVerstrichen: true)

        #expect(text == "Abmelden ist jederzeit möglich.")
    }

    @Test func ohneBekannteFristBleibtDerHinweisWeg() {
        let text = KurseWochenInhalt.abmeldehinweis(
            fuer: .angemeldet, abmeldenBisUhrzeit: nil, abmeldefristVerstrichen: false)

        #expect(text == nil)
    }

    @Test func andereZustaendeTragenKeinenAbmeldehinweis() {
        for zustand: KursZustand in [.frei, .voll, .vorbei, .abgesagt] {
            #expect(KurseWochenInhalt.abmeldehinweis(
                fuer: zustand, abmeldenBisUhrzeit: "16:00", abmeldefristVerstrichen: false) == nil)
        }
    }

    // MARK: - Wann der Knopf daneben steht

    @Test func einBestaetigterPlatzVorDerFristLaesstSichAbmelden() {
        #expect(KurseWochenInhalt.zeigtAbmeldenKnopf(fuer: .angemeldet, abmeldefristVerstrichen: false))
    }

    @Test func nachDerFristVerschwindetDerKnopf() {
        #expect(!KurseWochenInhalt.zeigtAbmeldenKnopf(fuer: .angemeldet, abmeldefristVerstrichen: true))
    }

    /// Die Frist gilt fuer die Warteliste nicht -- der Knopf bleibt auch
    /// dann stehen, wenn sie fuer einen bestaetigten Platz laengst vorbei
    /// waere.
    @Test func vonDerWartelisteKommtManJederzeitRunter() {
        #expect(KurseWochenInhalt.zeigtAbmeldenKnopf(fuer: .warteliste, abmeldefristVerstrichen: true))
    }

    @Test func ohneEigenenPlatzGibtEsNichtsAbzumelden() {
        for zustand: KursZustand in [.frei, .voll, .vorbei, .abgesagt] {
            #expect(!KurseWochenInhalt.zeigtAbmeldenKnopf(fuer: zustand, abmeldefristVerstrichen: false))
        }
    }
}
