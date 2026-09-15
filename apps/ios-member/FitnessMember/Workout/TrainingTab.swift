import Foundation

/// Was der Training-Tab in seiner Mitte zeigt -- Titel und Kopf schliessen
/// sich gegenseitig aus (TrainingRootView), Startwege stehen im Fuss darunter.
///
/// Ein reines enum wie GeraeteAuswahl: Die Wurzel hat genug Lebenszyklus
/// (Umschalttick, Scan, NFC), die Regel "ohne Training keine Null" soll
/// ohne ihn pruefbar sein.
enum TrainingTab {

    struct Zahlen: Equatable {
        let geraete: Int
        let saetze: Int
    }

    struct Mitte: Equatable {
        /// Die Uhr rechnet gegen diesen Zeitpunkt, nicht gegen einen
        /// mitgezaehlten Wert: ein gespeicherter Zeitpunkt ueberlebt
        /// Hintergrund und Sperrbildschirm.
        let startedAt: Date
        /// nil ohne Satz -- "0 Geraete - 0 Saetze" waere eine Zahl, die
        /// nichts Bestaetigtes zeigt (designsystem.md SS10).
        let zahlen: Zahlen?
    }

    static func mitte(_ session: LokaleSession?) -> Mitte? {
        guard let session else { return nil }
        let saetze = session.bloecke.flatMap(\.saetze).count
        let zahlen = saetze == 0 ? nil : Zahlen(
            geraete: Set(session.bloecke.map(\.machineId)).count,
            saetze: saetze
        )
        return Mitte(startedAt: session.startedAt, zahlen: zahlen)
    }

    /// Zuletzt bespieltes Geraet nach oben. Nicht einfach umgedreht: im
    /// Zirkel kehrt man zu einem frueheren Block zurueck, und dann ist DER
    /// das zuletzt benutzte Geraet, nicht der zuletzt angelegte Block.
    /// .distantPast ist nur der sichere Boden fuer einen Block ohne Satz.
    static func zuletztZuerst(_ bloecke: [LokalerBlock]) -> [LokalerBlock] {
        bloecke.sorted {
            ($0.saetze.map(\.performedAt).max() ?? .distantPast)
                > ($1.saetze.map(\.performedAt).max() ?? .distantPast)
        }
    }
}
