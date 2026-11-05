import Foundation

/// Der Bannertext nach einem gescheiterten Schreibversuch (R22) -- eine
/// reine Funktion aus `offen` und dem Fehler, damit sie ohne View testbar
/// ist, wie `OnboardingSchreiber` selbst.
///
/// Zwei Faelle, weil `.profil` immer zuerst laeuft (siehe
/// `OnboardingSchreiber`): steht es noch in `offen`, ist NICHTS
/// gespeichert -- auch nicht die Antworten aus Schritt 1. Ist es
/// verschwunden, hat der Server das Profil bereits, und der Satz nennt nur
/// noch das, was danach scheiterte. designsystem.md SS5/SS10: nie
/// "fehlgeschlagen", kein Ausrufezeichen, offline heisst "gespeichert,
/// wird gesendet" bzw. hier "bleibt hier stehen" -- nie "Verbindung
/// fehlgeschlagen".
enum OnboardingHinweis {
    ///
    /// `mitBestand == false` (Flow ohne Bestandsschritte, `nurPlan`): dann
    /// wurde kein Profil geschrieben, und "Dein Profil ist gespeichert"
    /// waere schlicht falsch.
    static func hinweis(offen: [OnboardingSchreibvorgang], fehler: APIError, mitBestand: Bool = true) -> String {
        if !mitBestand {
            let satz1 = fehler == .offline ? "Keine Verbindung." : fehler.servertext
            let liste = aufzaehlung(offen.compactMap(name))
            return "\(satz1) \(liste) noch nicht gespeichert — deine Angaben bleiben hier stehen."
        }
        guard !offen.contains(.profil) else {
            // `.offline` MUSS vor `servertext` abgefangen werden
            // (APIError.servertext dokumentiert das als Pflicht jedes
            // Aufrufers, siehe ProfilRootView) -- dass `servertext` fuer
            // .offline zufaellig denselben Satz liefert, ist kein Ersatz
            // fuer die eigene Fallunterscheidung.
            let satz1 = fehler == .offline ? "Keine Verbindung." : fehler.servertext
            return "\(satz1) Noch nichts gespeichert — deine Angaben bleiben hier stehen."
        }

        let liste = aufzaehlung(offen.compactMap(name))
        let grund = fehler == .offline ? "keine Verbindung" : fehler.servertext
        // `grund` traegt bei .offline keinen eigenen Punkt, `servertext`
        // dagegen schon (siehe APIError.servertext) -- ohne diese
        // Fallunterscheidung staende am Satzende entweder gar kein Punkt
        // oder einer zu viel.
        let satzende = grund.hasSuffix(".") ? grund : "\(grund)."
        return "Dein Profil ist gespeichert. \(liste) noch nicht — \(satzende)"
    }

    /// Der deutsche Name, wie ihn das Mitglied im Profil wiederfindet --
    /// `.profil` selbst taucht hier nie auf: dieser Zweig laeuft nur, wenn
    /// es schon geschrieben ist.
    private static func name(_ vorgang: OnboardingSchreibvorgang) -> String? {
        switch vorgang {
        case .profil: nil
        case .messwert: "Gewicht"
        case .wochenziel: "Wochenziel"
        case .zielgewicht: "Zielgewicht"
        case .trainingsprofil: "Zeit und Erfahrung"
        case .beschwerden: "Beschwerden"
        }
    }

    /// "Gewicht" · "Gewicht und Wochenziel" · "Gewicht, Wochenziel und
    /// Zielgewicht" -- die uebliche deutsche Aufzaehlung, Komma zwischen
    /// allen bis auf die letzten zwei, die ein "und" verbindet.
    ///
    /// Traegt ein Teil selbst schon ein "und" ("Zeit und Erfahrung"), bindet
    /// "sowie" das letzte an -- "Zeit und Erfahrung und Beschwerden" liest
    /// sich wie drei Teile statt zwei.
    private static func aufzaehlung(_ teile: [String]) -> String {
        guard let erstes = teile.first else { return "" }
        guard teile.count > 1 else { return erstes }
        let bindewort = teile.contains { $0.contains(" und ") } ? " sowie " : " und "
        return teile.dropLast().joined(separator: ", ") + bindewort + teile.last!
    }

    // MARK: - Plan-Schritt 1.4

    /// Die zwei Sonderfaelle der Vorschau (Entwuerfe 4.1, 4.2) -- nil fuer
    /// jeden anderen Fehler, der als Banner mit "Erneut versuchen" kommt.
    ///
    /// `beschwerden` sind die Bereiche, die das Mitglied in diesem Flow
    /// angegeben hat; der Server nennt nur den Baustein, nicht den Bereich.
    /// Gelesen wird hier nur der Name, nichts davon landet in einem Log.
    static func planSonderfall(_ fehler: APIError, beschwerden: [String: String]) -> PlanSonderfall? {
        switch fehler {
        case .planNichtMoeglich(_, let baustein, let grund):
            let name = BausteinName.text(baustein)
            if grund == "kein_geraet" {
                return PlanSonderfall(
                    titel: "Das geht noch nicht",
                    text: "Dein Studio hat dafür gerade kein aktives Gerät: \(name).",
                    aktion: nil)
            }
            // Bereiche in Anzeigereihenfolge, nicht in der zufaelligen des
            // Woerterbuchs.
            let bereiche = PlanAuswahl.bereiche.map(\.code).filter { beschwerden[$0] != nil }
            let angabe = switch bereiche.count {
            case 0: "deinen Angaben zu Beschwerden"
            case 1: "deiner Angabe zu \(PlanAuswahl.bereichName(bereiche[0]))"
            default: "deinen Angaben zu \(aufzaehlung(bereiche.map(PlanAuswahl.bereichName)))"
            }
            return PlanSonderfall(
                titel: "Das geht noch nicht",
                text: "Mit \(angabe) bleibt für „\(name)“ keine Übung übrig, die dein Studio anbietet.",
                aktion: .beschwerdenAendern)

        case .profilUnvollstaendig(_, let fehlt):
            // Feste Reihenfolge wie in den Bestandsschritten; Unbekanntes
            // (ein spaeterer Servercode) faellt still heraus.
            let bekannt: [(code: String, text: String, schritt: OnboardingSchritt)] = [
                ("ziel", "dein Ziel", .ziel),
                ("tage", "deine Trainingstage", .wieOft),
                ("trainingsprofil", "deine Zeit und Erfahrung", .planZeit),
            ]
            let fehlend = bekannt.filter { fehlt.contains($0.code) }
            let titel = switch fehlend.count {
            case 1: "Eine Angabe fehlt"
            case 2: "Zwei Angaben fehlen"
            case 3: "Drei Angaben fehlen"
            default: "Angaben fehlen"
            }
            let text = fehlend.isEmpty
                ? "Für den Plan brauchen wir noch ein paar Angaben."
                : "Für den Plan brauchen wir noch \(aufzaehlung(fehlend.map(\.text)))."
            // Ohne bekannte Luecke: "Zeit und Erfahrung" ist das Einzige,
            // was der Block selbst sicher ergaenzen kann.
            let schritte = fehlend.isEmpty ? [OnboardingSchritt.planZeit] : fehlend.map(\.schritt)
            return PlanSonderfall(titel: titel, text: text, aktion: .ergaenzen(schritte))

        default:
            return nil
        }
    }

    /// Der Bannertext, wenn das Beschwerden-Sheet im Profil den gespeicherten
    /// Stand nicht laden kann. Ohne ihn darf nichts gespeichert werden.
    static func beschwerdenLadefehler(_ fehler: APIError) -> String {
        let satz1 = fehler == .offline ? "Keine Verbindung." : fehler.servertext
        return "\(satz1) Deine gespeicherten Angaben lassen sich gerade nicht laden, deshalb ist Speichern noch gesperrt."
    }

    /// Der Bannertext, wenn Vorschlag oder Uebernahme an Netz oder Server
    /// scheitern. Nie "fehlgeschlagen" (designsystem.md SS10).
    static func planFehler(_ fehler: APIError, beimUebernehmen: Bool) -> String {
        if beimUebernehmen {
            let satz1 = fehler == .offline ? "Keine Verbindung." : fehler.servertext
            return "\(satz1) Dein Plan ist noch nicht übernommen."
        }
        if fehler == .offline { return "Keine Verbindung. Für den Vorschlag braucht die App eine Verbindung." }
        return fehler.servertext
    }
}

/// Zustand 4.1 / 4.2 der Vorschau.
struct PlanSonderfall: Equatable {
    enum Aktion: Equatable {
        /// 4.1, grund "beschwerden": zurueck zu Schritt 1.3.
        case beschwerdenAendern
        /// 4.2: diese Schritte nachholen, der erste ist das Ziel des Sprungs.
        case ergaenzen([OnboardingSchritt])
    }

    let titel: String
    let text: String
    /// nil: nur "Später" (4.1, grund "kein_geraet").
    let aktion: Aktion?
}
