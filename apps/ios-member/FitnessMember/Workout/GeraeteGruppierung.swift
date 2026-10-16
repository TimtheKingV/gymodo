import Foundation

/// Die Geraeteliste einer Kategorie nach Muskel -- nur Anzeige.
///
/// Ein Geraet gehoert zu den Hauptgruppen all seiner Uebungen. In der Ansicht
/// "Alle" steht es genau einmal: bei seiner einzigen Gruppe, sonst unter
/// "Mehrere". Filtert man ausdruecklich nach einer Gruppe, erscheint es
/// dort trotzdem -- auch ein Geraet unter "Mehrere".
enum GeraeteGruppierung {
    struct Abschnitt: Equatable {
        let gruppe: MuskelHauptgruppe
        let eintraege: [GeraeteAuswahl.Eintrag]
    }

    /// Die Hauptgruppen aller Hauptmuskeln aller Uebungen; ohne darstellbaren Muskel `weitere`.
    static func gruppen(von station: Station) -> Set<MuskelHauptgruppe> {
        let gruppen = station.exercises
            .reduce(into: Set<MuskelHauptgruppe>()) { $0.formUnion(UebungsGruppierung.hauptgruppen(muskeln: $1.muscles)) }
            .subtracting([.weitere])
        return gruppen.isEmpty ? [.weitere] : gruppen
    }

    /// Wo das Geraet in "Alle" steht.
    static func heimat(von station: Station) -> MuskelHauptgruppe {
        let gruppen = gruppen(von: station)
        return gruppen.count == 1 ? gruppen.first! : .mehrere
    }

    /// `eintraege` kommt schon in der Reihenfolge, die innerhalb einer
    /// Gruppe gelten soll (A-Z). Leere Gruppen entfallen.
    /// - nur: allein diese Gruppe, mit allen Geraeten, die sie bedienen.
    static func gruppieren(_ eintraege: [GeraeteAuswahl.Eintrag], nur filter: MuskelHauptgruppe? = nil) -> [Abschnitt] {
        if let filter {
            let treffer = eintraege.filter { eintrag in
                switch filter {
                case .mehrere, .weitere: heimat(von: eintrag.station) == filter
                default: gruppen(von: eintrag.station).contains(filter)
                }
            }
            return treffer.isEmpty ? [] : [Abschnitt(gruppe: filter, eintraege: treffer)]
        }
        return MuskelHauptgruppe.allCases.compactMap { gruppe in
            let treffer = eintraege.filter { heimat(von: $0.station) == gruppe }
            return treffer.isEmpty ? nil : Abschnitt(gruppe: gruppe, eintraege: treffer)
        }
    }

    /// Die Bullets: jede Gruppe, unter der beim Filtern ein Geraet steht.
    static func vorhandeneGruppen(_ eintraege: [GeraeteAuswahl.Eintrag]) -> [MuskelHauptgruppe] {
        MuskelHauptgruppe.allCases.filter { !gruppieren(eintraege, nur: $0).isEmpty }
    }

    /// Nur Geraete, an denen schon trainiert wurde, das juengste zuerst.
    static func favoriten(_ eintraege: [GeraeteAuswahl.Eintrag]) -> [GeraeteAuswahl.Eintrag] {
        eintraege
            .filter { $0.zuletzt != nil }
            .sorted { $0.zuletzt!.performedAt > $1.zuletzt!.performedAt }
    }
}
