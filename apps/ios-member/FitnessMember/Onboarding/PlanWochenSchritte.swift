import SwiftUI

// Die Schritte "Gehst du in Kurse?" (Leinwand 2c), "Machst du auch Cardio
// außerhalb?" (2c2) und "Deine Woche" (2c3). Die Huelle (Kopfzeile, Titel,
// Weiter, Ueberspringen) ist wie bei 1.1-1.3 `OnboardingScreen`; hier steht
// nur der Inhalt.
//
// "WELCHE?" aus 2c fehlt bewusst: das Profil speichert nur Kurstage, keine
// Kurse -- eine Auswahl, die nirgends ankommt, versprach etwas Falsches.

/// Die Texte des Wochenblocks -- rein, damit sie ohne UI pruefbar bleiben.
/// Sie nennen Tage, nie die Zahl der Krafteinheiten: die bestimmt der Server
/// (F15).
enum PlanWochenText {
    static let kurzname = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    static let vollname = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]
    private static let adverb = ["montags", "dienstags", "mittwochs", "donnerstags", "freitags", "samstags", "sonntags"]

    static func kurz(_ tag: Int) -> String { kurzname[(tag - 1) % 7] }
    static func voll(_ tag: Int) -> String { vollname[(tag - 1) % 7] }

    /// "a", "a und b", "a, b und c".
    static func liste(_ teile: [String]) -> String {
        guard let letzter = teile.last else { return "" }
        guard teile.count > 1 else { return letzter }
        return teile.dropLast().joined(separator: ", ") + " und " + letzter
    }

    /// 2c: "Montags ist dein Kurs gesetzt. ..."; nil ohne Tag.
    static func kursHinweis(_ tage: [Int]) -> String? {
        guard !tage.isEmpty else { return nil }
        let wann = liste(tage.sorted().map { adverb[$0 - 1] })
        let erster = wann.prefix(1).uppercased() + wann.dropFirst()
        let satz = tage.count == 1 ? "\(erster) ist dein Kurs gesetzt." : "\(erster) sind deine Kurse gesetzt."
        return satz + " Die Kraft-Einheiten legen wir auf die übrigen Tage."
    }

    /// 2c2: "Cardio am Sonntag ist ein fester Termin im Plan. ..."; nil ohne Tag.
    static func cardioHinweis(_ tage: [Int]) -> String? {
        guard !tage.isEmpty else { return nil }
        let wann = liste(tage.sorted().map(voll))
        let satz = tage.count == 1
            ? "Cardio am \(wann) ist ein fester Termin im Plan."
            : "Cardio am \(wann) sind feste Termine im Plan."
        return satz + " Umfang und Tempo kommen später, jetzt zählt nur die Einheit."
    }

    /// Warum ein Tag gerade nicht geht (nach einem Tipp darauf).
    static func sperrHinweis(_ tag: Int, _ sperre: TagSperre) -> String {
        switch sperre {
        case .belegt(.kurs): "Am \(voll(tag)) ist schon dein Kurs. Ein Tag hat einen festen Termin."
        case .belegt(.cardio): "Am \(voll(tag)) ist schon Cardio. Ein Tag hat einen festen Termin."
        case .belegt(.kraft): "Am \(voll(tag)) ist schon Krafttraining."
        case .letzterFreierTag: "Sechs feste Tage sind genug: ein Tag bleibt fürs Krafttraining frei."
        }
    }

    /// VoiceOver: "Montag, ausgewählt" (Tage als Schalter).
    static func tagLabel(_ tag: Int, ausgewaehlt: Bool) -> String {
        "\(voll(tag)), \(ausgewaehlt ? "ausgewählt" : "nicht ausgewählt")"
    }

    /// Lead von 2c3. Kein Rechenbeispiel ("A und B mit einem freien Tag
    /// dazwischen"): die Verteilung kommt vom Server.
    static func wochenLead(kurse: Bool, cardio: Bool) -> String {
        let gesetzt: String? = switch (kurse, cardio) {
        case (true, true): "Kurs und Cardio sind gesetzt."
        case (true, false): "Deine Kurse sind gesetzt."
        case (false, true): "Cardio ist gesetzt."
        case (false, false): nil
        }
        let rest = "Die Einheiten liegen auf den übrigen Tagen. Mit „Tauschen“ legst du eine auf einen freien Tag."
        return [gesetzt, rest].compactMap { $0 }.joined(separator: " ")
    }
}

// MARK: - Bausteine

/// Ja/Nein als Kachel (2c `.option`): gewaehlt = Akzentflaeche gedaempft mit
/// Akzentrand und gefuelltem Haken, sonst Flaeche mit leerem Kreis.
private struct WochenOption: View {
    let titel: String
    let zeile: String
    let istGewaehlt: Bool
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            HStack(spacing: DesignSystem.Spacing.s12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titel)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(DesignSystem.Color.text)
                    Text(zeile)
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ZStack {
                    if istGewaehlt {
                        Circle().fill(DesignSystem.Color.accent)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(DesignSystem.Color.onAccent)
                    } else {
                        Circle().strokeBorder(DesignSystem.Color.textFaint, lineWidth: 2)
                    }
                }
                .frame(width: 24, height: 24)
            }
            .padding(DesignSystem.Spacing.s16)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(istGewaehlt ? DesignSystem.Color.accentMuted : DesignSystem.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt)
                    .stroke(istGewaehlt ? DesignSystem.Color.accent : DesignSystem.Color.line, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(titel), \(zeile)")
        .accessibilityAddTraits(istGewaehlt ? [.isButton, .isSelected] : .isButton)
    }
}

/// Die sieben Tage als Schalter (2c/2c2 "AN WELCHEM TAG?"). Ein Tag der
/// anderen Art traegt deren Namen und laesst sich nicht waehlen; ein Tipp
/// darauf erklaert, warum (`TagSperre`).
private struct WochenTageRaster: View {
    @Binding var plan: PlanAntworten
    let art: Wochenart
    @Binding var hinweis: String?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { tag in knopf(tag) }
        }
    }

    private func tage() -> [Int] { art == .kurs ? plan.kursTage : plan.cardioTage }

    private func knopf(_ tag: Int) -> some View {
        let aktiv = tage().contains(tag)
        let sperre = plan.tagGesperrt(tag, fuer: art)
        let fremd: Wochenart? = if case .belegt(let andere) = sperre { andere } else { nil }
        return Button {
            if let abgelehnt = plan.tagUmschalten(tag, fuer: art) {
                hinweis = PlanWochenText.sperrHinweis(tag, abgelehnt)
            } else {
                hinweis = nil
            }
        } label: {
            VStack(spacing: 2) {
                Text(PlanWochenText.kurz(tag))
                    .font(.system(size: 14, weight: aktiv ? .heavy : .semibold))
                    .foregroundStyle(aktiv ? DesignSystem.Color.onAccent
                                     : (sperre == nil ? DesignSystem.Color.text : DesignSystem.Color.textFaint))
                if let fremd {
                    Text(fremd == .kurs ? "KURS" : "CARDIO")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(aktiv ? DesignSystem.Color.accent : SwiftUI.Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(aktiv ? SwiftUI.Color.clear : DesignSystem.Color.line, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PlanWochenText.tagLabel(tag, ausgewaehlt: aktiv))
        .accessibilityHint(sperre.map { PlanWochenText.sperrHinweis(tag, $0) } ?? "")
        .accessibilityAddTraits(aktiv ? [.isToggle, .isSelected] : .isToggle)
    }
}

/// Der graue Kasten unter den Tagen (2c `.hint`).
private struct WochenHinweis: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(DesignSystem.Color.text)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignSystem.Spacing.s16)
            .padding(.vertical, 14)
            .background(DesignSystem.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
    }
}

// MARK: - 2c Kurse

struct PlanKursSchritt: View {
    @Binding var plan: PlanAntworten
    @State private var hinweis: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
            VStack(spacing: 10) {
                WochenOption(titel: "Ja, ich besuche Kurse", zeile: "Sie zählen als Trainingstage",
                             istGewaehlt: plan.kursAntwort == true) {
                    plan.kurseBeantworten(true)
                }
                WochenOption(titel: "Nein, nur freies Training", zeile: "Du kannst Kurse später im Plan ergänzen",
                             istGewaehlt: plan.kursAntwort == false) {
                    plan.kurseBeantworten(false)
                    hinweis = nil
                }
            }
            if plan.kursAntwort == true {
                OnboardingAbschnitt(label: "An welchem Tag?") {
                    WochenTageRaster(plan: $plan, art: .kurs, hinweis: $hinweis)
                }
                if let text = hinweis ?? PlanWochenText.kursHinweis(plan.kursTage) {
                    WochenHinweis(text: text)
                }
            }
        }
    }
}

// MARK: - 2c2 Cardio

struct PlanCardioSchritt: View {
    @Binding var plan: PlanAntworten
    @State private var hinweis: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
            VStack(spacing: 10) {
                WochenOption(titel: "Ja, regelmäßig", zeile: "Ich trage es ein und hake es ab",
                             istGewaehlt: plan.cardioAntwort == true) {
                    plan.cardioBeantworten(true)
                }
                WochenOption(titel: "Nein, nur Gym", zeile: "Später im Plan ergänzbar",
                             istGewaehlt: plan.cardioAntwort == false) {
                    plan.cardioBeantworten(false)
                    hinweis = nil
                }
            }
            if plan.cardioAntwort == true {
                OnboardingAbschnitt(label: "Was machst du?") {
                    Fliesslayout(abstand: DesignSystem.Spacing.s8) {
                        ForEach(PlanAuswahl.cardioArten, id: \.code) { art in
                            let istAktiv = plan.cardioArten.contains(art.code)
                            Button {
                                plan.cardioArtUmschalten(art.code)
                            } label: {
                                Chip(text: art.text, isActive: istAktiv, innenabstand: DesignSystem.Spacing.s16, gefuellt: true)
                                    .fixedSize()
                            }
                            .buttonStyle(PressButtonStyle())
                            .accessibilityLabel(PlanWochenTextArt.label(art.text, ausgewaehlt: istAktiv))
                            .accessibilityAddTraits(istAktiv ? [.isToggle, .isSelected] : .isToggle)
                        }
                    }
                }
                OnboardingAbschnitt(label: "An welchem Tag?") {
                    WochenTageRaster(plan: $plan, art: .cardio, hinweis: $hinweis)
                }
                if let text = hinweis ?? PlanWochenText.cardioHinweis(plan.cardioTage) {
                    WochenHinweis(text: text)
                }
            }
        }
    }
}

private enum PlanWochenTextArt {
    static func label(_ name: String, ausgewaehlt: Bool) -> String {
        "\(name), \(ausgewaehlt ? "ausgewählt" : "nicht ausgewählt")"
    }
}

// MARK: - 2c3 Deine Woche

/// Zeigt das Raster eines Vorschlags vom Server (`createPlan` beim Betreten;
/// der Flow hat Kurs- und Cardio-Tage davor geschrieben). Die App verteilt
/// nichts selbst: ohne Tausch steht hier genau `plan.wochenraster`, nach
/// einem Tausch dieselbe Anzeige-Regel wie im Plan-Tab
/// (`PlanAntworten.wochenAnzeige`). Uebernommen wird erst in der Vorschau;
/// deren neuer Vorschlag traegt den Tausch dann als `kraftTage`.
///
/// Jedes Betreten ist eine neue Identitaet (`.id(schritt)` im Flow) und holt
/// einen neuen Vorschlag -- nach geaenderten Antworten steht kein altes
/// Raster mehr da.
struct PlanWochenSchritt: View {
    let apiClient: APIClient
    let studioId: String?
    @Binding var plan: PlanAntworten
    /// Nur Vorschau und Sichtpruefung: ein fester Vorschlag ohne Netzaufruf.
    var start: Zustand? = nil

    enum Zustand: Equatable {
        case laedt
        case vorschlag(Trainingsplan)
        case fehler
    }

    @State private var zustand: Zustand = .laedt
    /// Der Krafttag, der gerade getauscht wird; nil = kein Tausch offen.
    @State private var tauschVon: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            switch zustand {
            case .laedt:
                ProgressView()
                    .tint(DesignSystem.Color.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .accessibilityLabel("Woche wird geplant")
            case .fehler:
                // Die Vorschau danach erklaert Sonderfaelle (4.1/4.2) selbst.
                InlineBanner(tone: .muted, message: "Die Woche zeigen wir dir, sobald der Plan steht. Weiter geht es trotzdem.")
            case .vorschlag(let vorschlag):
                woche(vorschlag)
            }
        }
        .task {
            if let start {
                zustand = start
                return
            }
            await vorschlagHolen()
        }
    }

    private func vorschlagHolen() async {
        zustand = .laedt
        do throws(APIError) {
            zustand = .vorschlag(try await apiClient.createPlan(studioId: studioId))
        } catch {
            zustand = .fehler
        }
    }

    @ViewBuilder
    private func woche(_ vorschlag: Trainingsplan) -> some View {
        let anzeige = plan.wochenAnzeige(raster: vorschlag.wochenraster, einheiten: vorschlag.einheiten.map(\.key))
        let freie = (1...7).filter { tag in !anzeige.contains { $0.tag == tag } }
        if vorschlag.gruende.contains("kraft_tage_auf_eins"), let satz = PlanWarumText.grundSatz("kraft_tage_auf_eins") {
            InlineBanner(tone: .muted, message: satz)
        }
        if let tauschVon {
            Text("Wähle einen freien Tag für \(PlanWochenText.voll(tauschVon)).")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.accent)
                .accessibilityAddTraits(.isStaticText)
        }
        VStack(spacing: DesignSystem.Spacing.s8) {
            ForEach(1...7, id: \.self) { tag in
                zeile(tag: tag, plaetze: anzeige.filter { $0.tag == tag }, kannTauschen: !freie.isEmpty,
                      raster: vorschlag.wochenraster)
            }
        }
    }

    @ViewBuilder
    private func zeile(tag: Int, plaetze: [Rasterplatz], kannTauschen: Bool, raster: [Rasterplatz]) -> some View {
        if let platz = plaetze.first {
            switch platz.art {
            case .kraft:
                kraftZeile(tag: tag, key: platz.einheitKey, kannTauschen: kannTauschen)
            case .kurs:
                festeZeile(tag: tag, titel: "Kurs", zeile: nil) {
                    Text("K")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(DesignSystem.Color.text)
                        .frame(width: 36, height: 36)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(DesignSystem.Color.textMuted, lineWidth: 2))
                }
            case .cardio:
                festeZeile(tag: tag, titel: "Cardio-Einheit",
                           zeile: plan.cardioArten.isEmpty ? nil : CardioArtName.zeile(plan.cardioArten)) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.text)
                        .frame(width: 36, height: 36)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(DesignSystem.Color.textFaint, lineWidth: 1))
                }
            }
        } else {
            freieZeile(tag: tag, raster: raster)
        }
    }

    private func tagSpalte(_ tag: Int, farbe: SwiftUI.Color) -> some View {
        Text(PlanWochenText.kurz(tag))
            .font(.system(size: 15, weight: .heavy))
            .foregroundStyle(farbe)
            .frame(width: 28, alignment: .leading)
    }

    private func kraftZeile(tag: Int, key: String?, kannTauschen: Bool) -> some View {
        let name = key.map(EinheitName.text) ?? "Krafttraining"
        let wirdGetauscht = tauschVon == tag
        return HStack(spacing: DesignSystem.Spacing.s12) {
            tagSpalte(tag, farbe: DesignSystem.Color.text)
            Text(key.map(EinheitKuerzel.text) ?? "K")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(DesignSystem.Color.onAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 36, height: 36)
                .background(DesignSystem.Color.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            Text(name)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DesignSystem.Color.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            if kannTauschen {
                Button(wirdGetauscht ? "Abbrechen" : "Tauschen") {
                    tauschVon = wirdGetauscht ? nil : tag
                }
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(DesignSystem.Color.accent)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .buttonStyle(PressButtonStyle())
                .accessibilityLabel(wirdGetauscht ? "Tauschen abbrechen" : "\(name) am \(PlanWochenText.voll(tag)) tauschen")
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.s16)
        .frame(minHeight: 60)
        .background(DesignSystem.Color.accentMuted)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                .stroke(wirdGetauscht ? DesignSystem.Color.accent : SwiftUI.Color.clear, lineWidth: 1.5)
        )
        .accessibilityElement(children: .contain)
    }

    private func festeZeile<Marke: View>(
        tag: Int, titel: String, zeile: String?, @ViewBuilder marke: () -> Marke
    ) -> some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            tagSpalte(tag, farbe: DesignSystem.Color.textMuted)
            marke().accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(titel)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.text)
                if let zeile {
                    Text(zeile)
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("Fest")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
        .padding(.horizontal, DesignSystem.Spacing.s16)
        .frame(minHeight: 60)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func freieZeile(tag: Int, raster: [Rasterplatz]) -> some View {
        let inhalt = HStack(spacing: DesignSystem.Spacing.s12) {
            tagSpalte(tag, farbe: DesignSystem.Color.textMuted)
            Text("Frei")
                .font(.system(size: 15))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            if tauschVon != nil {
                Text("Hierhin")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(DesignSystem.Color.accent)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.s16)
        .frame(maxWidth: .infinity, minHeight: 60)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                .stroke(tauschVon != nil ? DesignSystem.Color.accent : DesignSystem.Color.line,
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .contentShape(Rectangle())

        if let von = tauschVon {
            Button {
                plan.kraftTagTauschen(von: von, nach: tag, raster: raster)
                tauschVon = nil
            } label: { inhalt }
                .buttonStyle(PressButtonStyle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(PlanWochenText.voll(tag)), frei")
                .accessibilityHint("Legt das Training vom \(PlanWochenText.voll(von)) hierhin")
        } else {
            inhalt
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(PlanWochenText.voll(tag)), frei")
        }
    }
}

/// Die Woche in einer Zeile fuer die Vorschau 1.4: Tag und Marke, wie der
/// Server das Raster vorschlaegt.
struct PlanWochenZeile: View {
    let raster: [Rasterplatz]

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.s4) {
            ForEach(1...7, id: \.self) { tag in
                let platz = raster.first { $0.tag == tag }
                VStack(spacing: DesignSystem.Spacing.s4) {
                    Text(PlanWochenText.kurz(tag))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                    Text(marke(platz))
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(platz?.art == .kraft ? DesignSystem.Color.onAccent : DesignSystem.Color.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background(platz?.art == .kraft ? DesignSystem.Color.accent : DesignSystem.Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(PlanWochenText.voll(tag)), \(beschreibung(platz))")
            }
        }
    }

    private func marke(_ platz: Rasterplatz?) -> String {
        guard let platz else { return "–" }
        switch platz.art {
        case .kraft: return platz.einheitKey.map(EinheitKuerzel.text) ?? "K"
        case .kurs: return "Kurs"
        case .cardio: return "Cardio"
        }
    }

    private func beschreibung(_ platz: Rasterplatz?) -> String {
        guard let platz else { return "frei" }
        switch platz.art {
        case .kraft: return platz.einheitKey.map(EinheitName.text) ?? "Krafttraining"
        case .kurs: return "Kurs"
        case .cardio: return "Cardio"
        }
    }
}
