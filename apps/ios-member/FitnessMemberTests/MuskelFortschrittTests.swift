import Foundation
import Testing
@testable import FitnessMember

struct MuskelFortschrittTests {
    private let jetzt = Date(timeIntervalSince1970: 1_792_000_000)

    private func tag(_ zurueck: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: jetzt.addingTimeInterval(-Double(zurueck) * 86_400))
    }

    private func uebung(_ id: String, _ punkte: [(Int, Double)]) -> ExerciseProgress {
        ExerciseProgress(
            id: id, exerciseName: id, machineLabel: "M", loadUnit: .kg, volumeKind: .reps,
            firstLoad: 0, currentLoad: 0, changeLoad: 0,
            points: punkte.map { .init(performedOn: tag($0.0), topLoad: $0.1, volume: 10) })
    }

    private func haupt(_ key: String) -> [GeraetMuskel] { [GeraetMuskel(key: key, name: key, role: .primary)] }

    private let standard: [(Int, Double)] = [(90, 40), (80, 50), (20, 55), (2, 60)]

    @Test func uebungMitZweiMesspunktenImAbstand() {
        let r = MuskelFortschritt.berechne(
            fortschritt: [uebung("a", standard)], muskeln: ["a": haupt("lats")], jetzt: jetzt)
        #expect(abs((r.jeMuskel["lats"] ?? 0) - 20) < 0.0001)
    }

    @Test func unterstuetzenderMuskelZaehltNicht() {
        let m = [GeraetMuskel(key: "lats", name: "l", role: .primary),
                 GeraetMuskel(key: "triceps", name: "t", role: .secondary)]
        let r = MuskelFortschritt.berechne(fortschritt: [uebung("a", standard)], muskeln: ["a": m], jetzt: jetzt)
        #expect(r.jeMuskel["triceps"] == nil)
        #expect(r.jeMuskel["lats"] != nil)
    }

    @Test func mittelUeberMehrereUebungen() {
        let zehn: [(Int, Double)] = [(90, 100), (2, 110)]
        let r = MuskelFortschritt.berechne(
            fortschritt: [uebung("a", standard), uebung("b", zehn)],
            muskeln: ["a": haupt("lats"), "b": haupt("lats")], jetzt: jetzt)
        #expect(abs((r.jeMuskel["lats"] ?? 0) - 15) < 0.0001)
    }

    @Test func gruppeIstDasMittelIhrerMuskelMitWert() {
        let zehn: [(Int, Double)] = [(90, 100), (2, 110)]
        let r = MuskelFortschritt.berechne(
            fortschritt: [uebung("a", standard), uebung("b", zehn)],
            muskeln: ["a": haupt("lats"), "b": haupt("upper_back")], jetzt: jetzt)
        #expect(r.jeMuskel["erectors"] == nil)
        #expect(abs((r.jeGruppe[.ruecken] ?? 0) - 15) < 0.0001)
    }

    @Test func zuKurzerAbstandOderEinPunktGibtKeinenWert() {
        let kurz = MuskelFortschritt.berechne(
            fortschritt: [uebung("a", [(20, 40), (10, 60)])], muskeln: ["a": haupt("lats")], jetzt: jetzt)
        #expect(kurz.jeMuskel["lats"] == nil)
        let einer = MuskelFortschritt.berechne(
            fortschritt: [uebung("a", [(20, 40)])], muskeln: ["a": haupt("lats")], jetzt: jetzt)
        #expect(einer.jeMuskel["lats"] == nil)
        #expect(einer.jeGruppe[.ruecken] == nil)
    }

    @Test func startlastNullGibtKeinenWert() {
        let r = MuskelFortschritt.berechne(
            fortschritt: [uebung("a", [(90, 0), (2, 60)])], muskeln: ["a": haupt("lats")], jetzt: jetzt)
        #expect(r.jeMuskel["lats"] == nil)
    }

    @Test func punkteAusserhalbDesFenstersZaehlenNicht() {
        // Ohne den Punkt vor 100 Tagen: 50 -> 60 = +20 %. Mit ihm waere der Start 10.
        let r = MuskelFortschritt.berechne(
            fortschritt: [uebung("a", [(100, 10), (80, 50), (2, 60)])],
            muskeln: ["a": haupt("lats")], jetzt: jetzt)
        #expect(abs((r.jeMuskel["lats"] ?? 0) - 20) < 0.0001)
    }

    @Test func anzeige() {
        #expect(MuskelFortschritt.anzeige(nil) == .keinWert)
        #expect(MuskelFortschritt.anzeige(2.9) == .stabil)
        #expect(MuskelFortschritt.anzeige(-2.9) == .stabil)
        #expect(MuskelFortschritt.anzeige(-3.0) == .wert(-3))
        #expect(MuskelFortschritt.anzeige(14.4) == .wert(14))
        #expect(MuskelFortschritt.anzeige(3.0) == .wert(3))
        #expect(MuskelFortschritt.anzeige(.nan) == .keinWert)
        #expect(MuskelFortschritt.anzeige(.infinity) == .keinWert)
    }
}
