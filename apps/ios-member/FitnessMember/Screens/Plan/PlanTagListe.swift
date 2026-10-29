import SwiftUI

/// Ein Eintrag der Tagesliste, mit allem aufgeloest, was die Zeile braucht:
/// der Kurs als voller Termin (fuer `KursTerminZeile` und das Kursdetail),
/// die Einheit mit ihrem Planinhalt.
enum PlanTagEintrag: Identifiable {
    case einheit(TrainingsplanEinheit, erledigt: Bool)
    case kurs(CourseWeekSession)
    case cardio(arten: [String], erledigt: Bool)

    var id: String {
        switch self {
        case .einheit(let e, _): "einheit-\(e.key)"
        case .kurs(let k): "kurs-\(k.sessionId)"
        case .cardio: "cardio"
        }
    }
}

/// Der kurze Schluessel im Kaestchen: "A", "OK A".
enum EinheitKuerzel {
    static func text(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ")
    }

    /// "6 Übungen · ca. 60 Min"
    static func untertitel(_ einheit: TrainingsplanEinheit) -> String {
        let n = einheit.positionen.count
        var teile = ["\(n) \(n == 1 ? "Übung" : "Übungen")"]
        if let min = einheit.geschaetzteMinuten { teile.append("ca. \(Int(min.rounded())) Min") }
        return teile.joined(separator: " · ")
    }
}

/// Die Liste des gewaehlten Tages (Leinwand 2a, 2f, 2g, 2i): Ueberschrift,
/// Eintraege, bei leerem Tag ein Satz und "Als nächstes".
struct PlanTagListe: View {
    let ueberschrift: String
    let istHeute: Bool
    /// Heute oder vergangen -- nur dann laesst sich Cardio abhaken (der Server
    /// lehnt die Zukunft ab).
    let darfAbhaken: Bool
    let eintraege: [PlanTagEintrag]
    /// Die Einheit, die im Training-Tab als naechste startet.
    let naechsteEinheitKey: String?
    let alsNaechstes: [(tag: String, eintrag: PlanTagEintrag)]
    let kursZeile: (CourseWeekSession) -> KursTerminZeile
    let beiEinheit: (String) -> Void
    let beiStart: () -> Void
    /// Liefert einen Fehlertext oder nil.
    let beiCardio: (_ erledigt: Bool) async -> String?

    @State private var cardioLaeuft = false
    @State private var cardioFehler: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text(ueberschrift.uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .accessibilityAddTraits(.isHeader)

            if eintraege.isEmpty {
                leer
            } else {
                ForEach(eintraege) { eintrag in
                    zeile(eintrag)
                }
            }
        }
    }

    @ViewBuilder
    private func zeile(_ eintrag: PlanTagEintrag) -> some View {
        switch eintrag {
        case .einheit(let einheit, let erledigt):
            einheitKarte(einheit, erledigt: erledigt)
        case .kurs(let termin):
            kursZeile(termin)
        case .cardio(let arten, let erledigt):
            cardioKarte(arten: arten, erledigt: erledigt)
        }
    }

    // MARK: - Einheit

    private func einheitKarte(_ einheit: TrainingsplanEinheit, erledigt: Bool) -> some View {
        let zeigtStart = istHeute && !erledigt && einheit.key == naechsteEinheitKey
        return HStack(spacing: DesignSystem.Spacing.s12) {
            Button { beiEinheit(einheit.key) } label: {
                HStack(spacing: DesignSystem.Spacing.s12) {
                    PlanKuerzelKaestchen(text: EinheitKuerzel.text(einheit.key), gefuellt: true)
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                        Text(EinheitName.text(einheit.key))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(DesignSystem.Color.text)
                        Text(erledigt ? "Erledigt" : "Flexibel · \(EinheitKuerzel.untertitel(einheit))")
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .foregroundStyle(DesignSystem.Color.textMuted)
                    }
                    Spacer(minLength: 0)
                    if !zeigtStart {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DesignSystem.Color.textFaint)
                    }
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityElement(children: .combine)
            .accessibilityHint("Zeigt die Übungen der Einheit")

            if zeigtStart {
                // Die eine Akzentflaeche des Screens: das, was heute dran ist.
                Button { beiStart() } label: {
                    Text("Start")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(DesignSystem.Color.onAccent)
                        .padding(.horizontal, DesignSystem.Spacing.s16)
                        .frame(minHeight: 44)
                        .background(DesignSystem.Color.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(PressButtonStyle())
                .accessibilityLabel("\(EinheitName.text(einheit.key)) starten")
                .accessibilityHint("Öffnet das Training")
            }
        }
        .padding(DesignSystem.Spacing.s16)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(zeigtStart ? DesignSystem.Color.accent : .clear, lineWidth: 1.5))
    }

    // MARK: - Cardio (Leinwand 2i)

    private func cardioKarte(arten: [String], erledigt: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            HStack(spacing: DesignSystem.Spacing.s12) {
                PlanCardioKaestchen()
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    Text("Cardio-Einheit")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DesignSystem.Color.text)
                    Text(CardioArtName.zeile(arten))
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                Spacer(minLength: 0)
                if erledigt {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(DesignSystem.Color.accent)
                        .accessibilityLabel("Erledigt")
                }
            }
            .accessibilityElement(children: .combine)

            if darfAbhaken {
                if erledigt {
                    Button { cardioSetzen(false) } label: {
                        Text("Nicht erledigt")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(DesignSystem.Color.textMuted)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressButtonStyle())
                    .disabled(cardioLaeuft)
                    .accessibilityHint("Nimmt das Abhaken zurück")
                } else {
                    SecondaryButton(title: "Als erledigt markieren") { cardioSetzen(true) }
                        .disabled(cardioLaeuft)
                }
            }
            if let cardioFehler {
                Text(cardioFehler)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.danger)
            }
            Text("Fester Termin aus deinem Wochenplan. Umfang und Tempo kommen später.")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignSystem.Spacing.s16)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
    }

    private func cardioSetzen(_ erledigt: Bool) {
        cardioLaeuft = true
        Task {
            cardioFehler = await beiCardio(erledigt)
            cardioLaeuft = false
        }
    }

    // MARK: - Leer und "Als nächstes"

    private var leer: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(istHeute ? "Heute nichts geplant" : "Nichts geplant")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
                Text("Willst du spontan trainieren, geht das jederzeit im Tab Training.")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.s16)
            .accessibilityElement(children: .combine)

            if !alsNaechstes.isEmpty {
                Text("ALS NÄCHSTES")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(alsNaechstes.enumerated()), id: \.offset) { _, naechster in
                    naechsteZeile(naechster.eintrag, tag: naechster.tag)
                }
            }
        }
    }

    @ViewBuilder
    private func naechsteZeile(_ eintrag: PlanTagEintrag, tag: String) -> some View {
        switch eintrag {
        case .einheit(let einheit, _):
            Button { beiEinheit(einheit.key) } label: {
                naechsteInhalt(
                    kaestchen: AnyView(PlanKuerzelKaestchen(text: EinheitKuerzel.text(einheit.key), gefuellt: false)),
                    titel: EinheitName.text(einheit.key), tag: tag)
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityHint("Zeigt die Übungen der Einheit")
        case .kurs(let termin):
            naechsteInhalt(kaestchen: AnyView(PlanKursKaestchen()), titel: termin.name, tag: tag)
        case .cardio:
            naechsteInhalt(kaestchen: AnyView(PlanCardioKaestchen()), titel: "Cardio-Einheit", tag: tag)
        }
    }

    private func naechsteInhalt(kaestchen: AnyView, titel: String, tag: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            kaestchen
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(titel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
                Text(tag)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Spacing.s12)
        .frame(minHeight: 44)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityElement(children: .combine)
    }
}

/// Das Kaestchen mit dem Einheitenkuerzel: gefuellt (accentMuted) fuer den
/// gewaehlten Tag, sonst nur Kontur.
struct PlanKuerzelKaestchen: View {
    let text: String
    let gefuellt: Bool

    var body: some View {
        Text(text)
            .font(.system(size: text.count > 1 ? 13 : 18, weight: .black))
            .foregroundStyle(gefuellt ? DesignSystem.Color.accent : DesignSystem.Color.text)
            .frame(width: 40, height: 40)
            .background(gefuellt ? DesignSystem.Color.accentMuted : DesignSystem.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
    }
}

struct PlanCardioKaestchen: View {
    var body: some View {
        Image(systemName: "waveform.path.ecg")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(DesignSystem.Color.text)
            .frame(width: 40, height: 40)
            .background(DesignSystem.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
    }
}

struct PlanKursKaestchen: View {
    var body: some View {
        Image(systemName: "person.3")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(DesignSystem.Color.textMuted)
            .frame(width: 40, height: 40)
            .background(DesignSystem.Color.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
    }
}

/// Die Marken unter einem Tag im Streifen und in der Legende: Punkt (Einheit),
/// Ring (Kurs), Raute (Cardio) -- Formen, nicht nur Farben.
struct PlanTagMarke: View {
    enum Art: CaseIterable { case einheit, kurs, cardio }
    let art: Art
    /// Gedeckt fuer Erledigtes.
    var gedeckt = false

    var body: some View {
        Group {
            switch art {
            case .einheit:
                Circle().fill(gedeckt ? DesignSystem.Color.textFaint : DesignSystem.Color.accent)
            case .kurs:
                Circle().strokeBorder(DesignSystem.Color.textMuted, lineWidth: 2)
            case .cardio:
                Rectangle()
                    .fill(gedeckt ? DesignSystem.Color.textFaint : DesignSystem.Color.text)
                    .frame(width: 6, height: 6)
                    .rotationEffect(.degrees(45))
            }
        }
        .frame(width: 8, height: 8)
    }
}
