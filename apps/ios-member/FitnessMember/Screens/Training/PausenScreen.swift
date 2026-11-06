import SwiftUI

/// Der eine Pausen-Screen fuer freies Training, Plan und Mini-Zirkel
/// (UX-Paket 2, Abschnitt 2.1; Boards "Pause · Plan", "Pause · Zirkel").
/// Ersetzt das fruehere Pausen-Rad am Geraet und den Koerper der Zirkel-Pause.
///
/// Eine reine Ansicht: sie haelt weder Timer noch Ablauf, sondern zeigt
/// Werte und meldet Absichten. Geraet und Zirkel-Ebene behalten ihre
/// Navigation und ihren Pausenende-Task -- die Quellen sind verschieden
/// (GeraetModel.laufendePause gegen ZirkelAblauf.pause), der Screen nicht.
///
/// Vorbild ist die Zirkel-Pause: kleiner Ring, darunter, was war und was
/// kommt. Die Uhr ist Nebensache, die Ablauf-Liste sagt, wo man steht.
struct PausenScreen: View {
    /// Bereits grossgeschrieben, fuer die Kopfzeile.
    let ort: String
    /// "PAUSE · BRUSTPRESSE", "PAUSE · MINI-ZIRKEL", "RUNDENPAUSE · MINI-ZIRKEL".
    let ueberschrift: String
    let ablaufzeile: Ablaufzeile?
    let timer: Resttimer
    let zeilen: [AblaufZeile]
    let knoepfe: PausenKnoepfe
    /// Die Einheit fuer "± kg" (Testnotiz 12.10. abends, #4).
    let einheit: LoadUnit
    let beiSteuerung: () -> Void
    let beiVerlaengern: () -> Void
    let beiHaupt: () -> Void
    /// Das Gewicht fuer den naechsten Satz -- in der Pause wird umgesteckt
    /// (Testnotiz 11.10., #12). nil blendet den Knopf aus: im Zirkel gibt
    /// es noch kein Ziel dafuer (Task 5), und ein Knopf ohne Wirkung waere
    /// schlimmer als keiner.
    let beiGewicht: (() -> Void)?
    let beiAbschliessen: () -> Void
    let beiUeberspringen: () -> Void
    let beiZirkelBeginnen: () -> Void
    let beiErweitern: () -> Void
    let beiZirkelBeenden: () -> Void

    /// "Alle anzeigen" klappt die Liste aus; nur Ansicht (E6).
    @State private var ausgeklappt = false
    /// Der gedrosselte Ansagetext (designsystem.md SS12). Ein eigener
    /// Task-Takt statt einer zweiten TimelineView, damit der Sekundentakt
    /// der sichtbaren Anzeige unangetastet bleibt.
    @State private var ansage: String

    init(ort: String, ueberschrift: String, ablaufzeile: Ablaufzeile?, timer: Resttimer,
         zeilen: [AblaufZeile], knoepfe: PausenKnoepfe, einheit: LoadUnit = .kg,
         beiSteuerung: @escaping () -> Void,
         beiVerlaengern: @escaping () -> Void,
         beiHaupt: @escaping () -> Void,
         beiGewicht: (() -> Void)?,
         beiAbschliessen: @escaping () -> Void = {},
         beiUeberspringen: @escaping () -> Void = {},
         beiZirkelBeginnen: @escaping () -> Void = {},
         beiErweitern: @escaping () -> Void = {},
         beiZirkelBeenden: @escaping () -> Void = {}) {
        self.ort = ort
        self.ueberschrift = ueberschrift
        self.ablaufzeile = ablaufzeile
        self.timer = timer
        self.zeilen = zeilen
        self.knoepfe = knoepfe
        self.einheit = einheit
        self.beiSteuerung = beiSteuerung
        self.beiVerlaengern = beiVerlaengern
        self.beiHaupt = beiHaupt
        self.beiGewicht = beiGewicht
        self.beiAbschliessen = beiAbschliessen
        self.beiUeberspringen = beiUeberspringen
        self.beiZirkelBeginnen = beiZirkelBeginnen
        self.beiErweitern = beiErweitern
        self.beiZirkelBeenden = beiZirkelBeenden
        _ansage = State(initialValue: timer.gesprochen())
    }

    /// Nur der Zirkel kennt "Überspringen" -- daran haengen die
    /// Testnotiz-IDs, die beide Pausen schon vorher trugen.
    private var imZirkel: Bool { knoepfe.ueberspringen }

    var body: some View {
        // Die Hoehe des sichtbaren Bereichs, damit die Knoepfe unten in der
        // Daumenzone stehen (Testnotiz 05.10., #12); passt der Inhalt nicht,
        // scrollt er.
        GeometryReader { sichtbar in
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                    TrainingKopfzeile(ort: ort, beiSteuerung: beiSteuerung)
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                        Text(ueberschrift)
                            .font(DesignSystem.Typography.label)
                            .tracking(1.5)
                            .foregroundStyle(DesignSystem.Color.textMuted)
                        if let ablaufzeile {
                            AblaufzeilePille(zeile: ablaufzeile)
                        }
                    }
                    uhr
                    if !zeilen.isEmpty {
                        liste
                    }
                    Spacer(minLength: 0)
                    knoepfeAnzeigen
                }
                .padding(.horizontal, 20)
                .padding(.bottom, DesignSystem.Spacing.s8)
                .frame(minHeight: sichtbar.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(DesignSystem.Color.bg)
    }

    // MARK: - Uhr

    /// 140 statt 240 pt: gross genug fuer die Ziffern aus einem Meter, klein
    /// genug, dass die Liste darunter das Auge zuerst bekommt. "+30 s"
    /// direkt daneben -- er betrifft nur die Uhr.
    private var uhr: some View {
        HStack(spacing: DesignSystem.Spacing.s16) {
            Zeitring(timer: timer, beschriftung: "PAUSE", kante: 140) {
                String(format: "%02d:%02d", $0 / 60, $0 % 60)
            }
            .accessibilityElement(children: .ignore)
            // designsystem.md SS12: der ganze Satz ist das Label, nicht Label
            // plus Value -- "gesprochen" beginnt selbst schon mit "Pause".
            .accessibilityLabel(ansage)
            .accessibilityAddTraits(.updatesFrequently)
            // Auf 15 s gedrosselt (SS12): eine 1:1-Kopplung an die
            // sekuendliche Anzeige waere fuer VoiceOver unbenutzbar. Neu ab
            // dem jeweiligen Endzeitpunkt gekeyed, damit "+30 s" die Ansage
            // neu startet statt den alten Countdown fortzufuehren.
            .task(id: timer.endetAm) {
                while !Task.isCancelled {
                    ansage = timer.gesprochen()
                    guard timer.laeuft() else { break }
                    try? await Task.sleep(for: .seconds(15))
                }
            }
            SecondaryButton(title: "+30 s", action: beiVerlaengern)
                .frame(width: 88)
                .accessibilityLabel("Pause um 30 Sekunden verlängern")
                .testnotizElement(imZirkel ? "zirkel.pause.verlaengern" : "geraet.pause-verlaengern",
                                  typ: "SecondaryButton")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Ablauf-Liste

    private var liste: some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                let sichtbar = AblaufListe.sichtbar(zeilen, ausgeklappt: ausgeklappt)
                ForEach(Array(sichtbar.enumerated()), id: \.element.id) { index, zeile in
                    if index > 0 { Divider().overlay(DesignSystem.Color.line) }
                    zeileAnzeigen(zeile)
                }
                if AblaufListe.hatMehr(zeilen) || ausgeklappt {
                    Divider().overlay(DesignSystem.Color.line)
                    Button(ausgeklappt ? "Weniger anzeigen" : "Alle anzeigen") {
                        ausgeklappt.toggle()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(.plain)
                    .testnotizElement("pause.ablauf.alle", typ: "Button")
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.s12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .testnotizElement("pause.ablauf", typ: "Card")
    }

    /// Standbild statt Video (Spec 2.1): die Liste ist zum Lesen da, eine
    /// Schleife je Zeile zoege den Blick weg.
    private func zeileAnzeigen(_ zeile: AblaufZeile) -> some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            Group {
                if let modellId = zeile.bildModellId {
                    Geraetefoto(modellId: modellId, url: nil, hoehe: 36, breite: 36)
                } else {
                    Uebungsbild(kante: 36)
                }
            }
            .overlay {
                if zeile.stand == .jetzt || zeile.stand == .naechste {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                        .strokeBorder(DesignSystem.Color.accent, lineWidth: 1.5)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(zeile.name)
                    .font(.system(size: 15, weight: zeile.stand == .offen ? .regular : .semibold))
                    .foregroundStyle(zeile.stand == .offen ? DesignSystem.Color.textMuted : DesignSystem.Color.text)
                    .lineLimit(1)
                if !zeile.detail.isEmpty {
                    Text(zeile.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(zeile.stand == .offen ? DesignSystem.Color.textFaint
                                                               : DesignSystem.Color.textMuted)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            Spacer(minLength: 0)
            standAnzeige(zeile.stand)
        }
        .padding(.vertical, 10)
        .opacity(zeile.stand == .erledigt ? 0.7 : 1)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func standAnzeige(_ stand: AblaufZeile.Stand) -> some View {
        switch stand {
        case .erledigt:
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DesignSystem.Color.accent)
                .accessibilityLabel("erledigt")
        case .jetzt:
            standMarke("JETZT")
        case .naechste:
            standMarke("ALS NÄCHSTES")
        case .offen:
            EmptyView()
        }
    }

    private func standMarke(_ text: String) -> some View {
        Text(text)
            .font(DesignSystem.Typography.label)
            .tracking(1)
            .foregroundStyle(DesignSystem.Color.accent)
    }

    // MARK: - Knoepfe

    private var knoepfeAnzeigen: some View {
        VStack(spacing: DesignSystem.Spacing.s8) {
            // Die eine Akzentflaeche (designsystem.md SS2): was als Naechstes
            // dran ist. Er beendet die Pause.
            PrimaryButton(title: knoepfe.haupt) { beiHaupt() }
                .accessibilityHint(imZirkel ? "Beendet die Pause und öffnet die nächste Übung"
                                            : "Beendet die Pause und zeigt wieder die Räder")
                .testnotizElement(imZirkel ? "zirkel.pause.starten" : "geraet.naechster-satz",
                                  typ: "PrimaryButton")
            nebenknoepfe
            textknoepfe
        }
    }

    /// Zwei Umrisse nebeneinander: umstecken, und der zweite Weg aus der
    /// Pause -- "Übung abschließen"/"Nächste Übung" bzw. im Zirkel
    /// "Überspringen".
    private var nebenknoepfe: some View {
        HStack(spacing: DesignSystem.Spacing.s8) {
            if let beiGewicht {
                SecondaryButton(title: PausenKnoepfe.gewichtTitel(einheit), action: beiGewicht)
                    .accessibilityLabel("Gewicht für den nächsten Satz ändern")
                    .testnotizElement("geraet.pause-gewicht", typ: "SecondaryButton")
            }
            if let abschliessen = knoepfe.abschliessen {
                // Derselbe Weg wie "Übung abschließen" unter den Raedern.
                SecondaryButton(title: abschliessen, action: beiAbschliessen)
                    .accessibilityHint("Schließt diese Übung ab")
                    .testnotizElement("geraet.naechste-uebung", typ: "SecondaryButton")
            }
            if knoepfe.ueberspringen {
                // Gilt nur fuer diese Runde und sichert keinen Satz.
                SecondaryButton(title: "Überspringen", action: beiUeberspringen)
                    .accessibilityHint("Lässt die nächste Station in dieser Runde aus")
                    .testnotizElement("zirkel.pause.ueberspringen", typ: "SecondaryButton")
            }
        }
    }

    /// Die seltenen Wege als Text statt Flaeche: ein Zirkel ist die
    /// Ausnahme, nicht der naechste Schritt.
    @ViewBuilder
    private var textknoepfe: some View {
        if knoepfe.zirkelBeginnen {
            textknopf("Zirkel mit weiterem Gerät", farbe: DesignSystem.Color.accent, aktion: beiZirkelBeginnen)
                .frame(maxWidth: .infinity)
                .accessibilityHint("Wählt ein zweites Gerät, die Pause läuft weiter")
                .testnotizElement("geraet.zirkel-beginnen", typ: "Button")
        }
        if knoepfe.erweitern || knoepfe.zirkelBeenden {
            HStack {
                if knoepfe.erweitern {
                    textknopf("+ Übung zum Zirkel", farbe: DesignSystem.Color.accent, aktion: beiErweitern)
                        .testnotizElement("zirkel.pause.erweitern", typ: "Button")
                }
                Spacer(minLength: DesignSystem.Spacing.s12)
                if knoepfe.zirkelBeenden {
                    textknopf("Zirkel beenden", farbe: DesignSystem.Color.textMuted, aktion: beiZirkelBeenden)
                        .accessibilityHint("Behält alle gesicherten Sätze")
                        .testnotizElement("zirkel.pause.beenden", typ: "Button")
                }
            }
        }
    }

    private func textknopf(_ titel: String, farbe: Color, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Text(titel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(farbe)
                .frame(minHeight: 44)
                .padding(.horizontal, DesignSystem.Spacing.s4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
