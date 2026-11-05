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

/// Die Einheiten eines Plans heissen beim Server "A", "B", "C" oder
/// "OK_A"/"UK_A" (Ober-/Unterkoerper, `strukturFuerTage`); das Mitglied
/// liest "Einheit A" bzw. "Oberkörper A".
enum EinheitName {
    static func text(_ key: String) -> String {
        if key.hasPrefix("OK_") { return "Oberkörper \(key.dropFirst(3))" }
        if key.hasPrefix("UK_") { return "Unterkörper \(key.dropFirst(3))" }
        return "Einheit \(key)"
    }
}

/// Der eine Satz unter "Dein Plan" (Entwurf 1.4): wie die Einheiten
/// aufeinander folgen. Die Folge haengt nie am Wochentag (Spec F5), das
/// sagt jeder Satz ausdruecklich.
enum PlanStrukturText {
    static func text(_ struktur: String) -> String {
        switch struktur {
        case "gk_eine": "Ganzkörper, eine Einheit. Jedes Training ist dieselbe Einheit."
        case "gk_ab": "Ganzkörper, A und B im Wechsel. Nach A kommt B, egal an welchem Tag."
        case "gk_abc": "Ganzkörper, A, B und C im Wechsel. Nach A kommt B, nach B kommt C, egal an welchem Tag."
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
