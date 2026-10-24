import Foundation

/// Die Antworten des Blocks "Dein Trainingsplan" (Entwuerfe 1.1-1.3) --
/// ein reiner Wertetyp wie `OnboardingAntworten`, aus demselben Grund:
/// "Später" auf einem Schritt darf die anderen nicht zuruecksetzen.
///
/// Werte bleiben Servercodes als Text (`neu`, `po`, `knie`, `meiden`):
/// sie gehen unveraendert in `TrainingsplanProfil` und den Limits-PUT, und
/// die Anzeige uebersetzt sie an einer Stelle (`PlanAuswahl`).
struct PlanAntworten: Equatable {
    var minuten: Int?
    var erfahrung: String?
    /// Hoechstens zwei, in der Reihenfolge des Antippens (der Server prueft
    /// dieselbe Grenze, `profilSchema.focus.max(2)`).
    private(set) var schwerpunkt: [String]
    /// Bereich -> "vorsichtig" | "meiden". "Nichts" steht NICHT darin: ein
    /// Bereich ohne Stufe fehlt, wie im Server (`areas` ist partiell).
    private(set) var beschwerden: [String: String]
    /// Die ausdrueckliche, getrennte Einwilligung (DSGVO Art. 9). Ohne sie
    /// verlassen Beschwerden das Geraet nie.
    ///
    /// Den Haken entfernen leert die Auswahl: ohne Einwilligung liesse sie
    /// sich ohnehin nicht senden, und stehen gebliebene Bereiche sperrten
    /// Weiter -- der Widerruf (DELETE) waere dann nur ueber "alles auf
    /// Nichts, dann Haken weg" erreichbar, und das sagt dem Mitglied niemand
    /// (Review Task 10).
    var einwilligung: Bool {
        didSet { if !einwilligung { beschwerden = [:] } }
    }
    /// Was der Server zuletzt bestaetigt hat: nil = keine Einwilligung
    /// (404 oder nie gefragt). Nur damit laesst sich ein Widerruf von
    /// "nie eingewilligt" unterscheiden.
    private(set) var beschwerdenVorher: [String: String]?

    /// Vorbelegung aus `Member.trainingProfile`. Beschwerden stehen dort nie
    /// (Gesundheitsdaten, nicht im Bootstrap-Cache) -- die kommen ueber
    /// `beschwerdenUebernehmen` aus dem eigenen Abruf.
    init(profil: TrainingsplanProfil?) {
        minuten = profil?.minutes
        erfahrung = profil?.experience
        schwerpunkt = Array((profil?.focus ?? []).prefix(2))
        beschwerden = [:]
        einwilligung = false
        beschwerdenVorher = nil
    }

    // MARK: - Schwerpunkt

    /// Ein drittes Tippen ist wirkungslos (Entwurf 1.2: "gesperrt, kein
    /// Fehlerton") -- kein stiller Austausch gegen den aeltesten.
    mutating func schwerpunktUmschalten(_ bereich: String) {
        if let index = schwerpunkt.firstIndex(of: bereich) {
            schwerpunkt.remove(at: index)
        } else if schwerpunkt.count < 2 {
            schwerpunkt.append(bereich)
        }
    }

    // MARK: - Beschwerden

    func stufe(fuer bereich: String) -> String {
        beschwerden[bereich] ?? "nichts"
    }

    mutating func setzeStufe(_ stufe: String, fuer bereich: String) {
        beschwerden[bereich] = stufe == "nichts" ? nil : stufe
    }

    /// Der Stand vom Server (GET training-limits); nil heisst: keine
    /// Einwilligung.
    mutating func beschwerdenUebernehmen(_ areas: [String: String]?) {
        beschwerdenVorher = areas
        beschwerden = areas ?? [:]
        einwilligung = areas != nil
    }

    /// "Ueberspringen" auf Schritt 1.3: zurueck auf den Stand vom Server, damit
    /// ein uebersprungener Schritt nichts schreibt -- weder ein PUT noch ein
    /// versehentlicher Widerruf. Der Widerruf geht bewusst nur ueber
    /// Haken weg und Weiter.
    mutating func beschwerdenVerwerfen() {
        beschwerdenUebernehmen(beschwerdenVorher)
    }

    /// Nach einem gelungenen Schreibversuch ist der gesendete Stand der neue
    /// Serverstand; ein zweiter Versuch (etwa nach "Zeit oder Schwerpunkt
    /// ändern") schreibt sonst dieselben Beschwerden noch einmal.
    mutating func beschwerdenGeschrieben() {
        switch beschwerdenAktion {
        case .keine: break
        case .speichern(let areas): beschwerdenVorher = areas
        case .widerrufen: beschwerdenVorher = nil
        }
    }

    /// Was mit den Beschwerden passiert -- die eine Regel, die der
    /// Schreiber befolgt:
    /// - ohne Einwilligung: nie senden; war sie vorher erteilt, widerrufen;
    /// - mit Einwilligung: senden, ausser es aendert sich nichts (alles
    ///   "Nichts" ohne fruehere Einwilligung, oder derselbe Stand wie zuvor).
    var beschwerdenAktion: BeschwerdenAktion {
        guard einwilligung else {
            return beschwerdenVorher == nil ? .keine : .widerrufen
        }
        if beschwerdenVorher == nil && beschwerden.isEmpty { return .keine }
        if beschwerdenVorher == beschwerden { return .keine }
        return .speichern(beschwerden)
    }

    // MARK: - Weiter und Schreiben

    /// Weiter bleibt aktiv (Entwurf 1.1: fehlt eine Angabe, zeigt der
    /// Plan-Schritt den Fehler, 4.2). Nur 1.3 ist gedaempft, solange ein
    /// Bereich gewaehlt ist und die Einwilligung fehlt.
    func kannWeiter(_ schritt: OnboardingSchritt) -> Bool {
        guard schritt == .planBeschwerden else { return true }
        return beschwerden.isEmpty || einwilligung
    }

    /// Der PUT-Rumpf -- nil, solange eine Pflichtangabe fehlt: dann kein
    /// Aufruf, ein vorhandenes Profil bleibt, wie es ist.
    var trainingsprofil: TrainingsplanProfil? {
        guard let minuten, let erfahrung else { return nil }
        return TrainingsplanProfil(minutes: minuten, experience: erfahrung, focus: schwerpunkt)
    }
}

enum BeschwerdenAktion: Equatable {
    case keine
    case speichern([String: String])
    case widerrufen
}

/// Die Karte "Dein Trainingsplan" auf Home (Entwurf 1.5).
enum PlanEinrichten {
    /// Nur nach dem Onboarding (vorher zeigt das Gate den Block selbst),
    /// nur mit aktivem Studio (ein Plan gehoert einem Studio, F20) und nur,
    /// solange dort kein Plan steht.
    static func zeigtKarte(member: BootstrapResponse.Member, studioId: String?) -> Bool {
        guard member.onboardingCompletedAt != nil, let studioId else { return false }
        return !member.plans.contains { $0.studioId == studioId }
    }

    /// Mit Trainingsprofil ist alles gefragt, was der Plan braucht -- dann
    /// reicht die Vorschau.
    static func umfang(member: BootstrapResponse.Member) -> OnboardingUmfang {
        member.trainingProfile == nil ? .nurPlan : .nurVorschau
    }
}

/// Die festen Auswahlwerte des Blocks mit ihren Texten, in Anzeigereihenfolge
/// (Codes wie in trainingsplan-typen.ts).
enum PlanAuswahl {
    static let minuten = [30, 45, 60, 75, 90]

    struct Erfahrung: Equatable {
        let code: String
        let titel: String
        let zeile: String
    }

    static let erfahrungen = [
        Erfahrung(code: "neu", titel: "Neu", zeile: "Ich fange gerade an"),
        Erfahrung(code: "unregelmaessig", titel: "Schon trainiert", zeile: "Aber nicht regelmäßig oder systematisch"),
        Erfahrung(code: "regelmaessig", titel: "Regelmäßig", zeile: "Seit über 6 Monaten"),
    ]

    static let schwerpunkte: [(code: String, text: String)] = [
        ("brust", "Brust"), ("ruecken", "Rücken"), ("schultern", "Schultern"), ("arme", "Arme"),
        ("po", "Po"), ("beine", "Beine"), ("bauch", "Bauch"),
    ]

    static let bereiche: [(code: String, text: String)] = [
        ("knie", "Knie"), ("huefte", "Hüfte"), ("unterer_ruecken", "Unterer Rücken"),
        ("schulter", "Schulter"), ("ellenbogen_handgelenk", "Ellenbogen/Handgelenk"),
    ]

    static let stufen: [(code: String, text: String)] = [
        ("nichts", "Nichts"), ("vorsichtig", "Vorsichtig"), ("meiden", "Meiden"),
    ]

    static func bereichName(_ code: String) -> String {
        bereiche.first { $0.code == code }?.text ?? PlanNamen.lesbar(code)
    }
}
