import Foundation

/// Was ein Training beansprucht hat und wie es heisst -- fuer die kleine
/// Figur und die Titelzeile der Trainingskarte auf Home.
///
/// Gerechnet wird aus den Saetzen und den Muskeln der Uebungen im Katalog
/// (`HomeZeilen.muskelnJeUebung`). Reine ANZEIGE: nichts davon wird
/// gespeichert.
struct TrainingsProfil: Equatable {
    enum Stufe: Equatable {
        case stark, schwach
    }

    /// "Brust, Trizeps", "Oberkörper", "Ganzkörper" ...
    let titel: String
    /// Muskelschluessel -> Stufe. Ein unbelasteter Muskel fehlt und bleibt
    /// auf der Figur grau.
    let stufen: [String: Stufe]

    /// Ab diesem Anteil an der staerksten Muskellast gilt ein Muskel als
    /// stark, darunter als schwach.
    static let starkAb = 0.5
    /// Ein Nebenmuskel (Bizeps, Trizeps, Bauch) kommt in den Namen, wenn
    /// er mindestens so viel der Gesamtlast traegt.
    static let nebenmuskelAb = 0.10
    static let bauchAb = 0.15
    /// Hauptsaechlich Arme: nur dann heisst das Training "Arme".
    static let nurArmeAb = 0.60
    static let beineAb = 0.25
    static let nurBeineAb = 0.50
    static let oberkoerperAnteilAb = 0.25
    /// Zwei Oberkoerpergruppen mit je so viel: "Oberkörper".
    static let oberkoerperGruppeAb = 0.20
    /// Ein Nebenmuskel zaehlt erst ab so vielen Saetzen -- wie bei
    /// `Haeufigkeit.mindestNebensaetze`.
    private static let mindestNebensaetze = 2
    private static let nebensatzGewicht = 0.5

    static func berechne(
        karte: Trainingskarte, muskeln: [String: [GeraetMuskel]]
    ) -> TrainingsProfil {
        var last: [String: Double] = [:]
        var hatCardio = false

        for einheit in karte.teile {
            for block in einheit.blocks {
                let kraft = block.sets.filter { $0.cardio == nil }.count
                if kraft < block.sets.count { hatCardio = true }
                guard kraft > 0 else { continue }
                for muskel in muskeln[block.exerciseId] ?? [] {
                    switch muskel.role {
                    case .primary:
                        last[muskel.key, default: 0] += Double(kraft)
                    case .secondary where kraft >= mindestNebensaetze:
                        last[muskel.key, default: 0] += Double(kraft) * nebensatzGewicht
                    case .secondary:
                        break
                    }
                }
            }
        }

        guard let staerkste = last.values.max() else {
            return TrainingsProfil(titel: hatCardio ? "Cardio" : "Training", stufen: [:])
        }

        let stufen = last.mapValues { $0 >= staerkste * starkAb ? Stufe.stark : .schwach }
        let gesamt = last.values.reduce(0, +)
        func anteil(_ schluessel: [String]) -> Double {
            schluessel.reduce(0) { $0 + (last[$1] ?? 0) } / gesamt
        }

        let brust = anteil(MuskelHauptgruppe.brust.muskelSchluessel)
        let ruecken = anteil(MuskelHauptgruppe.ruecken.muskelSchluessel)
        let schultern = anteil(MuskelHauptgruppe.schultern.muskelSchluessel)
        let beine = anteil(MuskelHauptgruppe.beine.muskelSchluessel)
        let bauch = anteil(MuskelHauptgruppe.rumpf.muskelSchluessel)
        let arme = anteil(MuskelHauptgruppe.arme.muskelSchluessel)
        let bizeps = anteil(["biceps"])
        let trizeps = anteil(["triceps"])
        let oberkoerper = brust + ruecken + schultern

        // Reihenfolge der Gruppen = Vorrang bei Gleichstand.
        let gruppen: [(name: String, anteil: Double)] = [
            ("Brust", brust), ("Rücken", ruecken), ("Schultern", schultern),
            ("Beine", beine), ("Bauch", bauch),
        ]
        let haupt = gruppen.max { $0.anteil < $1.anteil }!

        let titel: String
        if arme >= nurArmeAb {
            titel = "Arme"
        } else if beine >= beineAb && oberkoerper >= oberkoerperAnteilAb {
            titel = "Ganzkörper"
        } else if beine >= nurBeineAb {
            titel = bauch >= bauchAb ? "Beine, Bauch" : "Beine"
        } else if beine < beineAb,
            [brust, ruecken, schultern].filter({ $0 >= oberkoerperGruppeAb }).count >= 2
        {
            titel = "Oberkörper"
        } else {
            var namen = [haupt.name]
            switch haupt.name {
            case "Brust", "Schultern": if trizeps >= nebenmuskelAb { namen.append("Trizeps") }
            case "Rücken": if bizeps >= nebenmuskelAb { namen.append("Bizeps") }
            default: break
            }
            if haupt.name != "Bauch", bauch >= bauchAb { namen.append("Bauch") }
            titel = namen.joined(separator: ", ")
        }

        return TrainingsProfil(titel: titel, stufen: stufen)
    }
}
