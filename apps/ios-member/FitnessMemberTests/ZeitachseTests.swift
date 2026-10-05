import Foundation
import Testing
@testable import FitnessMember

/// Die Zeitachse der beiden Verlaufsdiagramme (Gewicht, Uebung) --
/// Testnotiz 05.10., #3 und #6.
struct ZeitachseTests {
    private let tag: TimeInterval = 24 * 60 * 60
    private let start = ISO8601DateFormatter().date(from: "2026-09-17T12:00:00Z")!

    /// Der juengste Eintrag steht auf zwei Dritteln der Achse, nicht am
    /// rechten Rand: rechts bleibt Luft fuer das, was noch kommt.
    @Test func derLetztePunktStehtAufZweiDritteln() throws {
        let daten = [start, start.addingTimeInterval(9 * tag), start.addingTimeInterval(18 * tag)]
        let bereich = try #require(Zeitachse.bereich(daten))

        let anteil = daten[2].timeIntervalSince(bereich.lowerBound)
            / bereich.upperBound.timeIntervalSince(bereich.lowerBound)
        #expect(abs(anteil - 2.0 / 3.0) < 0.0001)
        #expect(bereich.lowerBound <= daten[0])
    }

    /// Ein einzelner Eintrag bekommt trotzdem eine Achse, und auch er
    /// steht auf zwei Dritteln.
    @Test func einEinzelnerPunktBekommtEineSpanne() throws {
        let bereich = try #require(Zeitachse.bereich([start]))

        #expect(bereich.lowerBound < start)
        #expect(bereich.upperBound > start)
        let anteil = start.timeIntervalSince(bereich.lowerBound)
            / bereich.upperBound.timeIntervalSince(bereich.lowerBound)
        #expect(abs(anteil - 2.0 / 3.0) < 0.0001)
    }

    /// Unsortiert hereingereicht zaehlt trotzdem der juengste Tag.
    @Test func dieReihenfolgeSpieltKeineRolle() throws {
        let spaet = start.addingTimeInterval(10 * tag)
        let a = try #require(Zeitachse.bereich([spaet, start]))
        let b = try #require(Zeitachse.bereich([start, spaet]))

        #expect(a == b)
    }

    @Test func ohnePunkteGibtEsKeinenBereich() {
        #expect(Zeitachse.bereich([]) == nil)
    }

    /// Zwei Punkte verbindet eine Gerade, ab drei schwingt die Linie.
    @Test func geschwungenErstAbDreiPunkten() {
        #expect(!Zeitachse.geschwungen(anzahl: 1))
        #expect(!Zeitachse.geschwungen(anzahl: 2))
        #expect(Zeitachse.geschwungen(anzahl: 3))
        #expect(Zeitachse.geschwungen(anzahl: 12))
    }
}
