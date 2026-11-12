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

    // MARK: Woche (Cardio-Schritt und "Deine Woche", Spec P2 §4)

    /// Wie oft Kraft, wie oft Cardio, wie lange, welche Arten -- nicht wann.
    /// Dieselben Zaehler wie in "Woche anpassen".
    var woche: WochenAuswahl
    /// Ob dieser Flow die Woche fragt (Cardio-Schritt). Nur dann gehen die
    /// Zaehler mit dem Trainingsprofil raus -- sonst nil, und der Server
    /// laesst sie, wie sie sind ("Zeit oder Schwerpunkt ändern" aus der
    /// reinen Vorschau darf die Woche nicht ueberschreiben).
    var wochenGefragt = false
    /// Der Stand aus dem Profil, fuer "Überspringen" (wie `beschwerdenVorher`).
    private let wocheVorher: WochenAuswahl
    /// Ob das Profil schon ein Kraft-Ziel hat: dann gilt es, und keine
    /// Vorbelegung ueberschreibt es.
    private let kraftAusProfil: Bool

    /// Vorbelegung aus `Member.trainingProfile`. Beschwerden stehen dort nie
    /// (Gesundheitsdaten, nicht im Bootstrap-Cache) -- die kommen ueber
    /// `beschwerdenUebernehmen` aus dem eigenen Abruf.
    ///
    /// Kraft pro Woche, in dieser Rangfolge: das Profil, die Antwort auf "Wie
    /// oft?" in diesem Flow (`wieOft`), das Wochenziel aus dem Bootstrap, 2.
    init(profil: TrainingsplanProfil?, wieOft: Int? = nil, wochenziel: Wochenziel? = nil) {
        minuten = profil?.minutes
        erfahrung = profil?.experience
        schwerpunkt = Array((profil?.focus ?? []).prefix(2))
        beschwerden = [:]
        einwilligung = false
        beschwerdenVorher = nil
        let vorgabe = Wochenziel(
            kraft: profil?.kraftProWoche ?? Self.kraftVorgabe,
            cardio: profil?.cardioProWoche ?? 0,
            cardioMinuten: profil?.cardioMinuten ?? Self.cardioMinutenVorgabe)
        var auswahl = WochenAuswahl(ziel: vorgabe, profil: profil)
        auswahl.cardioArten = PlanAuswahl.cardioArten.map(\.code).filter(auswahl.cardioArten.contains)
        woche = auswahl
        wocheVorher = auswahl
        kraftAusProfil = profil?.kraftProWoche != nil
        kraftVorbelegen(wieOft: wieOft, wochenziel: wochenziel)
    }

    /// Setzt Kraft neu, solange das Profil keines hat -- der Flow ruft es,
    /// sobald "Wie oft?" beantwortet ist (die Vorbelegung beim Start kennt die
    /// Antwort noch nicht).
    mutating func kraftVorbelegen(wieOft: Int?, wochenziel: Wochenziel?) {
        guard !kraftAusProfil else { return }
        woche.kraft = WochenAuswahl.klemmen(
            wieOft ?? wochenziel?.kraft ?? Self.kraftVorgabe, WochenAuswahl.kraftGrenzen)
    }

    /// Letzter Rueckfall fuer Kraft; Cardio beginnt bei 0.
    static let kraftVorgabe = 2
    static let cardioMinutenVorgabe = 30

    static func == (a: PlanAntworten, b: PlanAntworten) -> Bool {
        a.minuten == b.minuten && a.erfahrung == b.erfahrung && a.schwerpunkt == b.schwerpunkt
            && a.beschwerden == b.beschwerden && a.einwilligung == b.einwilligung
            && a.beschwerdenVorher == b.beschwerdenVorher
            && a.woche == b.woche && a.wochenGefragt == b.wochenGefragt
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

    // MARK: - Woche

    /// Schluessel aus CARDIO_ARTEN, in Anzeigereihenfolge.
    mutating func cardioArtUmschalten(_ art: String) {
        var neu = Set(woche.cardioArten)
        if neu.contains(art) { neu.remove(art) } else { neu.insert(art) }
        woche.cardioArten = PlanAuswahl.cardioArten.map(\.code).filter(neu.contains)
    }

    /// "Überspringen" auf dem Cardio-Schritt: zurueck auf den Stand aus dem
    /// Profil. Kraft bleibt, wie es ist -- das gehoert zu "Deine Woche".
    mutating func cardioVerwerfen() {
        woche.cardio = wocheVorher.cardio
        woche.cardioMinuten = wocheVorher.cardioMinuten
        woche.cardioArten = wocheVorher.cardioArten
    }

    /// "Deine Woche": "2× Kraft · 1× Cardio 30 min · Kurse nach Buchung";
    /// der Cardio-Teil entfaellt bei 0.
    var zusammenfassung: String {
        var teile = ["\(woche.kraft)× Kraft"]
        if woche.cardio > 0 { teile.append("\(woche.cardio)× Cardio \(woche.cardioMinuten) min") }
        teile.append("Kurse nach Buchung")
        return teile.joined(separator: " · ")
    }

    // MARK: - Weiter und Schreiben

    /// Weiter bleibt aktiv (Entwurf 1.1: fehlt eine Angabe, zeigt der
    /// Plan-Schritt den Fehler, 4.2). Gedaempft sind nur 1.3, solange ein
    /// Bereich gewaehlt ist und die Einwilligung fehlt, und der Cardio-Schritt,
    /// solange Cardio gewaehlt ist, aber keine Art.
    func kannWeiter(_ schritt: OnboardingSchritt) -> Bool {
        switch schritt {
        case .planBeschwerden: beschwerden.isEmpty || einwilligung
        case .planCardio: woche.cardio == 0 || !woche.cardioArten.isEmpty
        default: true
        }
    }

    /// Der Satz zu einem gedaempften Weiter.
    func weiterGesperrtHinweis(_ schritt: OnboardingSchritt) -> String? {
        guard !kannWeiter(schritt) else { return nil }
        switch schritt {
        case .planBeschwerden: return "Erst die Einwilligung bestätigen — oder überspringen."
        case .planCardio: return "Erst wählen, was du machst."
        default: return nil
        }
    }

    /// Der PUT-Rumpf -- nil, solange eine Pflichtangabe fehlt: dann kein
    /// Aufruf, ein vorhandenes Profil bleibt, wie es ist. Die Zaehler nur,
    /// wenn der Flow die Woche fragt (`wochenGefragt`); Tagesfelder gehen nie
    /// mit.
    var trainingsprofil: TrainingsplanProfil? {
        guard let minuten, let erfahrung else { return nil }
        let basis = TrainingsplanProfil(minutes: minuten, experience: erfahrung, focus: schwerpunkt)
        guard wochenGefragt else { return basis }
        var auswahl = woche
        // Arten ohne Cardio waeren eine Angabe ohne Haken.
        if auswahl.cardio == 0 { auswahl.cardioArten = [] }
        return auswahl.profil(aus: basis)
    }
}

enum BeschwerdenAktion: Equatable {
    case keine
    case speichern([String: String])
    case widerrufen
}

/// Die Karte "Dein Trainingsplan" auf Home (Entwurf 1.5).
enum PlanEinrichten {
    /// Nur nach dem Onboarding (vorher zeigt das Gate den Block selbst) und
    /// nur, solange das Mitglied keinen Plan hat. Der Plan gehoert dem
    /// Mitglied, nicht einem Studio: die Karte erscheint auch im Freien
    /// Training.
    static func zeigtKarte(member: BootstrapResponse.Member) -> Bool {
        member.onboardingCompletedAt != nil && member.plans.isEmpty
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

    /// Wie CARDIO_ARTEN in trainingsplan-typen.ts.
    static let cardioArten: [(code: String, text: String)] = [
        ("laufen", "Laufen"), ("radfahren", "Radfahren"), ("schwimmen", "Schwimmen"),
        ("wandern", "Wandern"), ("anderes", "Anderes"),
    ]

    static let stufen: [(code: String, text: String)] = [
        ("nichts", "Nichts"), ("vorsichtig", "Vorsichtig"), ("meiden", "Meiden"),
    ]

    static func bereichName(_ code: String) -> String {
        bereiche.first { $0.code == code }?.text ?? PlanNamen.lesbar(code)
    }
}
