import Foundation

/// Wo das Mitglied nach dem Tap landet.
enum GeraetEinstieg: Equatable {
    /// GeraetErkannt -- die Uebungsliste bleibt sichtbar.
    case erkannt
    /// Direkt auf den Geraete-Screen, ohne Zwischenschritt.
    case direktZumSatz
}

/// Die Stationen des Dreischritts (designsystem.md SS8). Welche davon ein
/// Geraet wirklich zeigt, entscheidet `GeraetEinstiegRechner.erstkontaktSchritte`.
enum ErstkontaktSchritt: Equatable {
    case einweisung
    case einstellung
    case ersteWerte
}

/// Die Tabelle aus designsystem.md SS8, als reine Funktionen.
///
/// Sie faellt bewusst aus dem Prefetch und nicht aus tagContext: M1-Spec
/// SS8.1 Schritt 3 verlangt, dass der Screen sofort rendert, bevor das Netz
/// antwortet.
enum GeraetEinstiegRechner {
    static func einstieg(visitCount: Int, genutzteUebungen: Int) -> GeraetEinstieg {
        // Zeile 4 der Tabelle verlangt genau eine genutzte Uebung. Jeder
        // andere Wert faellt zurueck auf die Liste: ein Screen mit Optionen
        // ist immer nutzbar, ein Sprung zum Satz ohne bekannte Uebung waere
        // ein Tap, der stumm ins Leere laeuft.
        visitCount >= 2 && genutzteUebungen == 1 ? .direktZumSatz : .erkannt
    }

    /// Erstkontakt gilt je (Geraet, Uebung) -- der Dreischritt laeuft genau
    /// einmal je Paar (designsystem.md SS8).
    static func istErstkontakt(hatKalibrierung: Bool, hatLetztenSatz: Bool) -> Bool {
        !hatKalibrierung && !hatLetztenSatz
    }

    /// Ein Modell ohne Einstellparameter ist im Trainerportal ein regulaerer
    /// Zustand ("das Mitglied hat nichts einzustellen"). Die Einstellung
    /// faellt dann aus dem Dreischritt: der Schritt haette nur den
    /// Trainer-Schalter und einen Knopf, der am Server mit 422 endet, weil
    /// pruefeEinstellwerte einen leeren Satz zu Recht abweist -- eine
    /// Kalibrierung ohne Werte ist keine. Das Mitglied kaeme nie zu
    /// Schritt 3.
    ///
    /// Eine Kalibrierungszeile entsteht so nicht; istErstkontakt wird
    /// stattdessen ueber den ersten gesicherten Satz falsch (hatLetztenSatz,
    /// bis zum naechsten Bootstrap der lokale Session-Index).
    static func erstkontaktSchritte(hatEinstellparameter: Bool) -> [ErstkontaktSchritt] {
        hatEinstellparameter
            ? [.einweisung, .einstellung, .ersteWerte]
            : [.einweisung, .ersteWerte]
    }

    static func genutzteUebungen(machineId: String, in bootstrap: BootstrapResponse) -> Int {
        Set(bootstrap.lastSets.filter { $0.machineId == machineId }.map(\.exerciseId)).count
    }

    /// Die zuletzt genutzte Uebung an einem Geraet -- EIN Ort statt zweier
    /// Ableitungen in TrainingRootView (Review-Fund Schlusswelle), die beide
    /// nur funktionierten, weil der Server lastSets absteigend sortiert.
    /// `.max(by: performedAt)` liest das nicht voraus, sondern rechnet es
    /// selbst aus -- robust, falls die Server-Sortierung sich je aendert.
    static func letzteUebung(machineId: String, in bootstrap: BootstrapResponse) -> String? {
        bootstrap.lastSets
            .filter { $0.machineId == machineId }
            .max { $0.performedAt < $1.performedAt }?.exerciseId
    }

    static func hatKalibrierung(machineId: String, exerciseId: String, in bootstrap: BootstrapResponse) -> Bool {
        bootstrap.calibrations.contains { $0.machineId == machineId && $0.exerciseId == exerciseId }
    }

    static func hatLetztenSatz(machineId: String, exerciseId: String, in bootstrap: BootstrapResponse) -> Bool {
        bootstrap.lastSets.contains { $0.machineId == machineId && $0.exerciseId == exerciseId }
    }
}
