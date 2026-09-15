import Foundation
import Testing
@testable import FitnessMember

/// Der Block "Deine Ziele" auf Home -- eine reine Ableitung aus
/// Bootstrap-Zielen, Messwerten und dem "Ziel erreicht"-Speicher
/// (`VerlaufStore.erreichtesZielgewicht`).
struct HomeZieleTests {
    private func ziel(_ kind: String, _ wert: Double) -> Ziel {
        Ziel(id: "z", kind: kind, targetValue: wert, createdAt: "2026-08-01T00:00:00Z")
    }

    private func member(
        trainingGoal: String? = "lose_weight",
        weeklyDays: Ziel? = nil,
        targetWeight: Ziel? = nil
    ) -> BootstrapResponse.Member {
        BootstrapResponse.Member(
            displayName: nil, trainingGoal: trainingGoal,
            goals: Ziele(weeklyDays: weeklyDays, targetWeight: targetWeight))
    }

    private func messwert(_ tag: String, _ kg: Double) -> Messwert {
        Messwert(measuredOn: tag, weightKg: kg)
    }

    /// Fest auf UTC, wie in HomeSerieTests: sonst haengt "gestern" an der
    /// Zeitzone der Maschine, auf der der Test laeuft.
    private let kalender: Calendar = {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: "UTC")!
        return kalender
    }()
    /// Mittwoch, 9. September 2026, 12:00 UTC -- derselbe Zeitpunkt wie in
    /// HomeSerieTests.
    private let jetzt = Date(timeIntervalSince1970: 1_788_955_200)

    // MARK: - Entscheidung 1: die drei Kartenzustaende

    @Test func ohneZieleUndOhneGewichtIstNachholen() {
        let zustand = HomeZiele.zustand(
            member: member(weeklyDays: nil, targetWeight: nil), messwerte: [],
            erreichtesZielgewicht: nil, jetzt: jetzt, kalender: kalender)

        #expect(zustand == .nachholen)
    }

    @Test func mitWochenzielAberOhneGewichtIstNurEintragen() {
        let zustand = HomeZiele.zustand(
            member: member(weeklyDays: ziel("weekly_days", 3), targetWeight: nil), messwerte: [],
            erreichtesZielgewicht: nil, jetzt: jetzt, kalender: kalender)

        #expect(zustand == .nurEintragen)
    }

    @Test func mitZielgewichtAberOhneGewichtIstEbenfallsNurEintragen() {
        let zustand = HomeZiele.zustand(
            member: member(targetWeight: ziel("target_weight", 78)), messwerte: [],
            erreichtesZielgewicht: nil, jetzt: jetzt, kalender: kalender)

        #expect(zustand == .nurEintragen)
    }

    @Test func mitMesswertIstKarteAuchOhneZielgewicht() {
        let zustand = HomeZiele.zustand(
            member: member(targetWeight: nil), messwerte: [messwert("2026-09-08", 82.5)],
            erreichtesZielgewicht: nil, jetzt: jetzt, kalender: kalender)

        guard case .karte(let karte) = zustand else {
            Issue.record("Erwartet .karte, war \(zustand)")
            return
        }
        #expect(karte.wert == 82.5)
        #expect(karte.datumText == "gestern")
        #expect(karte.abstandText == nil)
        #expect(karte.zielText == nil)
        #expect(karte.zielwert == nil)
    }

    @Test func mitMesswertUndZielgewichtIstKarteMitAbstand() {
        let zustand = HomeZiele.zustand(
            member: member(targetWeight: ziel("target_weight", 78)),
            messwerte: [messwert("2026-09-01", 84.5), messwert("2026-09-08", 82.5)],
            erreichtesZielgewicht: nil, jetzt: jetzt, kalender: kalender)

        guard case .karte(let karte) = zustand else {
            Issue.record("Erwartet .karte, war \(zustand)")
            return
        }
        #expect(karte.abstandText == "noch 4,5 kg")
        #expect(karte.zielText == "bis 78,0")
        #expect(karte.zielwert == 78)
        #expect(karte.differenzText == "\u{2212}2,0 kg")
        #expect(karte.seitText == "seit 1. Sept.")
        #expect(karte.kurve == [84.5, 82.5])
    }

    // MARK: - abstandText

    @Test func abstandTextNenntDenRestwegZumZiel() {
        #expect(HomeZiele.abstandText(aktuell: 82.5, ziel: 78) == "noch 4,5 kg")
    }

    @Test func abstandTextOhneZielgewichtIstNil() {
        #expect(HomeZiele.abstandText(aktuell: 82.5, ziel: nil) == nil)
    }

    /// Kein Vorzeichen, keine Richtung -- ob ab- oder zugenommen werden
    /// soll, sagt das Trainingsziel, nicht diese Zahl.
    @Test func abstandTextIstUnabhaengigVonDerRichtung() {
        #expect(HomeZiele.abstandText(aktuell: 70, ziel: 75) == "noch 5,0 kg")
    }

    // MARK: - differenzText

    @Test func differenzTextMitMinuszeichenU2212() {
        #expect(HomeZiele.differenzText(-2.0) == "\u{2212}2,0 kg")
    }

    @Test func differenzTextMitPlus() {
        #expect(HomeZiele.differenzText(1.5) == "+1,5 kg")
    }

    /// "±0" allein (ohne Nachkommastelle) wuerde neben "82,5 kg" wie ein
    /// Formatfehler wirken -- Gewichte tragen immer eine Nachkommastelle.
    @Test func differenzTextBeiNullMitPlusminusUndNachkommastelle() {
        #expect(HomeZiele.differenzText(0) == "±0,0 kg")
    }

    // MARK: - kurve

    @Test func kurveNimmtHoechstensZwoelfPunkte() {
        let messwerte = (1...15).map { messwert(String(format: "2026-01-%02d", $0), Double($0)) }

        #expect(HomeZiele.kurve(messwerte) == (4...15).map(Double.init))
    }

    @Test func kurveNimmtAlleWennWenigerAlsZwoelfDaSind() {
        let messwerte = [messwert("2026-09-01", 84), messwert("2026-09-08", 82.5)]

        #expect(HomeZiele.kurve(messwerte) == [84, 82.5])
    }

    // MARK: - datumText

    @Test func datumTextSagtHeute() {
        #expect(HomeZiele.datumText("2026-09-09", jetzt: jetzt, kalender: kalender) == "heute")
    }

    @Test func datumTextSagtGestern() {
        #expect(HomeZiele.datumText("2026-09-08", jetzt: jetzt, kalender: kalender) == "gestern")
    }

    @Test func datumTextZaehltTage() {
        #expect(HomeZiele.datumText("2026-09-06", jetzt: jetzt, kalender: kalender) == "vor 3 Tagen")
    }

    // MARK: - Entscheidung 2: "Ziel erreicht" lebt im Speicher

    @Test func erreichtTextNenntGewichtUndDatum() {
        let erreicht = VerlaufStore.ErreichtesZielgewicht(weightKg: 78, measuredOn: "2026-11-03")

        #expect(HomeZiele.erreichtText(erreicht) == "Zielgewicht erreicht · 78,0 kg am 3. November")
    }

    @Test func erreichtTextOhneGespeichertenStandIstNil() {
        #expect(HomeZiele.erreichtText(nil) == nil)
    }

    /// Der Client kennt aus dem Bootstrap nur aktive Ziele -- ein
    /// erreichtes Zielgewicht kommt deshalb ausschliesslich aus dem
    /// gemerkten Stand, nie aus `member.goals`.
    @Test func zustandTraegtDenErreichtTextInDieKarte() {
        let erreicht = VerlaufStore.ErreichtesZielgewicht(weightKg: 78, measuredOn: "2026-11-03")
        let zustand = HomeZiele.zustand(
            member: member(targetWeight: nil), messwerte: [messwert("2026-11-03", 78)],
            erreichtesZielgewicht: erreicht, jetzt: jetzt, kalender: kalender)

        guard case .karte(let karte) = zustand else {
            Issue.record("Erwartet .karte, war \(zustand)")
            return
        }
        #expect(karte.erreichtText == "Zielgewicht erreicht · 78,0 kg am 3. November")
    }
}
