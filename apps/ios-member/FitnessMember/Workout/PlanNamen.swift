import Foundation

/// Die deutschen Namen der Plan-Bausteine -- eine Tabelle fuer alle Screens
/// (Sonderfall "Plan nicht moeglich", Tausch-Sheet), damit derselbe
/// Baustein nicht an zwei Stellen verschieden heisst. Die Schluessel sind
/// die festen Servercodes (`BAUSTEINE` in trainingsplan-typen.ts).
enum BausteinName {
    static func text(_ baustein: String) -> String {
        switch baustein {
        case "beine_knie": "Beine, Knie"
        case "beine_huefte": "Beine, Hüfte"
        case "druecken": "Drücken"
        case "ziehen": "Ziehen"
        case "schulter": "Schulter"
        case "arme": "Arme"
        case "rumpf": "Rumpf"
        case "beine_ergaenzung": "Beine, Ergänzung"
        case "cardio": "Cardio"
        // Ein Baustein, den erst ein spaeterer Server kennt: lesbar statt
        // Rohschluessel mit Unterstrich, und kein Absturz.
        default: PlanNamen.lesbar(baustein)
        }
    }
}

/// Die Namen der Einheiten eines Plans. Eine Einheit heisst nach ihren
/// Muskeln ("Brust, Trizeps", `TrainingsProfil`), nicht nach dem Buchstaben
/// des Servers ("A", "B", "C", "OK_A"/"UK_A"). Ohne Muskelkatalog (oder wenn
/// das Profil nur "Training" sagt) bleibt der mechanische Name: "Einheit A"
/// bzw. "Oberkörper A".
///
/// Heissen mehrere Einheiten eines Plans gleich ("Ganzkörper"), bekommt jede
/// den Zusatz "· Schwerpunkt <Baustein>" ihres satzstaerksten Bausteins; sind
/// auch die Zusaetze gleich, haengt der Buchstabe als letzter Zusatz dran.
struct EinheitNamen: Equatable {
    private let namen: [String: String]

    private init(namen: [String: String]) { self.namen = namen }

    init(plan: Trainingsplan, muskeln: [String: [GeraetMuskel]]) {
        var roh: [String: String] = [:]
        for einheit in plan.einheiten {
            let titel = TrainingsProfil.berechne(einheit: einheit, muskeln: muskeln).titel
            if !muskeln.isEmpty, titel != "Training" { roh[einheit.key] = titel }
        }

        var namen: [String: String] = [:]
        for einheit in plan.einheiten {
            guard let titel = roh[einheit.key] else {
                namen[einheit.key] = Self.mechanisch(einheit.key)
                continue
            }
            let gleichnamig = plan.einheiten.filter { roh[$0.key] == titel }
            namen[einheit.key] = gleichnamig.count > 1
                ? "\(titel) · Schwerpunkt \(Self.schwerpunkt(einheit))" : titel
        }

        // Auch der Zusatz gleich: der Buchstabe unterscheidet.
        var haeufigkeit: [String: Int] = [:]
        for name in namen.values { haeufigkeit[name, default: 0] += 1 }
        for einheit in plan.einheiten where roh[einheit.key] != nil {
            if let name = namen[einheit.key], haeufigkeit[name, default: 0] > 1 {
                namen[einheit.key] = "\(name) (\(Self.buchstabe(einheit.key)))"
            }
        }
        self.namen = namen
    }

    /// Ohne Plan im Bootstrap: alle Namen mechanisch.
    init(bootstrap: BootstrapResponse?) {
        if let plan = PlanAnzeige.plan(bootstrap: bootstrap) {
            self.init(plan: plan, muskeln: HomeZeilen.muskelnJeUebung(bootstrap))
        } else {
            self.init(namen: [:])
        }
    }

    func name(_ key: String) -> String {
        namen[key] ?? Self.mechanisch(key)
    }

    /// Fuer Fliesstext: "Brust, Trizeps" in Anfuehrung, damit das Komma nicht
    /// wie eine Aufzaehlung liest ("Nächstes Mal ist „Brust, Trizeps“ dran.").
    /// Der mechanische Name ("Einheit A", "Oberkörper A") bleibt ohne -- wie
    /// in `PlanTausch`.
    func zitiert(_ key: String) -> String {
        guard let name = namen[key], name != Self.mechanisch(key) else { return name(key) }
        return "„\(name)“"
    }

    private static func mechanisch(_ key: String) -> String {
        if key.hasPrefix("OK_") { return "Oberkörper \(key.dropFirst(3))" }
        if key.hasPrefix("UK_") { return "Unterkörper \(key.dropFirst(3))" }
        return "Einheit \(key)"
    }

    private static func buchstabe(_ key: String) -> String {
        key.split(separator: "_").last.map(String.init) ?? key
    }

    /// Der Baustein mit den meisten Saetzen; bei Gleichstand der erste in
    /// Positionsreihenfolge.
    private static func schwerpunkt(_ einheit: TrainingsplanEinheit) -> String {
        var summen: [String: Int] = [:]
        var reihenfolge: [String] = []
        for position in einheit.positionen {
            if summen[position.baustein] == nil { reihenfolge.append(position.baustein) }
            summen[position.baustein, default: 0] += position.saetze
        }
        var bester: String?
        for baustein in reihenfolge where bester == nil || summen[baustein, default: 0] > summen[bester!, default: 0] {
            bester = baustein
        }
        return BausteinName.text(bester ?? "")
    }
}

/// Der eine Satz unter "Dein Plan" (Entwurf 1.4): wie die Einheiten
/// aufeinander folgen. Die Folge haengt nie am Wochentag (Spec F5), das
/// sagt jeder Satz ausdruecklich.
enum PlanStrukturText {
    static func text(_ struktur: String) -> String {
        switch struktur {
        case "gk_eine": "Ganzkörper, eine Einheit. Jedes Training ist dieselbe Einheit."
        case "gk_ab": "Ganzkörper, zwei Einheiten im Wechsel. Die nächste folgt der letzten, egal an welchem Tag."
        case "gk_abc": "Ganzkörper, drei Einheiten im Wechsel. Die nächste folgt der letzten, egal an welchem Tag."
        case "ober_unter": "Oberkörper und Unterkörper im Wechsel. Die nächste Einheit folgt der letzten, egal an welchem Tag."
        default: "Die Einheiten folgen aufeinander, egal an welchem Tag."
        }
    }
}

enum PlanNamen {
    /// "neu_dabei" -> "Neu dabei".
    static func lesbar(_ schluessel: String) -> String {
        let text = schluessel.replacingOccurrences(of: "_", with: " ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}
