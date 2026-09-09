import SwiftUI

struct MemberKeinStudioView: View {
    @Environment(CatalogStore.self) private var catalogStore
    @Environment(SessionStore.self) private var sessionStore
    @State private var manualCode = ""
    @State private var showScanner = false
    @State private var errorMessage: String?
    @State private var isJoining = false
    /// Der Nebenweg des Scanner-Sheets ("Code stattdessen eingeben") hat
    /// bisher nur das Sheet geschlossen und sonst nichts getan -- der
    /// gleichwertige zweite Weg (designsystem.md SS11) fuehrte also
    /// nirgendwohin. Der Knopf merkt sich jetzt den Wunsch, und
    /// `onDismiss` setzt den Fokus, wenn das Sheet TATSAECHLICH weg ist:
    /// waehrend der Schliessanimation nimmt das Feld darunter noch keinen
    /// Fokus an.
    @State private var codeEingabeGewuenscht = false
    @FocusState private var codeFokus: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("NOCH KEIN STUDIO").font(DesignSystem.Typography.screentitel)

                SecondaryButton(title: "Code im Studio scannen") {
                    showScanner = true
                }
                Text("Aushang am Eingang oder Aufkleber am Gerät.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)

                Text("KEIN CODE ZUR HAND?").font(DesignSystem.Typography.label).foregroundStyle(DesignSystem.Color.textMuted)
                LabeledField(label: "Studio-Code") {
                    TextField("ABCD1234", text: $manualCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($codeFokus)
                }
                Text("Den Code bekommst du an der Theke.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)

                if let errorMessage {
                    InlineBanner(tone: .danger, message: errorMessage)
                }

                PrimaryButton(title: "Beitreten", isEnabled: !manualCode.isEmpty, isLoading: isJoining) {
                    await joinByCode()
                }

                Spacer()

                Button("Abmelden") { Task { await sessionStore.signOut() } }
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(28)
        }
        .background(DesignSystem.Color.bg)
        .sheet(isPresented: $showScanner, onDismiss: {
            guard codeEingabeGewuenscht else { return }
            codeEingabeGewuenscht = false
            codeFokus = true
        }) {
            ScannerSheet(
                titel: "Code scannen",
                hinweis: "QR-Code am Studioeingang ins Feld halten.",
                nebenweg: .knopf(
                    titel: "Code stattdessen eingeben",
                    aktion: { codeEingabeGewuenscht = true }
                ),
                beiCode: { scanned in
                    showScanner = false
                    Task { await joinByTag(scanned) }
                }
            )
        }
    }

    private func joinByCode() async {
        errorMessage = nil
        isJoining = true
        defer { isJoining = false }
        do {
            try await catalogStore.joinStudio(byCode: manualCode)
        } catch {
            errorMessage = "Dieser Code ist ungültig."
        }
    }

    /// Der QR-Code traegt den vollstaendigen Universal Link
    /// (https://<host>/t/<token>), der Endpoint erwartet aber den blanken
    /// 22-Zeichen-Token -- ohne Extraktion antwortet der Server mit 422.
    /// TagLink.token(fromScan:) ist der eine Ort fuer diese Extraktion.
    private func joinByTag(_ scanned: String) async {
        let token = TagLink.token(fromScan: scanned)
        errorMessage = nil
        isJoining = true
        defer { isJoining = false }
        do {
            try await catalogStore.joinStudio(byTag: token)
        } catch {
            errorMessage = "Dieser Code ist ungültig."
        }
    }
}
