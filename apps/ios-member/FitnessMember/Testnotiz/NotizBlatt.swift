#if DEBUG
import SwiftUI

struct NotizBlatt: View {
    private let testnotiz = Testnotiz.shared
    @State private var text = ""
    @State private var aufnahme = Aufnahme()
    @State private var sichert = false
    @State private var transkript = ""
    @State private var erkenntTranskript = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                    kopf

                    TextField("Was stimmt hier nicht?", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Color.text)
                        .padding(DesignSystem.Spacing.s12)
                        .background(DesignSystem.Color.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.card))

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                        SecondaryButton(title: aufnahmeTitel) { await aufnahmeGetippt() }
                        if let start = aufnahme.gestartetUm {
                            aufnahmeAnzeige(seit: start)
                        }
                        if aufnahme.erlaubnis == .verweigert {
                            hinweis("Mikrofon in den Einstellungen freigeben")
                        }
                        if let fehler = aufnahme.fehler {
                            hinweis(fehler)
                        }
                    }

                    if aufnahme.datei != nil {
                        transkriptFeld
                    }

                    PrimaryButton(
                        title: "Sichern",
                        isEnabled: !erkenntTranskript,
                        isLoading: sichert,
                        disabledHint: erkenntTranskript ? "Transkript wird erkannt…" : nil
                    ) { await sichern() }
                }
                .padding(DesignSystem.Spacing.s16)
            }
            .background(DesignSystem.Color.bg)
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Verwerfen") {
                        aufnahme.verwerfen()
                        testnotiz.zurRuhe()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        // Wischen schliesst das Blatt ohne "Verwerfen"; ohne diese Zeile blieben
        // Aufnahme und Audio-Sitzung aktiv. Nach "Sichern" hat abgeben() die Datei
        // schon uebernommen, dann tut verwerfen() nichts.
        .onDisappear { aufnahme.verwerfen() }
    }

    private var titel: String {
        switch testnotiz.entwurf?.art ?? .note {
        case .crop: "Ausschnitt"
        case .element: "Element"
        case .note: "Notiz"
        }
    }

    private var aufnahmeTitel: String {
        if aufnahme.laeuft { return "Aufnahme beenden" }
        return aufnahme.datei == nil ? "Sprachnotiz aufnehmen" : "Neu aufnehmen"
    }

    @ViewBuilder
    private var kopf: some View {
        if let entwurf = testnotiz.entwurf {
            if let bild = entwurf.ausschnitt {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 96, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
            }
            if entwurf.art == .element {
                Text(entwurf.element.map(TestnotizMarkdown.elementZeile) ?? "Kein Element unter dem Finger")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Color.text)
            }
            Text(entwurf.screen?.file ?? "Kein Screen gemeldet")
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    private func hinweis(_ text: String) -> some View {
        Text(text)
            .font(DesignSystem.Typography.fliesstext)
            .foregroundStyle(DesignSystem.Color.textMuted)
    }

    private func aufnahmeAnzeige(seit start: Date) -> some View {
        HStack(spacing: DesignSystem.Spacing.s8) {
            PulsierenderAufnahmepunkt()
            Text(timerInterval: start...Date.distantFuture, countsDown: false)
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.danger)
        }
    }

    @ViewBuilder
    private var transkriptFeld: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            Text("Transkript")
                .font(DesignSystem.Typography.label)
                .foregroundStyle(DesignSystem.Color.textMuted)
            if erkenntTranskript {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField("Kein Transkript erkannt", text: $transkript, axis: .vertical)
                    .lineLimit(2...6)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Color.text)
                    .padding(DesignSystem.Spacing.s12)
                    .background(DesignSystem.Color.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
            }
        }
    }

    /// Stopp loest die Erkennung aus; ein neuer Start (Neu aufnehmen) verwirft
    /// das alte Transkript sofort, es gehoert zur vorigen Aufnahme.
    private func aufnahmeGetippt() async {
        if aufnahme.laeuft {
            await aufnahme.umschalten()
            await transkribieren()
        } else {
            transkript = ""
            await aufnahme.umschalten()
        }
    }

    private func transkribieren() async {
        guard let datei = aufnahme.datei else { return }
        erkenntTranskript = true
        transkript = await Transkription.transkribieren(datei) ?? ""
        erkenntTranskript = false
    }

    private func sichern() async {
        sichert = true
        let audio = aufnahme.abgeben()
        let notiz = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let transkriptText = transkript.trimmingCharacters(in: .whitespacesAndNewlines)
        await testnotiz.sichern(
            notiz: notiz.isEmpty ? nil : notiz,
            audio: audio,
            transkript: transkriptText.isEmpty ? nil : transkriptText
        )
    }
}

/// Sanftes Pulsieren als Lebenszeichen der laufenden Aufnahme -- startet bei
/// jedem Erscheinen neu, weil das Blatt bei "Neu aufnehmen" dieselbe Instanz behaelt.
private struct PulsierenderAufnahmepunkt: View {
    @State private var sichtbar = false

    var body: some View {
        Circle()
            .fill(DesignSystem.Color.danger)
            .frame(width: 10, height: 10)
            .opacity(sichtbar ? 1 : 0.3)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    sichtbar = true
                }
            }
    }
}
#endif
