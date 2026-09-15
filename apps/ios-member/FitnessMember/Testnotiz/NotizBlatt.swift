#if DEBUG
import SwiftUI

struct NotizBlatt: View {
    private let testnotiz = Testnotiz.shared
    @State private var text = ""
    @State private var aufnahme = Aufnahme()
    @State private var sichert = false

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
                        SecondaryButton(title: aufnahmeTitel) { await aufnahme.umschalten() }
                        if aufnahme.erlaubnis == .verweigert {
                            hinweis("Mikrofon in den Einstellungen freigeben")
                        }
                        if let fehler = aufnahme.fehler {
                            hinweis(fehler)
                        }
                    }

                    PrimaryButton(title: "Sichern", isLoading: sichert) { await sichern() }
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

    private func sichern() async {
        sichert = true
        let audio = aufnahme.abgeben()
        let notiz = text.trimmingCharacters(in: .whitespacesAndNewlines)
        await testnotiz.sichern(notiz: notiz.isEmpty ? nil : notiz, audio: audio)
    }
}
#endif
