import Foundation

/// Die Texte hinter "Warum so?" (Trainingsplan Etappe 5): feste, versionierte
/// Bausteine, keine KI. Drei Abschnitte -- Aufteilung (aus Struktur und
/// Gruenden des Plans), Gewicht und Wiederholungen (fuer alle Plaene gleich).
///
/// Ein Code, den erst ein neuerer Server kennt, wird ausgelassen statt als
/// Rohcode angezeigt.
///
/// Die Zahlen im Wiederholungstext sind feste Woerter, die App rechnet nichts
/// (F15). Sie muessen gleich bleiben mit `zielprofil` in
/// `packages/domain/src/trainingsplan-regeln.ts` und `GROBE_STUFE_EXTRA_WDH`
/// in `plangewicht.ts`; bei Aenderung dort `version` erhoehen.
enum PlanWarumText {
    static let version = "1.0.0"

    struct Abschnitt: Equatable {
        let titel: String
        let absaetze: [String]
    }

    /// Immer drei Abschnitte: "Aufteilung", "Gewicht", "Wiederholungen".
    static func abschnitte(struktur: String, gruende: [String]) -> [Abschnitt] {
        [
            Abschnitt(titel: "Aufteilung", absaetze: aufteilung(struktur: struktur, gruende: gruende)),
            Abschnitt(titel: "Gewicht", absaetze: gewicht),
            Abschnitt(titel: "Wiederholungen", absaetze: wiederholungen),
        ]
    }

    // MARK: - Aufteilung

    private static func aufteilung(struktur: String, gruende: [String]) -> [String] {
        var absaetze = [PlanStrukturText.text(struktur)]
        var gesehen = Set<String>()
        for code in gruende where gesehen.insert(code).inserted {
            if let satz = satz(fuer: code) { absaetze.append(satz) }
        }
        return absaetze
    }

    private static func satz(fuer code: String) -> String? {
        if code.hasPrefix("fokus_"), code != "fokus_zweiter_entfallen" {
            guard let bereich = fokusBereiche[String(code.dropFirst("fokus_".count))] else { return nil }
            return "Dein Schwerpunkt „\(bereich)“ bekommt in jedem Training eine eigene Übung."
        }
        return saetze[code]
    }

    private static let fokusBereiche = [
        "brust": "Brust", "ruecken": "Rücken", "schultern": "Schultern", "arme": "Arme",
        "po": "Po", "beine": "Beine", "bauch": "Bauch",
    ]

    private static let saetze = [
        "zeit_uebungen": "Wie viele Übungen du pro Training machst, richtet sich nach der Zeit, die du angegeben hast.",
        "zeit_saetze_reduziert": "Damit es in deine Zeit passt, haben einige Übungen einen Satz weniger.",
        "zeit_ergaenzung_entfallen": "Ergänzungsübungen sind weggefallen, damit die Hauptübungen in deine Zeit passen.",
        "zeit_aufwaermen_entfallen": "Fürs Aufwärmen ist im Plan keine Zeit eingeplant. Wärm dich trotzdem kurz auf.",
        "zeit_budget_nicht_ausgeschoepft": "Dein Studio hat nicht genug passende Übungen für die ganze Zeit. Einige Trainings sind deshalb kürzer als angegeben.",
        "fokus_zweiter_entfallen": "Für einen zweiten Schwerpunkt reicht die Zeit nicht, deshalb gilt nur der erste.",
        "abnehmen_cardio_zone": "Zum Abnehmen gehört Cardio im ruhigen Tempo, bei dem du dich noch unterhalten kannst.",
        "abnehmen_cardio_gekuerzt": "Das Cardio ist kürzer, sonst fehlt die Zeit fürs Krafttraining.",
        "abnehmen_kein_cardio_geraet": "Dein Studio hat kein Cardio-Gerät in der App, deshalb ist kein Cardio eingeplant.",
        "abnehmen_alltag": "Abnehmen entscheidet sich vor allem im Alltag, bei Ernährung und Bewegung. Das Training unterstützt dich dabei.",
        "bauch_kein_fettabbau": "Bauchübungen kräftigen den Bauch, bauen aber kein Fett am Bauch ab.",
        "anfaenger_reserve": "Am Anfang lässt du bewusst mehr Luft nach oben, damit du zuerst die Technik lernst.",
        "beschwerden_meiden": "Übungen, die deine Beschwerden belasten, haben wir weggelassen.",
        "beschwerden_vorsichtig": "Wo du vorsichtig sein willst, haben wir schonendere Übungen gewählt.",
    ]

    // MARK: - Gewicht und Wiederholungen

    private static let gewicht = [
        "Das erste Gewicht an einem Gerät ist eine vorsichtige Schätzung aus deinen Angaben im Profil, oder aus einer ähnlichen Übung, die du schon gemacht hast. Es ist ein Startwert, keine Vorgabe. Lieber etwas zu leicht als zu schwer.",
        "Danach passen wir es laufend an. Nach jedem Training rechnen wir neu: Schaffst du in allen Sätzen den oberen Wiederholungswert, wird es schwerer. Verfehlst du den unteren oder meldest ein Problem, wird es leichter. Kommt dir ein Gewicht zu leicht oder zu schwer vor, nimm einfach das passende. Wir rechnen ab dem, was du wirklich gemacht hast. Nach einer längeren Pause starten wir wieder etwas leichter.",
    ]

    private static let wiederholungen = [
        "Wie viele Wiederholungen du machst, hängt von deinem Ziel ab. Für Muskelaufbau sind es 8–12 bei Grundübungen und 10–15 bei Einzelübungen. Für Fitness und Abnehmen sind es 10–15, also etwas mehr.",
        "Bei Geräten mit groben Gewichtsstufen steigt das Gewicht erst, wenn du in allen Sätzen drei Wiederholungen mehr schaffst als den oberen Wert.",
    ]
}
