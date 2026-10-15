import SwiftUI

/// Der Drawer zwischen der Wahl einer Uebung und der Satzseite (Testnotiz
/// 11.10., #6, #10, #11).
///
/// Er liegt ueber der Seite, auf der die Uebung gewaehlt wurde -- Liste
/// oder Geraeteseite --, statt als eigene Seite davor. Schliessen laesst
/// sie stehen. Bei einer neuen Uebung beginnt er mit der Einweisung (und
/// der Einstellung, wo es eine gibt), jede Wahl endet bei den Startwerten:
/// "Übung starten" uebergibt die Raeder an die Satzseite, die dann mit
/// dem Countdown beginnt.
struct UebungsstartSheet: View {
    /// @State, weil der Inhalt des Sheets bei jeder Auswertung der Wurzel
    /// ein frisches Modell baut -- ohne dieses @State verloere das Rad
    /// seinen Wert beim naechsten Neuzeichnen (wie GeraetErkanntScreen).
    @State private var modell: GeraetModel
    let beiStart: (Startwerte) -> Void
    let beiSchliessen: () -> Void

    /// Einmal beim Oeffnen bestimmt, nicht bei jedem Rendern: ein spaeter
    /// eintreffender Kontext darf dem Mitglied nicht unter derselben
    /// Position einen anderen Schritt unterschieben (wie zuvor im
    /// Erstkontakt).
    @State private var schritte: [UebungsstartSchritt]
    @State private var position = 0
    /// Wohin "Zurueck" nach "Kenne ich schon" fuehrt: an den Schritt, von
    /// dem aus uebersprungen wurde, nicht in die uebersprungene Einstellung.
    @State private var ruecksprung: Int?
    /// Gemessen fuer die Startwerte allein, siehe `detents`.
    @State private var hoehe: CGFloat = 520

    init(modell: GeraetModel, beiStart: @escaping (Startwerte) -> Void,
         beiSchliessen: @escaping () -> Void) {
        _modell = State(initialValue: modell)
        self.beiStart = beiStart
        self.beiSchliessen = beiSchliessen
        _schritte = State(initialValue: Uebungsstart.schritte(
            erstkontakt: modell.istErstkontakt,
            fragtEinstellung: modell.erstkontaktFragtEinstellung,
            volumeKind: modell.volumeKind))
    }

    var body: some View {
        Group {
            if schritte.isEmpty {
                // Sollte der Aufrufer abfangen (`Uebungsstart.direktStart`);
                // ohne Schritt gibt es nichts zu zeigen.
                Color.clear.onAppear { starten() }
            } else {
            switch schritte[position] {
            case .einweisung:
                EinweisungSchritt(
                    modell: modell, titel: titel("Einweisung"),
                    hauptaktion: schritte.contains(.einstellung) ? "Einstellungen erfassen"
                        : (istLetzter ? "Übung starten" : "Weiter"),
                    beiAbbruch: beiSchliessen,
                    beiWeiter: { weiter() },
                    beiUeberspringen: { ueberspringen() })
            case .einstellung:
                KalibrierungSchritt(modell: modell, titel: titel("Deine Einstellung"),
                                    beiZurueck: { zurueck() }) { weiter() }
            case .startwerte:
                StartwerteSchritt(
                    modell: modell,
                    titel: schritte.count > 1 ? titel("Startwerte") : nil,
                    beiZurueck: position > 0 ? { zurueck() } : nil
                ) { starten() }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    // Die untere Safe Area gehoert zum Detent, nicht zum
                    // Inhalt -- sonst sitzt der Knopf hinter dem
                    // Home-Indikator.
                    proxy.size.height + proxy.safeAreaInsets.bottom
                } action: { hoehe = $0 }
                // Nach der Messung: gemessen wird der Inhalt, oben buendig
                // steht er in jeder Hoehe.
                .frame(maxHeight: .infinity, alignment: .top)
            }
            }
        }
        .background(DesignSystem.Color.bg)
        // Kontext fuer Video, Beschreibung und Vorschlag. Kommt er nicht
        // (offline), steht alles aus dem Prefetch.
        .task { await modell.kontextLaden() }
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
    }

    /// Nur die Startwerte (bekannte Uebung): so hoch wie der Inhalt, die
    /// Seite darunter bleibt sichtbar. Mit Einweisung die volle Hoehe --
    /// Video und Text brauchen sie, und ein Drawer, der zwischen den
    /// Schritten die Hoehe wechselt, springt unter dem Daumen.
    private var detents: Set<PresentationDetent> {
        schritte == [.startwerte] ? [.height(hoehe)] : [.large]
    }

    /// "Schritt 2 von 3 · Deine Einstellung" -- die Zahl folgt der
    /// tatsaechlichen Liste, nicht dem Regelfall.
    private func titel(_ name: String) -> String {
        "Schritt \(position + 1) von \(schritte.count) · \(name)"
    }

    private var istLetzter: Bool { position == schritte.count - 1 }

    /// Ohne Startwerte (Cardio, Testnotiz 14.10., 18:45 #6) startet der
    /// letzte Schritt die Uebung selbst.
    private func weiter() {
        if istLetzter { starten() } else { position += 1 }
    }

    /// Erst jetzt ist der Erstkontakt durch: wer vorher schliesst, bekommt
    /// die Einweisung beim naechsten Mal wieder.
    private func starten() {
        modell.erstkontaktAbschliessen()
        beiStart(modell.startwerte)
    }

    private func zurueck() {
        if let ziel = ruecksprung {
            ruecksprung = nil
            position = ziel
        } else {
            position = max(position - 1, 0)
        }
    }

    private func ueberspringen() {
        guard let ziel = Uebungsstart.positionNachUeberspringen(in: schritte) else {
            starten()
            return
        }
        ruecksprung = position
        position = ziel
    }
}

/// Der letzte Schritt des Drawers: was beim letzten Mal galt, die Raeder
/// und "Übung starten" (Testnotiz 11.10., #10). Ersetzt den Rueckblick,
/// der bisher als eigenes Sheet auf der Satzseite aufging.
struct StartwerteSchritt: View {
    @Bindable var modell: GeraetModel
    /// Nur im mehrschrittigen Ablauf; allein braucht der Drawer keine Zeile
    /// "Schritt 1 von 1".
    let titel: String?
    let beiZurueck: (() -> Void)?
    let beiStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
            if let titel { kopf(titel) }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(modell.station.equipmentModel.name.uppercased())
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textFaint)
                Text(modell.aktiveUebung?.name ?? "")
                    .font(DesignSystem.Typography.detailScreentitel)
                    .foregroundStyle(DesignSystem.Color.text)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let rueckblick = modell.rueckblick {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    Text("ZULETZT")
                        .font(DesignSystem.Typography.label)
                        .tracking(1.5)
                        .foregroundStyle(DesignSystem.Color.textFaint)
                    Text(rueckblick.zuletzt)
                        .font(DesignSystem.Typography.uebungsname)
                        .monospacedDigit()
                        .foregroundStyle(DesignSystem.Color.text)
                        .fixedSize(horizontal: false, vertical: true)
                    if let vorschlag = rueckblick.vorschlag {
                        // Eine Rechnung, keine Empfehlung (designsystem.md
                        // SS10).
                        Text(vorschlag)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DesignSystem.Color.textMuted)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            WertZeile(modell: modell)

            // Mit Einweisung hat der Drawer volle Hoehe; ohne Spacer hing
            // "Übung starten" mitten darin statt in der Daumenzone
            // (Testnotiz 12.10. abends, #1). Allein (titel == nil) nicht:
            // dort misst der Drawer seinen Inhalt, ein Spacer liesse ihn
            // auf die angebotene Hoehe wachsen.
            if titel != nil { Spacer(minLength: 0) }

            VStack(spacing: DesignSystem.Spacing.s8) {
                // Die Uhr laeuft erst mit diesem Tipp, nicht schon waehrend
                // der Einweisung (Testnotiz 06.10., #5) -- gesagt wird es,
                // weil es keinen eigenen Startscreen mehr gibt.
                if !modell.trainingLaeuft {
                    Text("Mit „Übung starten“ läuft deine Trainingsuhr.")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                PrimaryButton(title: "Übung starten") { beiStart() }
                    .testnotizElement("uebungsstart.starten", typ: "PrimaryButton")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, DesignSystem.Spacing.s24)
        .padding(.bottom, DesignSystem.Spacing.s16)
        .testnotizScreen()
    }

    private func kopf(_ titel: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            if let beiZurueck {
                Button(action: beiZurueck) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.text)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PressButtonStyle())
                .accessibilityLabel("Zurück")
            }
            Text(titel.uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textFaint)
        }
    }
}
