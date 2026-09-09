import Foundation
import Testing
@testable import FitnessMember

/// `KurseHerkunft` -- die eine Ableitung, die alle drei Kurse-Screens
/// teilen: wie alt ist, was gerade auf dem Schirm steht, und sagt eine
/// Belegungszahl darin noch etwas aus.
struct KurseHerkunftTests {
    private let jetzt = Date(timeIntervalSince1970: 1_000_000)

    private func vorMinuten(_ minuten: Double) -> Date {
        jetzt.addingTimeInterval(-minuten * 60)
    }

    private func bilden(_ ladeZustand: KurseLadeZustand, wocheStand: Date?) -> KurseHerkunft {
        KurseHerkunft.bilden(ladeZustand: ladeZustand, wocheStand: wocheStand, jetzt: jetzt)
    }

    @Test func eingeradeGeholterPlanIstFrisch() {
        #expect(bilden(.geladen, wocheStand: vorMinuten(1)) == .frisch)
    }

    /// Die Grenze selbst zaehlt schon als veraltet -- derselbe Grenzfall
    /// wie beim Kursbeginn und bei der Abmeldefrist (`>=`).
    @Test func genauAufDerGrenzeGiltAlsVeraltet() {
        #expect(bilden(.geladen, wocheStand: vorMinuten(5)) == .veraltet)
        #expect(bilden(.geladen, wocheStand: vorMinuten(4.9)) == .frisch)
        #expect(bilden(.geladen, wocheStand: vorMinuten(120)) == .veraltet)
    }

    /// Der Weg aus der Durchsicht: Tab oeffnen, Telefon sperren, zwei
    /// Stunden spaeter zurueck. Ohne Ladeversuch bleibt der Zustand
    /// `.geladen`, der Plan steht unveraendert -- und genau deshalb muss
    /// die Alterung am Zeitpunkt haengen, nicht am Ladezustand.
    @Test func einAlterPlanOhneNeuenLadeversuchIstVeraltet() {
        let herkunft = bilden(.geladen, wocheStand: vorMinuten(120))

        #expect(herkunft == .veraltet)
        #expect(!herkunft.zeigtBelegung)
    }

    @Test func offlineUndServerfehlerBleibenUnterscheidbar() {
        #expect(bilden(.fehlgeschlagen(.offline), wocheStand: vorMinuten(1)) == .ohneEmpfang)
        #expect(bilden(.fehlgeschlagen(.server(message: "kaputt")), wocheStand: vorMinuten(1)) == .serverfehler)
        #expect(bilden(.fehlgeschlagen(.validation(message: "x")), wocheStand: nil) == .serverfehler)
    }

    /// Ein Fehlversuch schlaegt die Frische: der Plan mag eine Sekunde alt
    /// sein, der letzte Versuch ist trotzdem gescheitert, und das gehoert
    /// gesagt.
    @Test func einFehlversuchSchlaegtEinenFrischenStand() {
        #expect(bilden(.fehlgeschlagen(.offline), wocheStand: jetzt) == .ohneEmpfang)
    }

    /// Noch kein erfolgreicher Abruf: es gibt nichts zu datieren, und
    /// waehrend `.laedt` ist auch nichts fehlgeschlagen. Ohne diesen Zweig
    /// flackerte beim ersten Laden ein Hinweis auf, der fuer nichts gilt.
    @Test func ohneErfolgreichenAbrufUndOhneFehlerIstNichtsZuSagen() {
        #expect(bilden(.bereit, wocheStand: nil) == .frisch)
        #expect(bilden(.laedt, wocheStand: nil) == .frisch)
        #expect(bilden(.laedt, wocheStand: nil).satz(stand: nil) == nil)
    }

    /// Der Kern von Spec 5.2: nur eine frisch geholte Zahl ist eine Zahl.
    @Test func nurFrischeDatenZeigenEineBelegungszahl() {
        #expect(KurseHerkunft.frisch.zeigtBelegung)
        #expect(!KurseHerkunft.veraltet.zeigtBelegung)
        #expect(!KurseHerkunft.ohneEmpfang.zeigtBelegung)
        #expect(!KurseHerkunft.serverfehler.zeigtBelegung)
    }

    // MARK: - Die Saetze

    @Test func frischSagtNichts() {
        #expect(KurseHerkunft.frisch.satz(stand: vorMinuten(1)) == nil)
        #expect(KurseHerkunft.frisch.symbol == nil)
    }

    @Test func ohneEmpfangNenntDenEmpfangUndDenStand() {
        let satz = KurseHerkunft.ohneEmpfang.satz(stand: Date(timeIntervalSince1970: 0))

        #expect(satz?.hasPrefix("Ohne Empfang. Stand: ") == true)
        #expect(KurseHerkunft.ohneEmpfang.symbol == "wifi.slash")
    }

    /// Ein Serverfehler darf nie "kein Empfang" heissen -- das waere eine
    /// falsche Aussage ueber das Geraet und schickte das Mitglied WLAN
    /// suchen statt es erneut versuchen zu lassen.
    @Test func einServerfehlerBehauptetNichtsUeberDenEmpfang() {
        let satz = KurseHerkunft.serverfehler.satz(stand: Date(timeIntervalSince1970: 0))

        #expect(satz?.hasPrefix("Diese Angaben stammen vom letzten Abruf.") == true)
        #expect(satz?.contains("Empfang") == false)
        #expect(KurseHerkunft.serverfehler.symbol == "clock.arrow.circlepath")
    }

    @Test func veraltetKlingtWieDerServerfehlerUndNichtWieOffline() {
        let satz = KurseHerkunft.veraltet.satz(stand: Date(timeIntervalSince1970: 0))

        #expect(satz?.hasPrefix("Diese Angaben stammen vom letzten Abruf.") == true)
        #expect(satz?.contains("Empfang") == false)
    }

    /// Ohne bekannten Stand faellt die Datumsangabe weg -- ein erfundener
    /// Zeitpunkt waere schlimmer als keiner.
    @Test func ohneStandFaelltDieDatumsangabeWeg() {
        #expect(KurseHerkunft.ohneEmpfang.satz(stand: nil) == "Ohne Empfang.")
    }

    @Test func derZusatzHaengtHintenAn() {
        let satz = KurseHerkunft.veraltet.satz(
            stand: nil, zusatz: "Die freien Plätze lassen wir deshalb weg.")

        #expect(satz == "Diese Angaben stammen vom letzten Abruf. Die freien Plätze lassen wir deshalb weg.")
    }
}
