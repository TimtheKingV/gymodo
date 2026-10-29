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

    // MARK: Woche (Leinwaende 2c, 2c2, 2c3)

    /// Ja/Nein auf "Gehst du in Kurse?"; nil = noch nicht getippt (Weiter
    /// geht dann wie bei Nein, es bleibt bei keinen Kurstagen).
    private(set) var kursAntwort: Bool?
    /// ISO-Wochentage (1 = Mo ... 7 = So), aufsteigend.
    private(set) var kursTage: [Int]
    private(set) var cardioAntwort: Bool?
    private(set) var cardioTage: [Int]
    /// Schluessel aus CARDIO_ARTEN, in Anzeigereihenfolge.
    private(set) var cardioArten: [String]
    /// Nur durch "Tauschen" in "Deine Woche" gesetzt; leer = der Server
    /// verteilt die Krafttage selbst (die App rechnet ihre Zahl nicht, F15).
    private(set) var kraftTage: [Int]
    /// Ob dieser Flow die Woche fragt (Kurs-/Cardio-Schritt). Nur dann gehen
    /// die vier Tagesfelder mit dem Trainingsprofil raus -- sonst nil, und
    /// der Server laesst sie, wie sie sind ("Zeit oder Schwerpunkt ändern"
    /// aus der reinen Vorschau darf die Woche nicht ueberschreiben).
    var wochenGefragt = false
    /// Der Stand aus dem Profil, fuer "Überspringen" (wie `beschwerdenVorher`).
    private let wocheVorher: (kurs: [Int], cardio: [Int], arten: [String])

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
        let kurs = Self.tage(profil?.kursTage)
        let cardio = Self.tage(profil?.cardioTage)
        let arten = PlanAuswahl.cardioArten.map(\.code).filter { (profil?.cardioArten ?? []).contains($0) }
        kursTage = kurs
        cardioTage = cardio
        cardioArten = arten
        kraftTage = Self.tage(profil?.kraftTage)
        kursAntwort = kurs.isEmpty ? nil : true
        cardioAntwort = cardio.isEmpty ? nil : true
        wocheVorher = (kurs, cardio, arten)
    }

    private static func tage(_ tage: [Int]?) -> [Int] {
        Set((tage ?? []).filter { (1...7).contains($0) }).sorted()
    }

    static func == (a: PlanAntworten, b: PlanAntworten) -> Bool {
        a.minuten == b.minuten && a.erfahrung == b.erfahrung && a.schwerpunkt == b.schwerpunkt
            && a.beschwerden == b.beschwerden && a.einwilligung == b.einwilligung
            && a.beschwerdenVorher == b.beschwerdenVorher
            && a.kursAntwort == b.kursAntwort && a.kursTage == b.kursTage
            && a.cardioAntwort == b.cardioAntwort && a.cardioTage == b.cardioTage
            && a.cardioArten == b.cardioArten && a.kraftTage == b.kraftTage
            && a.wochenGefragt == b.wochenGefragt
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

    /// Die Kursfrage (2c) erscheint nur mit zugeordnetem Studio, das Kurse
    /// anbietet (Leinwand-Notiz s2) -- sonst entfaellt der Schritt, und der
    /// Zaehler zaehlt ihn nicht.
    func kursFrageSichtbar(hatStudioMitKursen: Bool) -> Bool {
        hatStudioMitKursen
    }

    /// Ohne Kursfrage gibt es keine Kurstage: gespeicherte aus einem
    /// frueheren Studio sperrten sonst Cardio-Tage, ohne dass das Mitglied
    /// sieht, warum.
    mutating func kurseOhneFrage() {
        kursAntwort = nil
        setzeTage(.kurs, [])
    }

    mutating func kurseBeantworten(_ ja: Bool) {
        kursAntwort = ja
        if !ja { setzeTage(.kurs, []) }
    }

    /// "Nein, nur Gym" leert Tage und Arten.
    mutating func cardioBeantworten(_ ja: Bool) {
        cardioAntwort = ja
        if !ja {
            setzeTage(.cardio, [])
            cardioArten = []
        }
    }

    mutating func cardioArtUmschalten(_ art: String) {
        if let index = cardioArten.firstIndex(of: art) {
            cardioArten.remove(at: index)
        } else {
            let neu = Set(cardioArten + [art])
            cardioArten = PlanAuswahl.cardioArten.map(\.code).filter(neu.contains)
        }
    }

    /// Warum ein Tag fuer `art` gerade nicht waehlbar ist; nil = waehlbar
    /// (auch: schon gewaehlt, dann waehlt Tippen ihn ab).
    func tagGesperrt(_ tag: Int, fuer art: Wochenart) -> TagSperre? {
        if tage(art).contains(tag) { return nil }
        for andere in [Wochenart.kurs, .cardio] where andere != art && tage(andere).contains(tag) {
            return .belegt(andere)
        }
        // Kurs und Cardio duerfen nicht alle sieben Tage belegen (der Server
        // lehnt das mit 422 ab): einer bleibt fuers Krafttraining.
        if art != .kraft, Set(kursTage + cardioTage + [tag]).count == 7 { return .letzterFreierTag }
        return nil
    }

    /// Schaltet `tag` fuer Kurs oder Cardio um. Anders als im Einplanen-Sheet
    /// (`PlanWochentage.umschalten`) nimmt das Onboarding einen Tag nie einer
    /// anderen Art weg: die steht in einem frueheren Schritt fest. nil =
    /// umgeschaltet, sonst der Grund der Ablehnung fuer den Hinweis.
    @discardableResult
    mutating func tagUmschalten(_ tag: Int, fuer art: Wochenart) -> TagSperre? {
        guard (1...7).contains(tag), art != .kraft else { return nil }
        if let sperre = tagGesperrt(tag, fuer: art) { return sperre }
        var neu = Set(tage(art))
        if neu.contains(tag) { neu.remove(tag) } else { neu.insert(tag) }
        setzeTage(art, neu.sorted())
        return nil
    }

    /// Vor jedem neuen Vorschlag fuer "Deine Woche": der Tausch gehoert zu
    /// genau einem Vorschlag. Danach verteilt der Server die Krafttage
    /// wieder selbst -- auch, wenn sich Ziel oder Wochentage seitdem
    /// geaendert haben.
    mutating func wocheNeuVorschlagen() {
        kraftTage = []
    }

    /// "Tauschen" (2c3): der Krafttag `von` wandert auf den freien Tag
    /// `nach`. Gezaehlt wird vom Raster des Servers aus, nach einem ersten
    /// Tausch von dessen Stand. `false` = nicht moeglich (kein Krafttag oder
    /// Ziel belegt), dann aendert sich nichts.
    @discardableResult
    mutating func kraftTagTauschen(von: Int, nach: Int, raster: [Rasterplatz]) -> Bool {
        let aktuell = kraftTage.isEmpty ? raster.filter { $0.art == .kraft }.map(\.tag) : kraftTage
        let belegt = Set(aktuell + kursTage + cardioTage)
        guard aktuell.contains(von), (1...7).contains(nach), !belegt.contains(nach) else { return false }
        kraftTage = Set(aktuell.filter { $0 != von } + [nach]).sorted()
        return true
    }

    /// Was "Deine Woche" zeigt: ohne Tausch genau das Raster des Servers,
    /// mit Tausch dieselbe Anzeige-Regel wie der Plan-Tab
    /// (`PlanTabZustand.anzeigeRaster`: die Folge bleibt, die Tage wandern).
    func wochenAnzeige(raster: [Rasterplatz], einheiten: [String]) -> [Rasterplatz] {
        guard !kraftTage.isEmpty else { return raster }
        let profil = TrainingsplanProfil(
            minutes: minuten ?? 0, experience: erfahrung ?? "", focus: schwerpunkt,
            kursTage: kursTage, cardioTage: cardioTage, cardioArten: cardioArten, kraftTage: kraftTage)
        return PlanTabZustand.anzeigeRaster(planRaster: raster, einheiten: einheiten, profil: profil)
    }

    /// "Überspringen" auf 2c/2c2: zurueck auf den Stand aus dem Profil.
    mutating func kurseVerwerfen() {
        kursAntwort = wocheVorher.kurs.isEmpty ? nil : true
        setzeTage(.kurs, wocheVorher.kurs)
    }

    mutating func cardioVerwerfen() {
        cardioAntwort = wocheVorher.cardio.isEmpty ? nil : true
        setzeTage(.cardio, wocheVorher.cardio)
        cardioArten = wocheVorher.arten
    }

    private func tage(_ art: Wochenart) -> [Int] {
        switch art {
        case .kurs: kursTage
        case .cardio: cardioTage
        case .kraft: kraftTage
        }
    }

    /// Jede Aenderung an Kurs- oder Cardio-Tagen verwirft einen Tausch: er
    /// bezog sich auf ein anderes Raster und koennte jetzt auf einem festen
    /// Tag liegen (der Server lehnte das ab).
    private mutating func setzeTage(_ art: Wochenart, _ neu: [Int]) {
        switch art {
        case .kurs:
            if kursTage != neu { kraftTage = [] }
            kursTage = neu
        case .cardio:
            if cardioTage != neu { kraftTage = [] }
            cardioTage = neu
        case .kraft:
            kraftTage = neu
        }
    }

    // MARK: - Weiter und Schreiben

    /// Weiter bleibt aktiv (Entwurf 1.1: fehlt eine Angabe, zeigt der
    /// Plan-Schritt den Fehler, 4.2). Gedaempft sind nur 1.3, solange ein
    /// Bereich gewaehlt ist und die Einwilligung fehlt, und 2c/2c2, solange
    /// "Ja" ohne Tag (Cardio: ohne Tag oder Art) steht.
    func kannWeiter(_ schritt: OnboardingSchritt) -> Bool {
        switch schritt {
        case .planBeschwerden: beschwerden.isEmpty || einwilligung
        case .planKurse: kursAntwort != true || !kursTage.isEmpty
        case .planCardio: cardioAntwort != true || (!cardioTage.isEmpty && !cardioArten.isEmpty)
        default: true
        }
    }

    /// Der Satz zu einem gedaempften Weiter.
    func weiterGesperrtHinweis(_ schritt: OnboardingSchritt) -> String? {
        guard !kannWeiter(schritt) else { return nil }
        switch schritt {
        case .planBeschwerden: return "Erst die Einwilligung bestätigen — oder überspringen."
        case .planKurse: return "Erst einen Tag wählen — oder „Nein“."
        case .planCardio:
            return cardioTage.isEmpty ? "Erst einen Tag wählen — oder „Nein“." : "Erst wählen, was du machst."
        default: return nil
        }
    }

    /// Der PUT-Rumpf -- nil, solange eine Pflichtangabe fehlt: dann kein
    /// Aufruf, ein vorhandenes Profil bleibt, wie es ist. Die Tagesfelder
    /// nur, wenn der Flow die Woche fragt (`wochenGefragt`), dann alle vier:
    /// ein gespeicherter Krafttag duerfte sonst mit einem neuen Kurstag
    /// kollidieren.
    var trainingsprofil: TrainingsplanProfil? {
        guard let minuten, let erfahrung else { return nil }
        guard wochenGefragt else {
            return TrainingsplanProfil(minutes: minuten, experience: erfahrung, focus: schwerpunkt)
        }
        return TrainingsplanProfil(
            minutes: minuten, experience: erfahrung, focus: schwerpunkt,
            kursTage: kursTage, cardioTage: cardioTage, cardioArten: cardioArten, kraftTage: kraftTage)
    }
}

/// Warum ein Tag im Kurs- oder Cardio-Schritt nicht waehlbar ist.
enum TagSperre: Equatable {
    /// Der Tag gehoert schon der anderen Art (E4).
    case belegt(Wochenart)
    /// Es waere der siebte feste Tag: einer bleibt fuers Krafttraining.
    case letzterFreierTag
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
