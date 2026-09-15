import Testing
@testable import FitnessMember

/// Wie das Rad seine Nachbarn zeigt, haengt davon ab, wie viele Zeilen es
/// zeigt: scrollTransition liefert die Phase auf [-1, 1] ueber den halben
/// Ausschnitt, nicht in Zeilen.
struct RastRadTests {

    @Test func fuenfZeilenZeigenZweiNachbarnJeRichtung() {
        // Wie bisher: der erste Nachbar liegt bei 0,5, der zweite am Rand.
        #expect(RastRad.nachbarstufe(phase: 0, sichtbareZeilen: 5) == .gewaehlt)
        #expect(RastRad.nachbarstufe(phase: 0.5, sichtbareZeilen: 5) == .nachbar)
        #expect(RastRad.nachbarstufe(phase: -0.5, sichtbareZeilen: 5) == .nachbar)
        #expect(RastRad.nachbarstufe(phase: 1, sichtbareZeilen: 5) == .fern)
    }

    @Test func dreiZeilenZeigenDenNachbarnAmRandAlsNachbarn() {
        // Bei drei Zeilen liegt der erste Nachbar schon am Rand (Phase 1).
        // Mit den festen Schwellen von frueher (0,25 / 0,75) waere er
        // "fern": 26 pt bei 15 % Deckkraft, also praktisch unsichtbar --
        // und das Rad zeigte keinen Nachbarn mehr (designsystem.md SS7).
        #expect(RastRad.nachbarstufe(phase: 0.2, sichtbareZeilen: 3) == .gewaehlt)
        #expect(RastRad.nachbarstufe(phase: 1, sichtbareZeilen: 3) == .nachbar)
        #expect(RastRad.nachbarstufe(phase: -1, sichtbareZeilen: 3) == .nachbar)
    }
}
