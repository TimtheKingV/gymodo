import SwiftUI

/// Ein Feld, ein Knopf. Der Weg zum Namen fuer alle, die sich vor
/// Sub-Projekt 4 registriert haben -- und fuer alle, die ihren aendern
/// wollen.
struct NameSheet: View {
    let bisher: String?
    let speichern: (String) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var fehler: String?
    @State private var laeuft = false

    private var nameLeer: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                LabeledField(label: "NAME") {
                    TextField("Dein Name", text: $name)
                        .textContentType(.givenName)
                }

                if let fehler {
                    InlineBanner(tone: .danger, message: fehler)
                }

                // PrimaryButton kapselt die Task selbst (siehe dessen
                // Definition) -- die Aktion hier ist bereits async, kein
                // zusaetzlicher Task-Wrapper noetig.
                PrimaryButton(
                    title: "Speichern",
                    isEnabled: !nameLeer,
                    isLoading: laeuft,
                    disabledHint: nameLeer ? "Gib deinen Namen ein" : nil
                ) {
                    laeuft = true
                    fehler = await speichern(name)
                    laeuft = false
                    if fehler == nil { dismiss() }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, DesignSystem.Spacing.s24)
            .background(DesignSystem.Color.bg)
            .navigationTitle("NAME")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { name = bisher ?? "" }
    }
}
