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
        #expect(tage.map(\.buchstabe) == ["M", "D", "M", "D", "F", "S", "S"])
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

    /// Die Tageszellen sind einzeln bedienbar und tragen ihr eigenes
    /// Label; dieser Satz haengt an der Flamme und beantwortet die Woche
    /// auf einmal, ohne dass VoiceOver sieben Elemente durchlaufen muss.
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

    /// Das Wochenziel ist eine zweite, unabhaengige Aussage neben der
    /// Serie (nicht-verhandelbare Regel 1) -- VoiceOver muss beide hoeren
    /// koennen, ohne dass eine die andere ersetzt.
    @Test func vorlesetextErwaehntDasZielWennEinsSteht() {
        let text = HomeSerie.vorlesetext(wochen: 6, tage: HomeSerie.tage(stand()), ziel: 3)

        #expect(
            text
                == "Serie: 6 Wochen. Diese Woche Montag und Dienstag trainiert. Ziel 3 Tage, 2 erreicht.")
    }

    @Test func vorlesetextOhneZielBleibtBeiZweiSaetzen() {
        let text = HomeSerie.vorlesetext(wochen: 6, tage: HomeSerie.tage(stand()))

        #expect(!text.contains("Ziel"))
    }

    // MARK: - Die Zielzeile

    @Test func zielzeileNenntStandUndZielInDerWoche() {
        #expect(HomeSerie.zielzeile(trainiert: 2, ziel: 3) == "2 von 3 Tagen diese Woche")
    }

    @Test func zielzeileMeldetDasZielAlsErreicht() {
        #expect(HomeSerie.zielzeile(trainiert: 3, ziel: 3) == "3 von 3 Tagen · Ziel erreicht")
    }

    /// Singular "Tag" bei einem Ziel von genau einem Tag.
    @Test func zielzeileHaeltDieEinzahlBeiEinemZieltag() {
        #expect(HomeSerie.zielzeile(trainiert: 0, ziel: 1) == "0 von 1 Tag diese Woche")
        #expect(HomeSerie.zielzeile(trainiert: 1, ziel: 1) == "1 von 1 Tag · Ziel erreicht")
    }

    /// Mehr als das Ziel ist erreicht, nicht falsch.
    @Test func zielzeileUeberDemZielBleibtErreicht() {
        #expect(HomeSerie.zielzeile(trainiert: 4, ziel: 3) == "4 von 3 Tagen · Ziel erreicht")
    }

    // MARK: - Der Zielkopf ueber dem Kalender

    /// "ZIEL 1 TAGE" soll gar nicht erst entstehen koennen -- der View
    /// setzt die Zeile nur noch in Grossbuchstaben.
    @Test func zielkopfHaeltDieEinzahlBeiEinemTag() {
        #expect(HomeSerie.zielkopf(ziel: 1) == "Ziel 1 Tag")
    }

    @Test func zielkopfSagtTageAbZwei() {
        #expect(HomeSerie.zielkopf(ziel: 3) == "Ziel 3 Tage")
    }

    // MARK: - Das Monatsgitter

    private func einheit(
        id: String = "s1",
        startedAt: String = "2026-09-08T16:04:00Z",
        completedAt: String? = "2026-09-08T16:51:00Z"
    ) -> SessionSummary {
        SessionSummary(
            id: id, startedAt: startedAt, completedAt: completedAt,
            completedReason: "manual", machineCount: 3, setCount: 8, blocks: [])
    }

    @Test func dasGitterFuelltVolleWochenVonMontagBisSonntag() {
        let tage = HomeSerie.monatstage(
            um: "2026-09-11", heute: "2026-09-11", trainingstage: [])

        // September 2026 beginnt an einem Dienstag: ein Tag Vorlauf,
        // 30 Tage, macht fuenf Zeilen.
        #expect(tage.count == 35)
        #expect(tage.first?.id == "2026-08-31")
        #expect(tage.last?.id == "2026-10-04")
        #expect(tage.map(\.buchstabe).prefix(7) == ["M", "D", "M", "D", "F", "S", "S"])
    }

    /// Die auffuellenden Tage stehen drin, statt zu fehlen: ein Gitter mit
    /// Loechern liesse die Spalten wandern, und dann stuende der 1. nicht
    /// mehr unter seinem Wochentag.
    @Test func nachbarmonateStehenDrinUndSindAlsSolcheMarkiert() {
        let tage = HomeSerie.monatstage(
            um: "2026-09-11", heute: "2026-09-11", trainingstage: [])

        #expect(tage.first?.ausserhalb == true)
        #expect(tage.last?.ausserhalb == true)
        #expect(tage.filter(\.ausserhalb).map(\.id) == [
            "2026-08-31", "2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04",
        ])
        #expect(tage.first(where: { $0.id == "2026-09-01" })?.ausserhalb == false)
    }

    /// Keine feste Sechszeiligkeit: der Monat wird nie umgeschaltet, und
    /// eine dauerhaft leere Zeile waere nur Nichts unter dem Gitter.
    @Test func dasGitterWaechstUndSchrumpftMitDemMonat() {
        // Maerz 2026 beginnt an einem Sonntag und hat 31 Tage -- sechs Zeilen.
        #expect(
            HomeSerie.monatstage(um: "2026-03-15", heute: "", trainingstage: []).count == 42)
        // Februar 2027 beginnt an einem Montag und hat 28 Tage -- vier
        // Zeilen, und kein einziger Fuelltag.
        let februar = HomeSerie.monatstage(um: "2027-02-15", heute: "", trainingstage: [])
        #expect(februar.count == 28)
        #expect(februar.allSatisfy { !$0.ausserhalb })
    }

    @Test func nurDieGenanntenTageTragenImGitterEineHantel() {
        let tage = HomeSerie.monatstage(
            um: "2026-09-11", heute: "2026-09-11",
            trainingstage: ["2026-09-07", "2026-09-09", "2026-10-02"])

        #expect(tage.filter(\.trainiert).map(\.id) == [
            "2026-09-07", "2026-09-09", "2026-10-02",
        ])
        #expect(tage.filter(\.istHeute).map(\.id) == ["2026-09-11"])
    }

    @Test func einUnlesbaresDatumErgibtKeinGitter() {
        #expect(HomeSerie.monatstage(um: "kaputt", heute: "", trainingstage: []).isEmpty)
    }

    // MARK: - Die Einheiten eines Tages

    /// Eine Einheit gehoert dem STUDIO, nicht dem Geraet: 22:30 UTC ist in
    /// Berlin schon der naechste Tag, und der Streifen muss sie dort
    /// zeigen, wo der Server sie zaehlt.
    @Test func einheitenFallenInDenOrtstagDesStudios() {
        let gebuendelt = HomeSerie.einheitenJeTag(
            [
                einheit(
                    id: "spaet", startedAt: "2026-09-08T22:30:00Z",
                    completedAt: "2026-09-08T23:10:00Z")
            ],
            zeitzone: "Europe/Berlin")

        #expect(gebuendelt.keys.sorted() == ["2026-09-09"])
    }

    @Test func dieselbeEinheitInUTCFaelltAufDenVortag() {
        let gebuendelt = HomeSerie.einheitenJeTag(
            [
                einheit(
                    id: "spaet", startedAt: "2026-09-08T22:30:00Z",
                    completedAt: "2026-09-08T23:10:00Z")
            ],
            zeitzone: "UTC")

        #expect(gebuendelt.keys.sorted() == ["2026-09-08"])
    }

    /// Was noch laeuft, ist kein Verlauf -- es hat kein Ende und darum
    /// auch keine Karte.
    @Test func dieLaufendeEinheitWirdNichtGebuendelt() {
        let gebuendelt = HomeSerie.einheitenJeTag(
            [einheit(id: "laeuft", completedAt: nil)], zeitzone: "Europe/Berlin")

        #expect(gebuendelt.isEmpty)
    }

    @Test func zweiEinheitenEinesTagesStehenMitDerJuengstenZuerst() {
        let gebuendelt = HomeSerie.einheitenJeTag(
            [
                einheit(
                    id: "frueh", startedAt: "2026-09-08T05:12:00Z",
                    completedAt: "2026-09-08T05:38:00Z"),
                einheit(id: "abends"),
            ],
            zeitzone: "Europe/Berlin")

        #expect(gebuendelt["2026-09-08"]?.map(\.id) == ["abends", "frueh"])
    }

    /// Der Server kennt die laufende Woche, die Liste den Rest -- beide
    /// zusammen, damit derselbe Tag in Woche und Monat nicht verschieden
    /// aussieht.
    @Test func trainingstageLegenBeideQuellenZusammen() {
        let menge = HomeSerie.trainingstage(
            stand: stand(trainedDays: ["2026-09-07", "2026-09-08"]),
            einheitenJeTag: ["2026-08-24": [einheit()]])

        #expect(menge == ["2026-09-07", "2026-09-08", "2026-08-24"])
    }

    /// Ein Tag, an dem gerade noch trainiert wird, steht in `trainedDays`,
    /// aber in keiner Buendelung -- seine Hantel darf trotzdem stehen.
    @Test func einLaufenderTagBehaeltSeineHantel() {
        let menge = HomeSerie.trainingstage(
            stand: stand(trainedDays: ["2026-09-09"]), einheitenJeTag: [:])
        let tage = HomeSerie.tage(stand(trainedDays: ["2026-09-09"]), trainingstage: menge)

        #expect(tage.filter(\.trainiert).map(\.id) == ["2026-09-09"])
    }

    // MARK: - Ueberschriften

    /// Mit Jahr: das Gitter kann ueber den Jahreswechsel reichen, und dann
    /// ist "Januar" allein zweideutig.
    @Test func derMonatstitelNenntDasJahr() {
        #expect(HomeSerie.monatstitel("2026-09-11") == "September 2026")
    }

    /// Ohne Jahr, wie Zahlformat.wochentagDatum: der gewaehlte Tag steht
    /// zwei Zentimeter darueber im Gitter.
    @Test func derTagestitelNenntWochentagUndDatum() {
        #expect(HomeSerie.tagestitel("2026-09-11") == "Freitag, 11. September")
    }

    @Test func unlesbareDatenErgebenKeineUeberschrift() {
        #expect(HomeSerie.monatstitel("kaputt").isEmpty)
        #expect(HomeSerie.tagestitel("kaputt").isEmpty)
    }

    // MARK: - Die Farbe der Flamme (Testnotiz 19. September, Eintrag 3)

    @Test func dieFlammeBrenntMitSerieUndEinerEinheitInDieserWoche() {
        #expect(HomeSerie.serieLaeuft(stand(weeks: 2, trainedDays: ["2026-09-08"])))
    }

    @Test func ohneSerieBrenntSieNie() {
        #expect(!HomeSerie.serieLaeuft(stand(weeks: 0, trainedDays: [])))
    }

    /// Der eigentliche Fund: die Serie steht bei zwei Wochen, weil der
    /// Server die noch leere laufende Woche nicht mitzaehlt -- die Zahl
    /// ist richtig. Gruen waere hier trotzdem falsch: bis Sonntag haengt
    /// die Serie an einer Einheit, und genau das soll die Farbe sagen.
    @Test func eineNochLeereWocheDecktDieFlammeAbOhneDieZahlAnzutasten() {
        let stehendeSerie = stand(weeks: 2, trainedDays: [])

        #expect(!HomeSerie.serieLaeuft(stehendeSerie))
        #expect(stehendeSerie.weeks == 2)
    }
}
