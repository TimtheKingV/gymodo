import Foundation

/// Der Teilobjekt-Schreibweg des Profils -- Registrierung (nur der
/// Name), Onboarding (alles auf einmal), Profil (ein Feld, oder eins auf
/// `null`).
///
/// `Encodable` allein unterscheidet `nil` ("Feld weglassen") nicht von
/// "Feld auf null setzen" -- beides waere derselbe `nil`-Wert. Genau
/// dieser Unterschied ist der Vertrag von `PUT /me/profile`
/// (`profilSchema` im Server: fehlt ein Schluessel, bleibt die Spalte
/// unberuehrt; `null` loescht sie). `Feld<T>` traegt die Unterscheidung:
/// die Eigenschaft selbst `nil` heisst "nicht gesendet", `.setzen`/
/// `.loeschen` heisst "gesendet, mit diesem Wert".
struct ProfilWrite: Encodable {
    enum Feld<T: Encodable>: Encodable {
        case setzen(T)
        case loeschen

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .setzen(let wert): try container.encode(wert)
            case .loeschen: try container.encodeNil()
            }
        }
    }

    var displayName: Feld<String>? = nil
    var sex: Feld<String>? = nil
    var heightCm: Feld<Int>? = nil
    var ageBand: Feld<String>? = nil
    var trainingGoal: Feld<String>? = nil
    /// Der Server nimmt nur das woertliche `true` an (`z.literal(true)`
    /// in `profilSchema`); `nil` oder `false` lassen den Schluessel weg.
    /// Ein zweites `onboardingDone` in einem Wiederholungsversuch waere
    /// sonst ein zweiter Abschlusszeitpunkt.
    var onboardingDone: Bool? = nil

    private enum CodingKeys: String, CodingKey {
        case displayName, sex, ageBand, heightCm, trainingGoal, onboardingDone
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let displayName { try container.encode(displayName, forKey: .displayName) }
        if let sex { try container.encode(sex, forKey: .sex) }
        if let ageBand { try container.encode(ageBand, forKey: .ageBand) }
        if let heightCm { try container.encode(heightCm, forKey: .heightCm) }
        if let trainingGoal { try container.encode(trainingGoal, forKey: .trainingGoal) }
        if onboardingDone == true { try container.encode(true, forKey: .onboardingDone) }
    }
}
