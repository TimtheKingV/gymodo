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

    /// Detail: jeder Muskel im Vergleich mit dem Mittel aller Gruppen.
    /// Mit `nurGruppe` stehen alle Muskeln ausserhalb der Gruppe in `line`.
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

    /// Trainingskarte auf Home: stark = Akzent, schwach = gedrueckter
    /// Akzent. Wer nicht beansprucht wurde, fehlt -- `MuskelFigur` malt ihn
    /// dann grau.
    static func farben(profil: TrainingsProfil) -> [String: Color] {
        profil.stufen.mapValues { stufe in
            switch stufe {
            case .stark: DesignSystem.Color.accent
            case .schwach: DesignSystem.Color.accentPressed
            }
        }
    }

    /// Startansicht: jeder Muskel im Status seiner Gruppe gegenueber allen
    /// sechs -- dieselbe Aussage wie Liste und Satz. Seltene Muskeln grau.
    /// Der Vergleich der Muskeln innerhalb der Gruppe bleibt dem Detail.
    static func farbenAlle(_ h: Haeufigkeit) -> [String: Color] {
        var farben: [String: Color] = [:]
        for gruppe in MuskelHauptgruppe.angezeigt {
            let gruppenfarbe = farbe(Ausgewogenheit.status(gruppe: gruppe, in: h))
            for muskel in gruppe.muskelSchluessel {
                farben[muskel] = Ausgewogenheit.seltene.contains(muskel) ? DesignSystem.Color.muskelInaktiv : gruppenfarbe
            }
        }
        return farben
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
