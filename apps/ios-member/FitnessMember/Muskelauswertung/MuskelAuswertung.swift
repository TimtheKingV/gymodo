import Foundation

/// Haeufigkeit und Fortschritt in einem Wert, damit die Views der
/// Muskelgruppen nur diese Struktur kennen.
struct MuskelAuswertung: Equatable {
    let haeufigkeit: Haeufigkeit
    let fortschritt: MuskelFortschritt
    /// Nur Hauptmuskeln koennen einen lastbasierten Fortschritt bekommen.
    /// Bei reinen Nebenmuskeln (z.B. Serratus) versprechen weitere Trainings
    /// deshalb keinen Fortschrittswert, obwohl die Haeufigkeit auswertbar ist.
    var hauptmuskeln: Set<String> = []

    func brauchtTrainings(muskel: String, wert: FortschrittsWert) -> Bool {
        wert == .keinWert && haeufigkeit.istAuswertbar && hauptmuskeln.contains(muskel)
            && !Ausgewogenheit.ohneKraftuebung.contains(muskel)
    }

    static func berechne(
        sessions: [SessionSummary],
        fortschritt: [ExerciseProgress],
        muskeln: [String: [GeraetMuskel]],
        jetzt: Date
    ) -> MuskelAuswertung {
        MuskelAuswertung(
            haeufigkeit: Haeufigkeit.berechne(sessions: sessions, muskeln: muskeln, jetzt: jetzt),
            fortschritt: MuskelFortschritt.berechne(fortschritt: fortschritt, muskeln: muskeln, jetzt: jetzt),
            hauptmuskeln: Set(muskeln.values.joined().filter { $0.role == .primary }.map(\.key)))
    }
}
