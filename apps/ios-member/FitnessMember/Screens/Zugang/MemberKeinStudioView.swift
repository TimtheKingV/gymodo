import SwiftUI

struct MemberKeinStudioView: View {
    @Environment(CatalogStore.self) private var catalogStore
    @Environment(SessionStore.self) private var sessionStore
    @State private var manualCode = ""
    @State private var showScanner = false
    @State private var errorMessage: String?
    @State private var isJoining = false

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
        .sheet(isPresented: $showScanner) {
            MemberScannerView { scanned in
                showScanner = false
                Task { await joinByTag(scanned) }
            }
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

    private func joinByTag(_ token: String) async {
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
