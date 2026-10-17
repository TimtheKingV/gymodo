import Foundation

/// Wie oft wurde ein Muskel bzw. eine Gruppe in den letzten 28 Tagen
/// trainiert -- gezaehlt in Einheiten (Sessions), nicht in Saetzen.
struct Haeufigkeit: Equatable {
    /// Alle Einheiten im Fenster, auch solche ohne darstellbaren Muskel --
    /// ausser reinen Cardio-Einheiten: sie liefern keine Muskeldaten und
    /// sollen keine Datenreife vortaeuschen.
    let einheiten: Int
    /// Einheiten je Muskelschluessel; nur Schluessel der sechs Gruppen.
    let jeMuskel: [String: Int]
    /// Einheiten je Gruppe; eine Einheit zaehlt je Gruppe einmal.
    let jeGruppe: [MuskelHauptgruppe: Int]

    /// Darunter ist die Auswertung zu duenn, um etwas zu behaupten.
    static let mindestEinheiten = 3
    static let fensterTage = 28
    /// Ein unterstuetzender Muskel zaehlt erst ab so vielen Saetzen je Einheit.
    static let mindestNebensaetze = 2

    var istAuswertbar: Bool { einheiten >= Self.mindestEinheiten }
}

extension Haeufigkeit {
    static func berechne(sessions: [SessionSummary], muskeln: [String: [GeraetMuskel]], jetzt: Date) -> Haeufigkeit {
        let grenze = jetzt.addingTimeInterval(-Double(fensterTage) * 86_400)
        let bekannt = Set(MuskelHauptgruppe.angezeigt.flatMap(\.muskelSchluessel))
        var einheiten = 0
        var jeMuskel: [String: Int] = [:]
        var jeGruppe: [MuskelHauptgruppe: Int] = [:]

        for session in sessions {
            guard let start = Zeitpunkt.parse(session.startedAt), start >= grenze, start <= jetzt else { continue }
            // Cardio-Saetze zaehlen nicht (Spec), auch wenn die Uebung Muskeln traegt.
            let alleSaetze = session.blocks.flatMap(\.sets)
            if !alleSaetze.isEmpty && alleSaetze.allSatisfy({ $0.cardio != nil }) { continue }
            einheiten += 1

            var haupt: [String: Int] = [:]
            var neben: [String: Int] = [:]
            for block in session.blocks {
                let saetze = block.sets.filter { $0.cardio == nil }.count
                guard saetze > 0 else { continue }
                for muskel in muskeln[block.exerciseId] ?? [] where bekannt.contains(muskel.key) {
                    switch muskel.role {
                    case .primary: haupt[muskel.key, default: 0] += saetze
                    case .secondary: neben[muskel.key, default: 0] += saetze
                    }
                }
            }
            let getroffen = Set(haupt.filter { $0.value > 0 }.keys)
                .union(neben.filter { $0.value >= mindestNebensaetze }.keys)
            for schluessel in getroffen { jeMuskel[schluessel, default: 0] += 1 }
            for gruppe in MuskelHauptgruppe.angezeigt
            where gruppe.muskelSchluessel.contains(where: getroffen.contains) {
                jeGruppe[gruppe, default: 0] += 1
            }
        }
        return Haeufigkeit(einheiten: einheiten, jeMuskel: jeMuskel, jeGruppe: jeGruppe)
    }
}
