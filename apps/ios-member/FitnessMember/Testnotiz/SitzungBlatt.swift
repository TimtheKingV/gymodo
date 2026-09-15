#if DEBUG
import SwiftUI

struct SitzungBlatt: View {
    private let testnotiz = Testnotiz.shared
    @State private var zip: URL?
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                Text(zusammenfassung)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Color.text)

                if let ordner = testnotiz.ablage?.ordner {
                    Text(ordner.lastPathComponent)
                        .font(DesignSystem.Typography.fliesstext)
                        .foregroundStyle(DesignSystem.Color.textMuted)

                    if let zip {
                        ShareLink(item: zip) {
                            Text("Sitzung teilen")
                                .font(.system(size: 19, weight: .heavy))
                                .frame(maxWidth: .infinity)
                                .frame(height: 64)
                                .foregroundStyle(DesignSystem.Color.onAccent)
                        }
                        .buttonStyle(HauptaktionButtonStyle(isEnabled: true))
                    } else {
                        ProgressView().tint(DesignSystem.Color.accent)
                    }

                    SecondaryButton(title: "Ordner in Dateien öffnen") {
                        // shareddocuments:// oeffnet die Dateien-App am Ordner;
                        // das geht nur mit UIFileSharingEnabled (Debug-Plist).
                        if let url = URL(string: "shareddocuments://" + ordner.path) { openURL(url) }
                    }
                }

                SecondaryButton(title: "Neue Sitzung beginnen") {
                    testnotiz.neueSitzung()
                    zip = nil
                }

                Spacer()
            }
            .padding(DesignSystem.Spacing.s16)
            .background(DesignSystem.Color.bg)
            .navigationTitle("Sitzung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { testnotiz.zurRuhe() }
                }
            }
        }
        .presentationDetents([.medium])
        .task(id: testnotiz.eintragsanzahl) {
            zip = try? await testnotiz.ablage?.zipFuerTeilen()
        }
    }

    private var zusammenfassung: String {
        switch testnotiz.eintragsanzahl {
        case 0: "Noch kein Eintrag in dieser Sitzung."
        case 1: "1 Eintrag in dieser Sitzung."
        default: "\(testnotiz.eintragsanzahl) Einträge in dieser Sitzung."
        }
    }
}
#endif
