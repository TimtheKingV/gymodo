import SwiftUI

/// Farben der Muskelfigur auf Home: Status je Muskel bzw. Gruppe.
enum MuskelFarben {
    static func farbe(_ status: MuskelStatus) -> Color {
        switch status {
        case .nachholbedarf: DesignSystem.Color.warn
        case .ok: DesignSystem.Color.accentPressed
        case .viel: DesignSystem.Color.accent
        case .kaumUebungen, .keineAuswertung: DesignSystem.Color.muskelInaktiv
        }
    }

    /// Mit `nurGruppe` stehen alle Muskeln ausserhalb der Gruppe in `line`;
    /// sonst bekommt jeder Muskel die Statusfarbe aus seiner eigenen Gruppe.
    static func farben(gruppe: MuskelHauptgruppe, h: Haeufigkeit, nurGruppe: Bool) -> [String: Color] {
        var farben: [String: Color] = [:]
        for andere in MuskelHauptgruppe.angezeigt {
            for muskel in andere.muskelSchluessel {
                if nurGruppe && andere != gruppe {
                    farben[muskel] = DesignSystem.Color.line
                } else {
                    farben[muskel] = farbe(Ausgewogenheit.status(muskel: muskel, gruppe: andere, in: h))
                }
            }
        }
        return farben
    }

    /// Startansicht: jeder Muskel nach seiner eigenen Gruppe.
    static func farbenAlle(_ h: Haeufigkeit) -> [String: Color] {
        farben(gruppe: .brust, h: h, nurGruppe: false)
    }
}

extension MuskelHauptgruppe {
    /// Welche Seiten der Figur die Detailansicht der Gruppe zeigt.
    var detailAnsichten: Set<MuskelFigur.Ansicht> {
        switch self {
        case .ruecken: [.hinten]
        case .brust, .rumpf: [.vorne]
        case .schultern, .arme, .beine, .weitere, .mehrere: [.vorne, .hinten]
        }
    }
}
