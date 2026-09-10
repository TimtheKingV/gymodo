import Foundation
import Testing
@testable import FitnessMember

/// Der Wochenstreifen am Kopf des Home-Tabs.
///
/// Die Tage kommen als ORTSDATEN vom Server ("yyyy-MM-dd", Zeitzone des
/// Studios) -- deshalb pruefen diese Tests bewusst mit Kalendern in
/// verschiedenen Systemzeitzonen, dass der Streifen keinen zweiten,
/// eigenen Zeitzonen-Abgleich einfuehrt.
struct HomeSerieTests {
    private func stand(
        weeks: Int = 6,
        weekStart: String = "2026-09-07",
        today: String = "2026-09-09",
        trainedDays: [String] = ["2026-09-07", "2026-09-08"]
    ) -> Serienstand {
        Serienstand(weeks: weeks, weekStart: weekStart, today: today, trainedDays: trainedDays)
    }

    // MARK: - Die sieben Tagesboxen

    @Test func siebenTageVonMontagBisSonntag() {
        let tage = HomeSerie.tage(stand())

        #expect(tage.count == 7)
        #expect(tage.map(\.kuerzel) == ["MO", "DI", "MI", "DO", "FR", "SA", "SO"])
        #expect(tage.map(\.tagesnummer) == [7, 8, 9, 10, 11, 12, 13])
    }

    @Test func tagesnummernLaufenUeberDenMonatswechsel() {
        let tage = HomeSerie.tage(
            stand(weekStart: "2026-08-31", today: "2026-09-02", trainedDays: []))

        #expect(tage.map(\.tagesnummer) == [31, 1, 2, 3, 4, 5, 6])
    }

    @Test func nurDieGenanntenTageTragenEineHantel() {
        let tage = HomeSerie.tage(stand())

        #expect(tage.map(\.trainiert) == [true, true, false, false, false, false, false])
    }

    /// Ein Tag ausserhalb der Woche darf nichts faerben -- der Server
    /// liefert das nicht, aber ein alter Cache koennte es.
    @Test func einTagAusserhalbDerWocheFaerbtNichts() {
        let tage = HomeSerie.tage(stand(trainedDays: ["2026-09-01", "2026-09-08"]))

        #expect(tage.map(\.trainiert) == [false, true, false, false, false, false, false])
    }

    @Test func genauEinTagIstHeute() {
        let tage = HomeSerie.tage(stand())

        #expect(tage.filter(\.istHeute).map(\.id) == ["2026-09-09"])
    }

    /// Faellt "heute" nicht in die gelieferte Woche, traegt kein Tag die
    /// Kontur. Das ist der Zustand zwischen Mitternacht und dem naechsten
    /// Laden, und eine geratene Kontur waere schlimmer als keine.
    @Test func eineWocheOhneHeuteTraegtKeineKontur() {
        let tage = HomeSerie.tage(stand(today: "2026-09-20"))

        #expect(tage.allSatisfy { !$0.istHeute })
    }

    /// Ein unlesbares Datum kommt aus gemerktem Zustand und koennte einen
    /// aelteren Stand tragen. Dann lieber kein Streifen als ein geratener.
    @Test func einUnlesbaresDatumErgibtKeinenStreifen() {
        #expect(HomeSerie.tage(stand(weekStart: "kaputt")).isEmpty)
    }

    // MARK: - Die Flamme

    @Test func eineWocheStehtInDerEinzahl() {
        #expect(HomeSerie.wochenLabel(1) == "Woche")
        #expect(HomeSerie.wochenLabel(0) == "Wochen")
        #expect(HomeSerie.wochenLabel(6) == "Wochen")
    }

    // MARK: - Die Fussnote

    /// Fest auf UTC, nicht `.current`: sonst haengt "gestern" an der
    /// Zeitzone der Maschine, auf der der Test laeuft.
    private let kalender: Calendar = {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: "UTC")!
        return kalender
    }()
    /// Mittwoch, 9. September 2026, 12:00 UTC.
    private let jetzt = Date(timeIntervalSince1970: 1_788_955_200)

    @Test func fussnoteNenntGesamtzahlUndLetztenTag() {
        let text = HomeSerie.fussnote(
            gesamt: 34, lastSessionAt: "2026-09-08T08:00:00.000Z",
            jetzt: jetzt, kalender: kalender)

        #expect(text == "34 Einheiten gesamt · zuletzt gestern")
    }

    @Test func fussnoteSagtHeuteStattVorNullTagen() {
        let text = HomeSerie.fussnote(
            gesamt: 34, lastSessionAt: "2026-09-09T08:00:00.000Z",
            jetzt: jetzt, kalender: kalender)

        #expect(text == "34 Einheiten gesamt · zuletzt heute")
    }

    @Test func fussnoteZaehltTageAbZwei() {
        let text = HomeSerie.fussnote(
            gesamt: 34, lastSessionAt: "2026-09-04T08:00:00.000Z",
            jetzt: jetzt, kalender: kalender)

        #expect(text == "34 Einheiten gesamt · zuletzt vor 5 Tagen")
    }

    @Test func fussnoteHaeltDieEinzahl() {
        let text = HomeSerie.fussnote(
            gesamt: 1, lastSessionAt: "2026-09-09T08:00:00.000Z",
            jetzt: jetzt, kalender: kalender)

        #expect(text == "1 Einheit gesamt · zuletzt heute")
    }

    /// Ohne Verlauf steht keine Null da (designsystem.md SS5), sondern der
    /// Satz, der erklaert, was fehlt.
    @Test func fussnoteOhneVerlaufNenntKeineNull() {
        let text = HomeSerie.fussnote(
            gesamt: 0, lastSessionAt: nil, jetzt: jetzt, kalender: kalender)

        #expect(text == "Noch keine Einheit erfasst")
    }

    @Test func fussnoteLaesstDenLetztenTagWegWennErFehlt() {
        let text = HomeSerie.fussnote(
            gesamt: 34, lastSessionAt: nil, jetzt: jetzt, kalender: kalender)

        #expect(text == "34 Einheiten gesamt")
    }

    // MARK: - VoiceOver

    /// Der Streifen ist EIN Element, nicht sieben: er ist nicht bedienbar,
    /// und sieben einzeln vorgelesene Tagesboxen waeren nur Weg.
    @Test func vorlesetextNenntSerieUndTrainingstage() {
        let text = HomeSerie.vorlesetext(wochen: 6, tage: HomeSerie.tage(stand()))

        #expect(text == "Serie: 6 Wochen. Diese Woche Montag und Dienstag trainiert.")
    }

    @Test func vorlesetextZaehltDreiTageMitKommaUndUnd() {
        let tage = HomeSerie.tage(
            stand(trainedDays: ["2026-09-07", "2026-09-08", "2026-09-11"]))

        #expect(
            HomeSerie.vorlesetext(wochen: 6, tage: tage)
                == "Serie: 6 Wochen. Diese Woche Montag, Dienstag und Freitag trainiert.")
    }

    @Test func vorlesetextSagtWennDieWocheNochLeerIst() {
        let text = HomeSerie.vorlesetext(wochen: 6, tage: HomeSerie.tage(stand(trainedDays: [])))

        #expect(text == "Serie: 6 Wochen. Diese Woche noch nicht trainiert.")
    }

    @Test func vorlesetextOhneSerieNenntKeineNull() {
        let text = HomeSerie.vorlesetext(
            wochen: 0, tage: HomeSerie.tage(stand(weeks: 0, trainedDays: [])))

        #expect(text == "Keine laufende Serie. Diese Woche noch nicht trainiert.")
    }
}
