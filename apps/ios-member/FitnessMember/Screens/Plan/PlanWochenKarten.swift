import SwiftUI

/// Die Texte der Wochenkarten (Spec P2 §3 Punkt 4/5, Leinwand "Gewählt ·
/// Kalender B + Karten A") -- rein, damit sie ohne UI pruefbar bleiben.
enum PlanWochenKarten {
    /// Woher ein automatischer Cardio-Haken kam: nach einer Kraft-Einheit
    /// (`nil` = freies Training) oder aus einem reinen Cardio-Training an
    /// einem Geraet.
    enum CardioHerkunft: Equatable {
        case nachKraft(einheitKey: String?)
        case geraet(String)
    }

    /// "Kraft B · Brust, Trizeps", ohne Muskelnamen "Kraft B"; "Freies Training";
    /// "Cardio · 30 min" (offen) bzw. "Cardio" (erledigt); der Kursname.
    static func titel(_ karte: WochenKarte, namen: EinheitNamen) -> String {
        switch karte.art {
        case .kraft(let key):
            guard let key else { return "Freies Training" }
            let kurz = kraftKurz(key)
            let name = namen.name(key)
            return namen.istMechanisch(key) ? kurz : "\(kurz) · \(name)"
        case .cardio:
            guard karte.erledigtAm == nil else { return "Cardio" }
            return karte.minuten.map { "Cardio · \($0) min" } ?? "Cardio"
        case .kurs(let kurs):
            return kurs.name
        }
    }

    /// Spec §3 Punkt 4/5: "erledigt Mo, 9. · 58 min", "7 Übungen · ca. 63 min",
    /// "nach Kraft B · 32 min", "abgehakt Di, 10.", "zählt auch nach dem
    /// Krafttraining", "18:00 · gebucht".
    static func untertitel(
        _ karte: WochenKarte, einheiten: [TrainingsplanEinheit], kalender: Calendar,
        herkunft: CardioHerkunft? = nil
    ) -> String {
        switch karte.art {
        case .kraft(let key):
            if let am = karte.erledigtAm {
                return mitMinuten("erledigt \(tagKurz(am, kalender: kalender))", karte.minuten)
            }
            guard let einheit = einheiten.first(where: { $0.key == key }) else { return "" }
            let n = einheit.positionen.count
            var teile = ["\(n) \(n == 1 ? "Übung" : "Übungen")"]
            if let min = einheit.geschaetzteMinuten { teile.append("ca. \(Int(min.rounded())) min") }
            return teile.joined(separator: " · ")
        case .cardio:
            guard let am = karte.erledigtAm else { return "zählt auch nach dem Krafttraining" }
            if case .hand = karte.quelle { return "abgehakt \(tagKurz(am, kalender: kalender))" }
            let vorn: String? = switch herkunft {
            case .nachKraft(let key?): "nach \(kraftKurz(key))"
            case .nachKraft(nil): "nach freiem Training"
            case .geraet(let name): name
            case nil: nil
            }
            guard let minuten = karte.minuten else { return vorn ?? "" }
            return vorn.map { "\($0) · \(minuten) min" } ?? "\(minuten) min"
        case .kurs(let kurs):
            guard let start = Zeitpunkt.parse(kurs.startsAt) else { return "gebucht" }
            return "\(uhrzeit(start, kalender: kalender)) · gebucht"
        }
    }

    /// Die Herkunft eines Cardio-Hakens aus der Sitzung: eine gezaehlte
    /// Plan-Einheit, sonst ein Training mit Kraftsatz (frei), sonst das erste
    /// Cardio-Geraet.
    static func herkunft(
        sitzungId: String, sitzungen: [SessionSummary], erledigt: [ErledigteEinheit]
    ) -> CardioHerkunft? {
        if let key = erledigt.first(where: { $0.sessionId == sitzungId })?.einheitKey {
            return .nachKraft(einheitKey: key)
        }
        guard let sitzung = sitzungen.first(where: { $0.id == sitzungId }) else { return nil }
        if sitzung.blocks.contains(where: { $0.sets.contains { $0.cardio == nil } }) {
            return .nachKraft(einheitKey: nil)
        }
        return sitzung.blocks.first { $0.sets.contains { $0.cardio != nil } }.map { .geraet($0.machineLabel) }
    }

    /// Der ruhige Satz einer kuenftigen Woche: "Diese Woche: 2× Kraft, 1× Cardio".
    static func ausblick(_ ziel: Wochenziel) -> String {
        var teile = ["\(ziel.kraft)× Kraft"]
        if ziel.cardio > 0 { teile.append("\(ziel.cardio)× Cardio") }
        return "Diese Woche: " + teile.joined(separator: ", ")
    }

    /// "Kraft B", "Kraft OK A".
    static func kraftKurz(_ key: String) -> String {
        "Kraft \(EinheitKuerzel.text(key))"
    }

    /// "Mo, 9." -- feste Kurznamen, unabhaengig von Locale-Eigenheiten.
    static func tagKurz(_ tag: Date, kalender: Calendar) -> String {
        let kurz = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
        let index = (kalender.component(.weekday, from: tag) - 1 + 7) % 7
        return "\(kurz[index]), \(kalender.component(.day, from: tag))."
    }

    /// "DO" fuer die Datumskachel der Kurse.
    static func wochentagKachel(_ tag: Date, kalender: Calendar) -> String {
        tagKurz(tag, kalender: kalender).prefix(2).uppercased()
    }

    private static func uhrzeit(_ zeitpunkt: Date, kalender: Calendar) -> String {
        let c = kalender.dateComponents([.hour, .minute], from: zeitpunkt)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private static func mitMinuten(_ text: String, _ minuten: Int?) -> String {
        minuten.map { "\(text) · \($0) min" } ?? text
    }
}

// MARK: - Karte

/// Eine Karte der Woche (Leinwand "Karten A"): Kachel links, Titel und
/// Untertitel, rechts Haken, leerer Kreis oder ein Knopf.
struct PlanWochenKarte: View {
    enum Kachel {
        case muskeln([String: TrainingsProfil.Stufe])
        case hantel
        case cardio
        /// Datumskachel eines Kurses: gestrichelt solange kuenftig, mit Haken nach Beginn.
        case kurs(wochentag: String, tag: Int, begonnen: Bool)
    }

    enum Rechts {
        case haken
        case offen
        case keins
        /// Ein Knopf ("Abhaken", "Rückgängig"); die Aktion liefert einen Fehlertext oder nil.
        case knopf(titel: String, hinweis: String, aktion: () async -> String?)
    }

    let kachel: Kachel
    var kopf: String?
    let titel: String
    let untertitel: String
    let rechts: Rechts
    /// Akzentrand: die naechste offene Kraft-Karte.
    var hervorgehoben = false
    var geschlecht: Geschlecht?
    var beiTipp: (() -> Void)?
    var tippHinweis: String?

    @State private var laeuft = false
    @State private var fehler: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            HStack(spacing: DesignSystem.Spacing.s12) {
                if let beiTipp {
                    Button(action: beiTipp) { inhalt.contentShape(Rectangle()) }
                        .buttonStyle(PressButtonStyle())
                        .accessibilityHint(tippHinweis ?? "")
                } else {
                    inhalt
                }
                rechtsTeil
            }
            if let fehler {
                Text(fehler)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.danger)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.s12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt)
                .strokeBorder(hervorgehoben ? DesignSystem.Color.accent : .clear, lineWidth: 1.5))
    }

    private var inhalt: some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            kachelAnsicht
            VStack(alignment: .leading, spacing: 2) {
                if let kopf {
                    Text(kopf)
                        .font(DesignSystem.Typography.label)
                        .tracking(1.5)
                        .foregroundStyle(DesignSystem.Color.accent)
                }
                Text(titel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
                    .fixedSize(horizontal: false, vertical: true)
                if !untertitel.isEmpty {
                    Text(untertitel)
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(beiTipp == nil ? [] : .isButton)
    }

    @ViewBuilder
    private var kachelAnsicht: some View {
        let form = RoundedRectangle(cornerRadius: DesignSystem.Spacing.s12)
        switch kachel {
        case .muskeln(let stufen):
            MuskelFigur(farben: MuskelFarben.farben(stufen: stufen), geschlecht: geschlecht, kompakt: true)
                .padding(DesignSystem.Spacing.s4)
                .frame(width: 52, height: 52)
                .background(DesignSystem.Color.surfaceRaised, in: form)
                .accessibilityHidden(true)
        case .hantel:
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.text)
                .frame(width: 52, height: 52)
                .background(DesignSystem.Color.surfaceRaised, in: form)
                .accessibilityHidden(true)
        case .cardio:
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.accent)
                .frame(width: 52, height: 52)
                .background(DesignSystem.Color.surfaceRaised, in: form)
                .accessibilityHidden(true)
        case .kurs(let wochentag, let tag, let begonnen):
            VStack(spacing: 0) {
                Text(wochentag)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                Text("\(tag)")
                    .font(.system(size: 18, weight: .bold).monospacedDigit())
                    .foregroundStyle(DesignSystem.Color.text)
            }
            .frame(width: 52, height: 52)
            .overlay {
                if begonnen {
                    form.strokeBorder(DesignSystem.Color.accent, lineWidth: 2)
                } else {
                    form.strokeBorder(DesignSystem.Color.textFaint, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                }
            }
            .overlay(alignment: .topTrailing) {
                if begonnen {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Color.accent)
                        .background(DesignSystem.Color.surface, in: Circle())
                        .offset(x: 5, y: -5)
                }
            }
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var rechtsTeil: some View {
        switch rechts {
        case .haken:
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(DesignSystem.Color.onAccent)
                .frame(width: 30, height: 30)
                .background(DesignSystem.Color.accent, in: Circle())
                .accessibilityLabel("Erledigt")
        case .offen:
            Circle()
                .strokeBorder(DesignSystem.Color.line, lineWidth: 2)
                .frame(width: 30, height: 30)
                .accessibilityLabel("Offen")
        case .keins:
            EmptyView()
        case .knopf(let titel, let hinweis, let aktion):
            Button {
                laeuft = true
                Task {
                    fehler = await aktion()
                    laeuft = false
                }
            } label: {
                Text(titel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
                    .padding(.horizontal, DesignSystem.Spacing.s12)
                    .frame(minHeight: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(DesignSystem.Color.line, lineWidth: 1)
                            .frame(minHeight: 36))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressButtonStyle())
            .disabled(laeuft)
            .accessibilityHint(hinweis)
        }
    }
}

// MARK: - Tageszelle

/// Die Tageszelle des Wochenstreifens und des Monats (Leinwand "Kalender B"):
/// ein Tag mit Geleistetem traegt das Symbol im Akzentring (Kraft > Kurs >
/// Cardio, bei mehreren Arten ein kleiner Punkt); heute ist weiss gefuellt;
/// ein gebuchter, noch nicht begonnener Kurs hat einen gestrichelten Ring;
/// sonst nur die Zahl. Keine Versaeumnis-Marke.
struct PlanTagZelle: View {
    let nummer: Int
    let marken: [TagMarke]
    let istHeute: Bool
    var istGewaehlt = false
    /// Nachbarmonat im Monatsgitter: gedimmt.
    var gedeckt = false

    static func symbol(_ marke: TagMarke) -> String? {
        switch marke {
        case .kraft: "dumbbell.fill"
        case .kurs: "person.3.fill"
        case .cardio: "waveform.path.ecg"
        case .kursGebucht: nil
        }
    }

    private var geleistet: [TagMarke] { marken.filter { $0 != .kursGebucht } }

    var body: some View {
        let erste = geleistet.first
        ZStack {
            if istHeute {
                Circle()
                    .fill(DesignSystem.Color.text)
                    .padding(erste == nil ? 0 : DesignSystem.Spacing.s4)
            } else if istGewaehlt {
                Circle().fill(DesignSystem.Color.surfaceRaised)
            }
            if let erste, let symbol = Self.symbol(erste) {
                Image(systemName: symbol)
                    .font(.system(size: erste == .kurs ? 12 : 15, weight: .semibold))
                    .foregroundStyle(istHeute ? DesignSystem.Color.bg : DesignSystem.Color.text)
            } else {
                Text("\(nummer)")
                    .font(.system(size: 16, weight: .bold).monospacedDigit())
                    .foregroundStyle(
                        istHeute ? DesignSystem.Color.bg
                            : marken.contains(.kursGebucht) ? DesignSystem.Color.text : DesignSystem.Color.textMuted)
            }
        }
        .frame(width: 40, height: 40)
        .overlay {
            if erste != nil {
                Circle().strokeBorder(DesignSystem.Color.accent, lineWidth: 2)
            } else if marken.contains(.kursGebucht) && !istHeute {
                Circle().strokeBorder(DesignSystem.Color.textFaint, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // Mehr als eine Art: ein kleiner Punkt.
            if geleistet.count > 1 || (erste != nil && marken.contains(.kursGebucht)) {
                Circle()
                    .fill(DesignSystem.Color.accent)
                    .frame(width: 7, height: 7)
                    .overlay(Circle().strokeBorder(DesignSystem.Color.bg, lineWidth: 1.5))
                    .offset(x: 1, y: 1)
            }
        }
        .opacity(gedeckt ? 0.4 : 1)
        .accessibilityHidden(true)
    }

    /// "Montag, 9. Heute. Kraft, Kurs." fuer VoiceOver.
    static func label(wochentag: String, nummer: Int, istHeute: Bool, marken: [TagMarke]) -> String {
        var teile = ["\(wochentag), \(nummer)."]
        if istHeute { teile.append("Heute.") }
        let namen = marken.map { marke -> String in
            switch marke {
            case .kraft: "Kraft"
            case .kurs: "Kurs"
            case .kursGebucht: "Kurs gebucht"
            case .cardio: "Cardio"
            }
        }
        if !namen.isEmpty { teile.append(namen.joined(separator: ", ") + ".") }
        return teile.joined(separator: " ")
    }
}
