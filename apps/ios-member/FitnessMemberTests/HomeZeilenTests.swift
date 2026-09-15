import Foundation
import Testing
@testable import FitnessMember

struct HomeZeilenTests {
    /// `machineIds` bleibt standardmaessig im Gleichklang mit `machineCount`:
    /// die Karte zaehlt die verschiedenen `machineId` der Bloecke, die
    /// einzelne Einheit ihr `machineCount` -- fuer eine Karte aus einem
    /// einzigen Teil muessen beide Wege dieselbe Zahl liefern.
    private func einheit(
        id: String = "s1",
        startedAt: String = "2026-09-08T16:04:00Z",
        completedAt: String? = "2026-09-08T16:51:00Z",
        completedReason: String? = "manual",
        machineCount: Int = 3,
        setCount: Int = 8,
        machineIds: [String]? = nil
    ) -> SessionSummary {
        let geraete = machineIds ?? (0..<machineCount).map { "m\($0 + 1)" }
        return SessionSummary(
            id: id, startedAt: startedAt, completedAt: completedAt,
            completedReason: completedReason, machineCount: machineCount, setCount: setCount,
            blocks: geraete.map(block))
    }

    private func block(_ machineId: String) -> SessionSummary.Block {
        SessionSummary.Block(
            machineId: machineId, machineLabel: machineId, exerciseId: "e-\(machineId)",
            exerciseName: "Übung \(machineId)", sets: [])
    }

    /// Was heute noch laeuft, ist kein Verlauf -- die laufende Einheit
    /// steht im Training-Tab.
    @Test func dieLaufendeEinheitStehtNichtImVerlauf() {
        let zeilen = HomeZeilen.abgeschlossene([
            einheit(id: "laeuft", completedAt: nil, completedReason: nil),
            einheit(id: "fertig"),
        ])

        #expect(zeilen.map(\.id) == ["fertig"])
    }

    @Test func eineBeendeteEinheitZeigtIhreDauer() {
        #expect(HomeZeilen.dauerText(einheit()) == "47 min")
    }

    /// getSessions setzt das Ende einer vergessenen Einheit auf den
    /// letzten Satz -- die daraus gerechnete Dauer ist eine Untergrenze,
    /// keine Dauer. Das Artboard laesst sie deshalb weg.
    @Test func eineSelbsttaetigBeendeteEinheitZeigtKeineDauer() {
        #expect(HomeZeilen.dauerText(einheit(completedReason: "auto")) == nil)
    }

    @Test func tageHerZaehltKalendertage() {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let jetzt = Date(timeIntervalSince1970: 1_757_500_000)
        let vorbei = jetzt.addingTimeInterval(-3 * 24 * 60 * 60)

        let iso = ISO8601DateFormatter().string(from: vorbei)
        #expect(HomeZeilen.tageHer(iso, jetzt: jetzt, kalender: kalender) == 3)
    }

    @Test func ohneEinheitGibtEsKeineTageHer() {
        #expect(HomeZeilen.tageHer(nil, jetzt: Date(), kalender: .current) == nil)
    }

    @Test func derGrussNimmtDenErstenNamensteil() {
        #expect(HomeZeilen.vorname("Lena Wagner") == "Lena")
        #expect(HomeZeilen.vorname("Lena") == "Lena")
    }

    /// Ohne gesetzten Namen wird nichts erfunden -- weder Gruss noch
    /// Initialen. Aus einer Mailadresse abgeleitet saehe beides so lange
    /// richtig aus, bis es jemanden trifft.
    @Test func ohneNamenGibtEsWederGrussNochInitialen() {
        #expect(HomeZeilen.vorname(nil) == nil)
        #expect(HomeZeilen.vorname("   ") == nil)
        #expect(HomeZeilen.initialen(nil) == nil)
    }

    @Test func initialenNehmenHoechstensZweiTeile() {
        #expect(HomeZeilen.initialen("Lena Wagner") == "LW")
        #expect(HomeZeilen.initialen("Lena") == "L")
        #expect(HomeZeilen.initialen("Lena Marie Wagner") == "LM")
    }

    @Test func veraenderungZeigtVorzeichenUndPlusMinusNullBeiKeinerAenderung() {
        #expect(HomeZeilen.veraenderung(15) == "+15,0")
        #expect(HomeZeilen.veraenderung(-2.5) == "-2,5")
        #expect(HomeZeilen.veraenderung(0) == "±0")
    }

    @Test func tageHerLabelIstNurBeiGenauEinemTagEinzahl() {
        #expect(HomeZeilen.tageHerLabel(1) == "Tag her")
        #expect(HomeZeilen.tageHerLabel(0) == "Tage her")
        #expect(HomeZeilen.tageHerLabel(2) == "Tage her")
    }

    /// Baut die erwartete "18:04 – 18:51"-Angabe aus denselben
    /// Zeitpunkten, statt sie als Text vorherzusagen:
    /// Zahlformat.uhrzeit folgt TimeZone.current (richtig -- die Zeit
    /// gehoert dem Geraet, siehe Zahlformat-Kommentar), ein woertlich
    /// erwarteter String waere deshalb nur in der Zeitzone des
    /// Testrechners gruen (vgl. Kommentar in KurseWochenBerechnungTests).
    private func zeitraum(_ session: SessionSummary) -> String {
        let start = Zeitpunkt.parse(session.startedAt)!
        let ende = Zeitpunkt.parse(session.completedAt!)!
        return "\(Zahlformat.uhrzeit(start)) – \(Zahlformat.uhrzeit(ende))"
    }

    // MARK: - Die Ueberschrift eines Teils im Detail

    /// Eine Karte, die zwei Einheiten zeigt, oeffnet ein Detail mit zwei
    /// Teilen -- jeder Teil steht unter seiner eigenen Uhrzeit, sonst
    /// waere nicht zu sehen, wo der eine aufhoert und der naechste anfaengt.
    @Test func teilUeberschriftZeigtDenZeitraumDesTeils() {
        let session = einheit()
        #expect(HomeZeilen.teilUeberschrift(session) == zeitraum(session))
    }

    /// Ein erfundenes Ende waere schlimmer als ein offener Zeitraum -- wie
    /// in der kleinen Zeile bleibt die Ueberschrift beim Beginn.
    @Test func teilUeberschriftZeigtNurDenBeginnBeiEinemSelbsttaetigBeendetenTeil() {
        let auto = einheit(completedReason: "auto")
        #expect(HomeZeilen.teilUeberschrift(auto) == "ab \(uhrzeit(auto.startedAt))")
    }

    @Test func teilUeberschriftZeigtOhneEndeNurDenBeginn() {
        let offen = einheit(completedAt: nil, completedReason: nil)
        #expect(HomeZeilen.teilUeberschrift(offen) == "ab \(uhrzeit(offen.startedAt))")
    }

    // MARK: - Die getauschten Zeilen (Zeit/Saetze gross, Uhrzeit/Geraete klein)

    @Test func grosseZeileZeigtDauerUndSaetze() {
        #expect(HomeZeilen.grosseZeile(einheit()) == "47 min · 8 Sätze")
    }

    /// Die selbsttaetig beendete Einheit hat keine Dauer (dauerText liefert
    /// nil) -- die grosse Zeile faellt dann auf die Saetze zurueck, statt
    /// eine leere erste Angabe vor dem Trennpunkt zu zeigen.
    @Test func grosseZeileLaesstDieDauerOhneGueltigeWeg() {
        #expect(HomeZeilen.grosseZeile(einheit(completedReason: "auto")) == "8 Sätze")
    }

    @Test func grosseZeileUnterscheidetEinzahlUndMehrzahlBeiEinemSatz() {
        #expect(HomeZeilen.grosseZeile(einheit(setCount: 1)) == "47 min · 1 Satz")
    }

    @Test func kleineZeileZeigtZeitraumUndGeraete() {
        let session = einheit()
        #expect(HomeZeilen.kleineZeile(session) == "\(zeitraum(session)) · 3 Geräte")
    }

    /// Ein erfundenes Ende waere schlimmer als ein offener Zeitraum -- die
    /// kleine Zeile zeigt bei einer selbsttaetig beendeten Einheit nur den
    /// Beginn ("ab 08:32").
    @Test func kleineZeileZeigtNurDenBeginnBeiEinerSelbsttaetigBeendetenEinheit() {
        let auto = einheit(completedReason: "auto")
        let start = Zeitpunkt.parse(auto.startedAt)!
        #expect(HomeZeilen.kleineZeile(auto) == "ab \(Zahlformat.uhrzeit(start)) · 3 Geräte")
    }

    @Test func kleineZeileUnterscheidetEinzahlUndMehrzahlBeiEinemGeraet() {
        let session = einheit(machineCount: 1)
        #expect(HomeZeilen.kleineZeile(session) == "\(zeitraum(session)) · 1 Gerät")
    }

    // MARK: - Benachbarte Einheiten werden eine Karte

    /// Wie `HomeSerie.einheitenJeTag` buendelt: juengste Einheit zuerst.
    private func tagesliste(_ einheiten: SessionSummary...) -> [SessionSummary] {
        einheiten.sorted { $0.startedAt > $1.startedAt }
    }

    private func uhrzeit(_ iso: String) -> String {
        Zahlformat.uhrzeit(Zeitpunkt.parse(iso)!)
    }

    /// Wie `zeitraum(_:)`, aber aus zwei beliebigen Zeitpunkten -- die
    /// Spanne einer Karte reicht vom Beginn des ersten bis zum Ende des
    /// letzten Teils.
    private func spanne(_ vonIso: String, _ bisIso: String) -> String {
        "\(uhrzeit(vonIso)) – \(uhrzeit(bisIso))"
    }

    /// 34 Minuten Training, 14 Minuten Pause, 30 Minuten Training: eine
    /// Karte, und ihre grosse Zeile zeigt 64 Minuten -- nicht die 78
    /// Minuten der Spanne. Die Pause ist keine Trainingszeit.
    @Test func zweiEinheitenMitKurzerLueckeWerdenEineKarte() {
        let karten = HomeZeilen.trainingskarten(tagesliste(
            einheit(id: "a", startedAt: "2026-09-11T08:32:00Z", completedAt: "2026-09-11T09:06:00Z", setCount: 5),
            einheit(id: "b", startedAt: "2026-09-11T09:20:00Z", completedAt: "2026-09-11T09:50:00Z", setCount: 3)
        ))

        #expect(karten.map { $0.teile.map(\.id) } == [["a", "b"]])
        #expect(HomeZeilen.grosseZeile(karten[0]) == "64 min · 8 Sätze")
        #expect(HomeZeilen.kleineZeile(karten[0])
            == "\(spanne("2026-09-11T08:32:00Z", "2026-09-11T09:50:00Z")) · 3 Geräte")
    }

    /// Gerundet wird JE TEIL, dann summiert -- nicht andersherum: 34:30 und
    /// 30:30 sind 35 + 31 = 66 Minuten, summiert und dann gerundet waeren
    /// es 65. Der Weg ueber die Teile haelt eine Karte aus einem Teil mit
    /// `dauerText` im Gleichklang, und genau das pinnt dieser Test -- die
    /// Sekunden der beiden Teile trennen die zwei Rechenwege.
    @Test func dieKarteSummiertJeTeilGerundeteMinuten() {
        let karten = HomeZeilen.trainingskarten(tagesliste(
            einheit(id: "a", startedAt: "2026-09-11T08:32:00Z", completedAt: "2026-09-11T09:06:30Z", setCount: 5),
            einheit(id: "b", startedAt: "2026-09-11T09:20:00Z", completedAt: "2026-09-11T09:50:30Z", setCount: 3)
        ))

        #expect(karten.count == 1)
        #expect(HomeZeilen.grosseZeile(karten[0]) == "66 min · 8 Sätze")
    }

    @Test func zweiEinheitenMitLangerLueckeBleibenZweiKarten() {
        let karten = HomeZeilen.trainingskarten(tagesliste(
            einheit(id: "a", startedAt: "2026-09-11T08:32:00Z", completedAt: "2026-09-11T09:06:00Z"),
            einheit(id: "b", startedAt: "2026-09-11T10:14:00Z", completedAt: "2026-09-11T10:20:00Z")
        ))

        #expect(karten.map { $0.teile.map(\.id) } == [["b"], ["a"]])
    }

    /// Die Grenze gehoert nach oben: genau 60 Minuten Luecke trennt, 59
    /// fasst zusammen.
    @Test func genauSechzigMinutenLueckeTrennt() {
        func karten(naechsterBeginn: String) -> [[String]] {
            HomeZeilen.trainingskarten(tagesliste(
                einheit(id: "a", startedAt: "2026-09-11T08:32:00Z", completedAt: "2026-09-11T09:06:00Z"),
                einheit(id: "b", startedAt: naechsterBeginn, completedAt: "2026-09-11T10:30:00Z")
            )).map { $0.teile.map(\.id) }
        }

        #expect(karten(naechsterBeginn: "2026-09-11T10:06:00Z") == [["b"], ["a"]])
        #expect(karten(naechsterBeginn: "2026-09-11T10:05:00Z") == [["a", "b"]])
    }

    /// Der selbsttaetig beendete Teil bringt seine Saetze und sein Geraet
    /// mit, aber keine Dauer: sein Ende liegt beim letzten Satz (siehe
    /// dauerText).
    @Test func einAutoBeendeterTeilZaehltFuerSaetzeUndGeraeteAberNichtFuerDieDauer() {
        let karten = HomeZeilen.trainingskarten(tagesliste(
            einheit(
                id: "a", startedAt: "2026-09-11T08:32:00Z", completedAt: "2026-09-11T09:06:00Z",
                completedReason: "auto", setCount: 5, machineIds: ["m1"]),
            einheit(
                id: "b", startedAt: "2026-09-11T09:20:00Z", completedAt: "2026-09-11T09:50:00Z",
                setCount: 3, machineIds: ["m2"])
        ))

        #expect(karten.count == 1)
        #expect(HomeZeilen.grosseZeile(karten[0]) == "30 min · 8 Sätze")
        #expect(HomeZeilen.kleineZeile(karten[0])
            == "\(spanne("2026-09-11T08:32:00Z", "2026-09-11T09:50:00Z")) · 2 Geräte")
    }

    /// Traegt die Karte nur selbsttaetig beendete Teile, steht keine Dauer
    /// da -- eine erfundene waere schlimmer als gar keine.
    @Test func eineKarteAusNurAutoBeendetenTeilenZeigtKeineDauer() {
        let karten = HomeZeilen.trainingskarten(tagesliste(
            einheit(
                id: "a", startedAt: "2026-09-11T08:32:00Z", completedAt: "2026-09-11T09:06:00Z",
                completedReason: "auto", setCount: 5, machineIds: ["m1"]),
            einheit(
                id: "b", startedAt: "2026-09-11T09:20:00Z", completedAt: "2026-09-11T09:50:00Z",
                completedReason: "auto", setCount: 3, machineIds: ["m2"])
        ))

        #expect(karten.count == 1)
        #expect(HomeZeilen.grosseZeile(karten[0]) == "8 Sätze")
    }

    /// Endet der letzte Teil selbsttaetig, bleibt die Spanne offen: das
    /// Ende der Karte ist unbekannt, nicht der letzte Satz.
    @Test func endetDerLetzteTeilSelbsttaetigZeigtDieKarteNurIhrenBeginn() {
        let karten = HomeZeilen.trainingskarten(tagesliste(
            einheit(
                id: "a", startedAt: "2026-09-11T08:32:00Z", completedAt: "2026-09-11T09:06:00Z",
                machineIds: ["m1"]),
            einheit(
                id: "b", startedAt: "2026-09-11T09:20:00Z", completedAt: "2026-09-11T09:50:00Z",
                completedReason: "auto", machineIds: ["m2"])
        ))

        #expect(karten.count == 1)
        #expect(HomeZeilen.kleineZeile(karten[0]) == "ab \(uhrzeit("2026-09-11T08:32:00Z")) · 2 Geräte")
    }

    /// Wer nach der Pause an dasselbe Geraet zurueckkehrt, hat kein
    /// zweites benutzt -- die Summe der `machineCount` waere hier 3.
    @Test func dasselbeGeraetInZweiTeilenIstEinGeraet() {
        let karten = HomeZeilen.trainingskarten(tagesliste(
            einheit(
                id: "a", startedAt: "2026-09-11T08:32:00Z", completedAt: "2026-09-11T09:06:00Z",
                machineIds: ["m1", "m2"]),
            einheit(
                id: "b", startedAt: "2026-09-11T09:20:00Z", completedAt: "2026-09-11T09:50:00Z",
                machineIds: ["m2"])
        ))

        #expect(karten.count == 1)
        #expect(HomeZeilen.kleineZeile(karten[0])
            == "\(spanne("2026-09-11T08:32:00Z", "2026-09-11T09:50:00Z")) · 2 Geräte")
    }

    /// Ohne lesbares Ende gibt es keine Luecke, weder zur vorigen noch zur
    /// naechsten Einheit -- ohne diese Regel wuerden alle drei Einheiten
    /// hier zu einer Karte (je 10 Minuten Abstand).
    @Test func eineEinheitOhneLesbaresEndeStehtAllein() {
        let karten = HomeZeilen.trainingskarten(tagesliste(
            einheit(id: "a", startedAt: "2026-09-11T08:00:00Z", completedAt: "2026-09-11T08:30:00Z"),
            einheit(id: "b", startedAt: "2026-09-11T08:40:00Z", completedAt: "nicht lesbar"),
            einheit(id: "c", startedAt: "2026-09-11T08:50:00Z", completedAt: "2026-09-11T09:20:00Z")
        ))

        #expect(karten.map { $0.teile.map(\.id) } == [["c"], ["b"], ["a"]])
    }

    /// Eine Karte aus einem einzigen Teil darf nicht anders aussehen als
    /// die Einheit selbst -- sonst haette der Tages-Ausklapper zwei
    /// Darstellungen derselben Sache.
    @Test func eineKarteAusEinemTeilZeigtDieselbenZeilenWieDieEinheit() {
        for einzeln in [einheit(), einheit(completedReason: "auto"), einheit(machineCount: 1, setCount: 1)] {
            let karten = HomeZeilen.trainingskarten([einzeln])

            #expect(karten.count == 1)
            #expect(HomeZeilen.grosseZeile(karten[0]) == HomeZeilen.grosseZeile(einzeln))
            #expect(HomeZeilen.kleineZeile(karten[0]) == HomeZeilen.kleineZeile(einzeln))
        }
    }

    /// Die Karte traegt die Id ihres aeltesten Teils: die Route ins Detail
    /// bleibt `sessionDetail(id:)`, und das Detail sucht sich die uebrigen
    /// Teile selbst.
    @Test func dieKarteTraegtDieIdIhresAeltestenTeils() {
        let karten = HomeZeilen.trainingskarten(tagesliste(
            einheit(id: "a", startedAt: "2026-09-11T08:32:00Z", completedAt: "2026-09-11T09:06:00Z"),
            einheit(id: "b", startedAt: "2026-09-11T09:20:00Z", completedAt: "2026-09-11T09:50:00Z")
        ))

        #expect(karten.map(\.id) == ["a"])
    }

    /// Ein selbsttaetig beendeter Teil genuegt fuer die Marke: die Dauer
    /// der ganzen Karte ist dann eine Untergrenze.
    @Test func eineKarteMitEinemAutoBeendetenTeilIstAutoBeendet() {
        let karten = HomeZeilen.trainingskarten(tagesliste(
            einheit(id: "a", startedAt: "2026-09-11T08:32:00Z", completedAt: "2026-09-11T09:06:00Z"),
            einheit(
                id: "b", startedAt: "2026-09-11T09:20:00Z", completedAt: "2026-09-11T09:50:00Z",
                completedReason: "auto")
        ))

        #expect(karten.count == 1)
        #expect(karten[0].istAutoBeendet)
    }

    @Test func eineKarteOhneAutoBeendetenTeilIstNichtAutoBeendet() {
        let karten = HomeZeilen.trainingskarten(tagesliste(
            einheit(id: "a", startedAt: "2026-09-11T08:32:00Z", completedAt: "2026-09-11T09:06:00Z"),
            einheit(id: "b", startedAt: "2026-09-11T09:20:00Z", completedAt: "2026-09-11T09:50:00Z")
        ))

        #expect(karten.count == 1)
        #expect(!karten[0].istAutoBeendet)
    }

    /// Das Detail bekommt die Id eines beliebigen Teils und muss die ganze
    /// Karte finden -- auch die des zweiten Teils.
    @Test func karteFuerFindetDieKarteZuJedemTeil() {
        let einheiten = tagesliste(
            einheit(id: "a", startedAt: "2026-09-11T08:32:00Z", completedAt: "2026-09-11T09:06:00Z"),
            einheit(id: "b", startedAt: "2026-09-11T09:20:00Z", completedAt: "2026-09-11T09:50:00Z"),
            einheit(id: "c", startedAt: "2026-09-11T14:00:00Z", completedAt: "2026-09-11T14:30:00Z")
        )

        #expect(HomeZeilen.karte(fuer: "b", in: einheiten)?.teile.map(\.id) == ["a", "b"])
        #expect(HomeZeilen.karte(fuer: "c", in: einheiten)?.teile.map(\.id) == ["c"])
        #expect(HomeZeilen.karte(fuer: "unbekannt", in: einheiten) == nil)
    }
}
