import Foundation

/// Wo das Mitglied nach dem Tap landet.
enum GeraetEinstieg: Equatable {
    /// GeraetErkannt -- die Uebungsliste bleibt sichtbar.
    case erkannt
    /// Direkt auf den Geraete-Screen, ohne Zwischenschritt.
    case direktZumSatz
}

/// Die Tabelle aus designsystem.md SS8, als reine Funktionen.
///
/// Sie faellt bewusst aus dem Prefetch und nicht aus tagContext: M1-Spec
/// SS8.1 Schritt 3 verlangt, dass der Screen sofort rendert, bevor das Netz
/// antwortet.
enum GeraetEinstiegRechner {
    static func einstieg(visitCount: Int, genutzteUebungen: Int, uebungsanzahl: Int) -> GeraetEinstieg {
        // Ein Geraet mit genau einer Uebung bietet keine Wahl -- die
        // Uebungsliste waere ein Tipp ohne Entscheidung (Testnotiz 11.10., #4).
        if uebungsanzahl == 1 { return .direktZumSatz }
        // Zeile 4 der Tabelle verlangt genau eine genutzte Uebung. Jeder
        // andere Wert faellt zurueck auf die Liste: ein Screen mit Optionen
        // ist immer nutzbar, ein Sprung zum Satz ohne bekannte Uebung waere
        // ein Tap, der stumm ins Leere laeuft.
        return visitCount >= 2 && genutzteUebungen == 1 ? .direktZumSatz : .erkannt
    }

    /// Erstkontakt gilt je (Geraet, Uebung) -- der Dreischritt laeuft genau
    /// einmal je Paar (designsystem.md SS8).
    static func istErstkontakt(hatKalibrierung: Bool, hatLetztenSatz: Bool) -> Bool {
        !hatKalibrierung && !hatLetztenSatz
    }

    /// Ob der Drawer vor der Uebung mit der Einweisung beginnt (Testnotiz
    /// 11.10., #6) -- bekannt, bevor die Satzseite entsteht.
    /// `naechsterSetIndex` liest die lokale Einheit: ein Satz, den der
    /// Bootstrap noch nicht kennt, zaehlt.
    static func brauchtErstkontakt(station: String, exerciseId: String,
                                   in bootstrap: BootstrapResponse, naechsterSetIndex: Int) -> Bool {
        naechsterSetIndex == 1
            && istErstkontakt(
                hatKalibrierung: hatKalibrierung(station: station, exerciseId: exerciseId, in: bootstrap),
                hatLetztenSatz: hatLetztenSatz(station: station, exerciseId: exerciseId, in: bootstrap))
    }

    /// Die letzten Saetze einer Station als (Uebung, Zeitpunkt): am Geraet
    /// aus lastSets, am Typ aus lastTypeSets. Ein Schluessel, den der
    /// Prefetch nicht kennt, hat keine -- auch ein "geraet:" nie welche aus
    /// den Typsaetzen, sonst zaehlte der Satz am Typ doppelt.
    private static func letzteSaetze(station: String, in bootstrap: BootstrapResponse)
        -> [(exerciseId: String, performedAt: String)] {
        switch Station.art(schluessel: station) {
        case .geraet(let id)?:
            bootstrap.lastSets.filter { $0.machineId == id }
                .map { ($0.exerciseId, $0.performedAt) }
        case .typ(let id)?:
            bootstrap.lastTypeSets.filter { $0.equipmentModelId == id }
                .map { ($0.exerciseId, $0.performedAt) }
        case nil:
            []
        }
    }

    static func genutzteUebungen(station: String, in bootstrap: BootstrapResponse) -> Int {
        Set(letzteSaetze(station: station, in: bootstrap).map(\.exerciseId)).count
    }

    /// Die zuletzt genutzte Uebung an einer Station -- EIN Ort statt zweier
    /// Ableitungen in TrainingRootView (Review-Fund Schlusswelle), die beide
    /// nur funktionierten, weil der Server lastSets absteigend sortiert.
    /// `.max(by: performedAt)` liest das nicht voraus, sondern rechnet es
    /// selbst aus -- robust, falls die Server-Sortierung sich je aendert.
    static func letzteUebung(station: String, in bootstrap: BootstrapResponse) -> String? {
        letzteSaetze(station: station, in: bootstrap)
            .max { $0.performedAt < $1.performedAt }?.exerciseId
    }

    /// Kalibrierungen gibt es nur am Geraet; am Typ ist die Antwort immer nein.
    static func hatKalibrierung(station: String, exerciseId: String, in bootstrap: BootstrapResponse) -> Bool {
        guard case .geraet(let id)? = Station.art(schluessel: station) else { return false }
        return bootstrap.calibrations.contains { $0.machineId == id && $0.exerciseId == exerciseId }
    }

    static func hatLetztenSatz(station: String, exerciseId: String, in bootstrap: BootstrapResponse) -> Bool {
        letzteSaetze(station: station, in: bootstrap).contains { $0.exerciseId == exerciseId }
    }
}
