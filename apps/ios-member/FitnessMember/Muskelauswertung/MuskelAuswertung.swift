import Foundation

/// Haeufigkeit und Fortschritt in einem Wert, damit die Views der
/// Muskelgruppen nur diese Struktur kennen.
struct MuskelAuswertung: Equatable {
    let haeufigkeit: Haeufigkeit
    let fortschritt: MuskelFortschritt

    static func berechne(
        sessions: [SessionSummary],
        fortschritt: [ExerciseProgress],
        muskeln: [String: [GeraetMuskel]],
        jetzt: Date
    ) -> MuskelAuswertung {
        MuskelAuswertung(
            haeufigkeit: Haeufigkeit.berechne(sessions: sessions, muskeln: muskeln, jetzt: jetzt),
            fortschritt: MuskelFortschritt.berechne(fortschritt: fortschritt, muskeln: muskeln, jetzt: jetzt))
    }
}
