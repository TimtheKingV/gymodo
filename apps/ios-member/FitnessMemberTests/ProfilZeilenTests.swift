import Foundation
import Testing
@testable import FitnessMember

/// Die reinen Ableitungen der Profil-Abschnitte "ÜBER DICH" und "ZIELE"
/// (Aufgabe 10) -- Zeilentexte, das "—" ohne Angabe und bei einem
/// unbekannten Server-Rohwert, und die Vorgaben der `ZielSheet`s.
struct ProfilZeilenTests {
    private func ziel(_ kind: String, _ wert: Double) -> Ziel {
        Ziel(id: "z", kind: kind, targetValue: wert, createdAt: "2026-08-01T00:00:00Z")
    }

    // MARK: - geschlechtText

    @Test func geschlechtTextZeigtDasDeutscheWort() {
        #expect(ProfilZeilen.geschlechtText("female") == "Weiblich")
    }

    @Test func geschlechtTextOhneAngabeIstEinGedankenstrich() {
        #expect(ProfilZeilen.geschlechtText(nil) == "—")
    }

    /// Ein neuerer Server kann einen Rohwert ergaenzen, den dieser Client
    /// nicht kennt -- "—", nie ein Absturz (Ruling).
    @Test func geschlechtTextBeiUnbekanntemRohwertIstEinGedankenstrich() {
        #expect(ProfilZeilen.geschlechtText("nonbinary") == "—")
    }

    // MARK: - altersspanneText

    @Test func altersspanneTextZeigtDieSpanne() {
        #expect(ProfilZeilen.altersspanneText("25_34") == "25–34")
    }

    @Test func altersspanneTextOhneAngabeIstEinGedankenstrich() {
        #expect(ProfilZeilen.altersspanneText(nil) == "—")
    }

    @Test func altersspanneTextBeiUnbekanntemRohwertIstEinGedankenstrich() {
        #expect(ProfilZeilen.altersspanneText("100_plus") == "—")
    }

    // MARK: - groesseText

    @Test func groesseTextTraegtDieEinheit() {
        #expect(ProfilZeilen.groesseText(168) == "168 cm")
    }

    @Test func groesseTextOhneAngabeIstEinGedankenstrich() {
        #expect(ProfilZeilen.groesseText(nil) == "—")
    }

    // MARK: - richtungText

    @Test func richtungTextZeigtDasDeutscheWort() {
        #expect(ProfilZeilen.richtungText("lose_weight") == "Abnehmen")
    }

    @Test func richtungTextOhneAngabeIstEinGedankenstrich() {
        #expect(ProfilZeilen.richtungText(nil) == "—")
    }

    @Test func richtungTextBeiUnbekanntemRohwertIstEinGedankenstrich() {
        #expect(ProfilZeilen.richtungText("get_shredded") == "—")
    }

    // MARK: - tageProWocheText

    @Test func tageProWocheTextZeigtNurDieZahl() {
        #expect(ProfilZeilen.tageProWocheText(ziel("weekly_days", 3)) == "3")
    }

    @Test func tageProWocheTextOhneZielIstEinGedankenstrich() {
        #expect(ProfilZeilen.tageProWocheText(nil) == "—")
    }

    // MARK: - zielgewichtText

    @Test func zielgewichtTextTraegtEineNachkommastelleUndDieEinheit() {
        #expect(ProfilZeilen.zielgewichtText(ziel("target_weight", 78)) == "78,0 kg")
    }

    @Test func zielgewichtTextOhneZielIstEinGedankenstrich() {
        #expect(ProfilZeilen.zielgewichtText(nil) == "—")
    }

    // MARK: - gewichtsverlaufDetailText

    private let zeitzone = TimeZone(identifier: "UTC")!
    /// Mittwoch, 9. September 2026, 12:00 UTC -- derselbe Zeitpunkt wie in
    /// HomeZieleTests.
    private let jetzt = Date(timeIntervalSince1970: 1_788_955_200)

    @Test func gewichtsverlaufDetailTextKombiniertGewichtUndOrtstag() {
        let text = ProfilZeilen.gewichtsverlaufDetailText(
            Messwert(measuredOn: "2026-09-08", weightKg: 82.5), jetzt: jetzt, zeitzone: zeitzone)

        #expect(text == "82,5 kg · gestern")
    }

    @Test func gewichtsverlaufDetailTextOhneMesswertIstNil() {
        #expect(ProfilZeilen.gewichtsverlaufDetailText(nil, jetzt: jetzt, zeitzone: zeitzone) == nil)
    }

    // MARK: - tageProWocheVorgabe

    @Test func tageProWocheVorgabeUebernimmtDasAktiveZiel() {
        #expect(ProfilZeilen.tageProWocheVorgabe(aktiv: ziel("weekly_days", 5)) == 5)
    }

    @Test func tageProWocheVorgabeOhneAktivesZielIstDrei() {
        #expect(ProfilZeilen.tageProWocheVorgabe(aktiv: nil) == 3)
    }

    // MARK: - zielgewichtVorgabe

    @Test func zielgewichtVorgabeUebernimmtDasAktiveZielVorAllemAnderen() {
        let vorgabe = ProfilZeilen.zielgewichtVorgabe(
            aktiv: ziel("target_weight", 78), letzterMesswert: Messwert(measuredOn: "2026-09-08", weightKg: 82.5))

        #expect(vorgabe == 78)
    }

    @Test func zielgewichtVorgabeFaelltAufDenLetztenMesswert() {
        let vorgabe = ProfilZeilen.zielgewichtVorgabe(
            aktiv: nil, letzterMesswert: Messwert(measuredOn: "2026-09-08", weightKg: 82.5))

        #expect(vorgabe == 82.5)
    }

    @Test func zielgewichtVorgabeFaelltOhneAllesAufFuenfundsiebzig() {
        #expect(ProfilZeilen.zielgewichtVorgabe(aktiv: nil, letzterMesswert: nil) == 75.0)
    }
}
