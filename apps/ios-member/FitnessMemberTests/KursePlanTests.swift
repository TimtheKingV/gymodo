import Foundation
import Testing
@testable import FitnessMember

/// Die Kurse aller Studios in einem Plan, mit Filter je Studio (Testnotiz
/// 11.10., #15).
struct KursePlanTests {
    private let studioA = KursTestdaten.woche(ownStatus: [nil, nil], praefix: "a", stunde: "18", frist: 2)
    private let studioB = KursTestdaten.woche(ownStatus: [nil, nil], praefix: "b", stunde: "07", frist: 24,
                                              zeitzone: "Europe/Vienna")

    @Test func zusammenfuehrenSortiertNachBeginnUndMerktDasStudio() throws {
        let plan = try #require(KursePlan.zusammenfuehren([("s1", studioA), ("s2", studioB)]))

        #expect(plan.sessions.map(\.sessionId) == ["b0", "a0", "b1", "a1"])
        #expect(plan.sessions.map(\.studioId) == ["s2", "s1", "s2", "s1"])
    }

    /// Frist und Zeitzone des Ergebnisses kommen vom ersten Studio -- das
    /// aktive steht vorn. Sie tragen nur Wochenstreifen und Ladefenster;
    /// je Termin gilt das eigene Studio (KurseStore.frist(fuer:)).
    @Test func fristUndZeitzoneDesPlansKommenVomErstenStudio() throws {
        let plan = try #require(KursePlan.zusammenfuehren([("s2", studioB), ("s1", studioA)]))

        #expect(plan.cancellationDeadlineHours == 24)
        #expect(plan.timezone == "Europe/Vienna")
    }

    @Test func ohneStudiosGibtEsKeinenPlan() {
        #expect(KursePlan.zusammenfuehren([]) == nil)
    }

    /// Das aktive Studio steht vorn, im Freien Training bleibt die Liste,
    /// wie sie ist -- Home und Kurse-Tab fragen damit dieselbe Menge an.
    @Test func dasAktiveStudioStehtVorn() {
        #expect(KurseStudios.reihenfolge(alle: ["s1", "s2", "s3"], aktiv: "s2") == ["s2", "s1", "s3"])
        #expect(KurseStudios.reihenfolge(alle: ["s1", "s2"], aktiv: nil) == ["s1", "s2"])
        #expect(KurseStudios.reihenfolge(alle: ["s1"], aktiv: "fremd") == ["s1"])
    }

    // MARK: - Filter

    @Test func ausgeblendeteStudiosFallenWeg() throws {
        let plan = try #require(KursePlan.zusammenfuehren([("s1", studioA), ("s2", studioB)]))

        #expect(KurseFilter.sichtbar(plan.sessions, ausgeblendet: ["s2"]).map(\.sessionId) == ["a0", "a1"])
        #expect(KurseFilter.sichtbar(plan.sessions, ausgeblendet: []).count == 4)
    }

    /// Ein Studio plus Freies Training ist ein Studio: dann keine Chips.
    @Test func dieAuswahlErscheintErstAbZweiStudios() {
        #expect(!KurseFilter.zeigtAuswahl(studios: 1))
        #expect(KurseFilter.zeigtAuswahl(studios: 2))
    }

    @Test func einTippSchaltetEinStudioAusUndWiederEin() {
        let alle = ["s1", "s2", "s3"]
        let aus = KurseFilter.umschalten("s2", ausgeblendet: [], alle: alle)
        #expect(aus == ["s2"])
        #expect(KurseFilter.umschalten("s2", ausgeblendet: aus, alle: alle).isEmpty)
    }

    /// Das letzte sichtbare Studio laesst sich nicht abwaehlen -- ein
    /// leerer Plan saehe aus wie "keine Kurse", nicht wie "alles
    /// ausgeblendet".
    @Test func dasLetzteSichtbareStudioBleibt() {
        let alle = ["s1", "s2"]
        #expect(KurseFilter.umschalten("s1", ausgeblendet: ["s2"], alle: alle) == ["s2"])
    }

    /// Ausgeblendete IDs eines Studios, das man verlassen hat, zaehlen
    /// nicht: sonst liesse sich das letzte echte Studio abwaehlen.
    @Test func ausgeblendeteFremdeStudiosZaehlenNicht() {
        #expect(KurseFilter.sichtbareStudios(alle: ["s1", "s2"], ausgeblendet: ["s9", "s2"]) == ["s1"])
    }
}
