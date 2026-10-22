import SwiftUI

/// "Mini-Zirkel anlegen" (Spec 21.10., Entscheidung 2, Variante A): eine
/// Liste der Uebungen zum Umsortieren, darunter Runden und beide Pausen
/// (Entscheidung 3), unten "Zirkel starten".
///
/// Kennt weder Katalog noch Navigation: Namen, das Hinzufuegen (eigenes
/// Sheet mit der Geraeteliste) und der Start kommen von der Wurzel
/// (TrainingRootView), die auch den Entwurf haelt -- er muss das
/// Auswahl-Sheet ueberleben, das ueber diesem liegt.
struct ZirkelPlanungSheet: View {
    @Binding var entwurf: ZirkelEntwurf
    let name: (ZirkelUebung) -> String
    /// Ein Satz unter der Liste, etwa wenn ein gewaehltes Geraet nicht
    /// dazukommen konnte. nil = keiner.
    var hinweis: String?
    let beiHinzufuegen: () -> Void
    let beiStart: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                uebungen
                einstellungen
            }
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Color.bg)
            // Schwebt wie die Scanwege an der Wurzel: "Zirkel starten" bleibt
            // in der Daumenzone, egal wie lang die Liste wird.
            .safeAreaInset(edge: .bottom) { fuss }
            .navigationTitle("Mini-Zirkel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .testnotizElement("zirkel.planung.abbrechen", typ: "Button")
                }
            }
        }
        .presentationDragIndicator(.visible)
        .testnotizScreen()
    }

    // MARK: - Uebungen

    private var uebungen: some View {
        Section {
            // Die Uebung selbst ist die Identitaet: der Entwurf nimmt keine
            // zweimal auf (ZirkelEntwurf.hinzufuegen).
            ForEach(Array(entwurf.uebungen.enumerated()), id: \.element) { index, uebung in
                zeile(index: index, uebung: uebung)
                    .listRowBackground(DesignSystem.Color.surface)
            }
            .onMove { entwurf.verschiebe(von: $0, nach: $1) }
            .onDelete { entwurf.entferne(at: $0) }

            Button(action: beiHinzufuegen) {
                Label("Übung hinzufügen", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.accent)
                    .frame(minHeight: 44)
            }
            .listRowBackground(DesignSystem.Color.surface)
            .testnotizElement("zirkel.planung.hinzufuegen", typ: "Button")
        } header: {
            kopf("ÜBUNGEN")
        } footer: {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                if let hinweis {
                    InlineBanner(tone: .muted, message: hinweis)
                }
                // Ohne Bearbeiten-Knopf: Ziehen und Wischen gehen in der
                // Liste direkt, nur sieht man es ihr nicht an.
                Text("Halten und ziehen zum Umsortieren, nach links wischen zum Entfernen.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
        }
        .testnotizElement("zirkel.planung.uebungen", typ: "List")
    }

    private func zeile(index: Int, uebung: ZirkelUebung) -> some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            Text("\(index + 1)")
                .font(.system(size: 15, weight: .black).monospacedDigit())
                .foregroundStyle(DesignSystem.Color.textMuted)
                .frame(width: 20, alignment: .leading)
            UebungsVideoKachel(exerciseId: uebung.exerciseId, kante: 40) {
                Uebungsbild(kante: 40)
            }
            Text(name(uebung))
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.text)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Runden und Pausen

    private var einstellungen: some View {
        Section {
            Stepper(value: $entwurf.runden, in: Zirkel.rundenBereich) {
                // Der Bereich beginnt bei 2: "Runden" passt immer.
                Text("\(entwurf.runden) Runden")
                    .monospacedDigit()
            }
            .testnotizElement("zirkel.planung.runden", typ: "Stepper")
            Picker("Pause zwischen Übungen", selection: $entwurf.uebungspause) {
                ForEach(Einstellungen.resttimerStufen, id: \.self) { stufe in
                    Text("\(stufe) s").tag(stufe)
                }
            }
            .testnotizElement("zirkel.planung.uebungspause", typ: "Picker")
            Picker("Rundenpause", selection: $entwurf.rundenpause) {
                ForEach(Einstellungen.resttimerStufen, id: \.self) { stufe in
                    Text("\(stufe) s").tag(stufe)
                }
            }
            .testnotizElement("zirkel.planung.rundenpause", typ: "Picker")
        } header: {
            kopf("ABLAUF")
        }
        // Ausdruecklich: die Systemfarbe der Beschriftung folgt dem Hell-/
        // Dunkelmodus des Geraets, die Flaeche darunter nicht -- im hellen
        // Modus stuende schwarze Schrift auf surface (Sichtpruefung Task 6).
        .foregroundStyle(DesignSystem.Color.text)
        .tint(DesignSystem.Color.accent)
        .listRowBackground(DesignSystem.Color.surface)
    }

    /// Beide Kopfzeilen gleich und ausdruecklich -- die Farbe der Zeilen
    /// darunter (siehe einstellungen) faerbte sonst nur eine davon.
    private func kopf(_ titel: String) -> some View {
        Text(titel)
            .font(DesignSystem.Typography.label)
            .tracking(1.5)
            .foregroundStyle(DesignSystem.Color.textMuted)
    }

    // MARK: - Fuss

    private var fuss: some View {
        PrimaryButton(title: "Zirkel starten", isEnabled: entwurf.istGueltig,
                      disabledHint: "Ein Zirkel braucht mindestens zwei Übungen.") {
            beiStart()
        }
        .testnotizElement("zirkel.planung.starten", typ: "PrimaryButton")
        .padding(.horizontal, 20)
        .padding(.vertical, DesignSystem.Spacing.s12)
        .background(DesignSystem.Color.bg)
    }
}
