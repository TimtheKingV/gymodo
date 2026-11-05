import SwiftUI

/// Ein Eintrag der Tagesliste, mit allem aufgeloest, was die Zeile braucht:
/// der Kurs als voller Termin (fuer `KursTerminZeile` und das Kursdetail),
/// die Einheit mit ihrem Planinhalt.
enum PlanTagEintrag: Identifiable {
    case einheit(TrainingsplanEinheit, zustand: TerminZustand)
    case kurs(CourseWeekSession)
    case cardio(arten: [String], zustand: TerminZustand)

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
/// die Trainings des Tages, die Eintraege, bei leerem Tag ein Satz und
/// "Als nächstes".
struct PlanTagListe: View {
    let einheitNamen: EinheitNamen
    let muskeln: [String: [GeraetMuskel]]
    let geschlecht: Geschlecht?
    let kalender: Calendar
    let ueberschrift: String
    let istHeute: Bool
    /// Heute oder vergangen -- nur dann laesst sich Cardio abhaken (der Server
    /// lehnt die Zukunft ab).
    let darfAbhaken: Bool
    let eintraege: [PlanTagEintrag]
    /// Die abgeschlossenen Trainings des Tages (Vergangenheit und heute),
    /// gefaltet wie auf Home (`HomeZeilen.trainingskarten`).
    var trainings: [Trainingskarte] = []
    /// Die Einheit, die im Training-Tab als naechste startet.
    let naechsteEinheitKey: String?
    let alsNaechstes: [(tag: String, eintrag: PlanTagEintrag)]
    let kursZeile: (CourseWeekSession) -> KursTerminZeile
    let beiEinheit: (String) -> Void
    /// Session-Id des aeltesten Teils einer Trainingskarte -> Training-Detail.
    var beiTraining: (String) -> Void = { _ in }
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

            if eintraege.isEmpty && trainings.isEmpty {
                leer
            } else {
                // Erledigtes zuerst, darunter, was (noch) ansteht oder verpasst ist.
                ForEach(trainings) { karte in
                    EinheitKarte(
                        modell: .training(karte, muskeln: muskeln), geschlecht: geschlecht,
                        kalender: kalender, beiTipp: { beiTraining(karte.id) },
                        hinweis: "Zeigt das Training")
                }
                ForEach(eintraege) { eintrag in
                    zeile(eintrag)
                }
            }
        }
    }

    @ViewBuilder
    private func zeile(_ eintrag: PlanTagEintrag) -> some View {
        switch eintrag {
        case .einheit(let einheit, let zustand):
            einheitKarte(einheit, zustand: zustand)
        case .kurs(let termin):
            kursZeile(termin)
        case .cardio(let arten, let zustand):
            cardioKarte(arten: arten, zustand: zustand)
        }
    }

    // MARK: - Einheit

    private func einheitKarte(_ einheit: TrainingsplanEinheit, zustand: TerminZustand) -> some View {
        var offen = false
        if case .geplant = zustand { offen = true }
        let zeigtStart = istHeute && offen && einheit.key == naechsteEinheitKey
        return EinheitKarte(
            modell: .einheit(
                einheit, namen: einheitNamen, muskeln: muskeln, tag: nil, zustand: zustand),
            geschlecht: geschlecht, kalender: kalender,
            beiTipp: { beiEinheit(einheit.key) },
            hinweis: "Zeigt die Übungen der Einheit",
            // Die eine Akzentflaeche des Screens: das, was heute dran ist.
            aktion: zeigtStart
                ? (titel: "Training starten", label: "\(einheitNamen.name(einheit.key)) starten",
                   hinweis: "Öffnet das Training", ausloesen: beiStart)
                : nil)
    }

    // MARK: - Cardio (Leinwand 2i)

    private func cardioKarte(arten: [String], zustand: TerminZustand) -> some View {
        let erledigt = zustand == .erledigt
        var verpasst = false
        if case .verpasst = zustand { verpasst = true }
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            HStack(spacing: DesignSystem.Spacing.s12) {
                PlanCardioKaestchen()
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    Text("Cardio-Einheit")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DesignSystem.Color.text)
                    Text(CardioArtName.zeile(arten))
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                    // Cardio rueckt nicht nach: nur "verpasst", ohne Zieltag.
                    if verpasst {
                        Text("verpasst")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignSystem.Color.textMuted)
                    }
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
            .opacity(verpasst ? 0.75 : 1)

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
            Text("Fester Termin aus deinem Wochenplan.")
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
                // Ein vergangener Tag (abhakbar, aber nicht heute) hatte nichts.
                let vergangen = darfAbhaken && !istHeute
                Text(vergangen ? "Kein Training" : istHeute ? "Heute nichts geplant" : "Nichts geplant")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
                if !vergangen {
                    Text("Willst du spontan trainieren, geht das jederzeit im Tab Training.")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
        case .einheit(let einheit, let zustand):
            EinheitKarte(
                modell: .einheit(
                    einheit, namen: einheitNamen, muskeln: muskeln, tag: tag, zustand: zustand),
                geschlecht: geschlecht, kalender: kalender,
                beiTipp: { beiEinheit(einheit.key) },
                hinweis: "Zeigt die Übungen der Einheit")
        case .kurs(let termin):
            PlanTerminZeile(kaestchen: AnyView(PlanKursKaestchen()), titel: termin.name, tag: tag)
        case .cardio:
            PlanTerminZeile(kaestchen: AnyView(PlanCardioKaestchen()), titel: "Cardio-Einheit", tag: tag)
        }
    }
}

/// Die kurze Zeile fuer einen Kurs oder Cardio-Termin mit Tag: Kaestchen,
/// Titel, Tag. "Als nächstes" im Plan-Tab und "Nächste Einheit" auf Home.
struct PlanTerminZeile: View {
    let kaestchen: AnyView
    let titel: String
    let tag: String

    var body: some View {
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
/// Ring (Kurs), Raute (Cardio), gestrichelter Ring (verpasst) -- Formen,
/// nicht nur Farben.
struct PlanTagMarke: View {
    enum Art: CaseIterable { case einheit, kurs, cardio, verpasst }
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
            case .verpasst:
                Circle().strokeBorder(
                    DesignSystem.Color.textFaint, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
            }
        }
        .frame(width: 8, height: 8)
    }
}
