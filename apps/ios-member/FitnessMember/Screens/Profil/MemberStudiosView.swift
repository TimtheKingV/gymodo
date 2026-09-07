import SwiftUI

struct MemberStudiosView: View {
    @Environment(CatalogStore.self) private var catalogStore
    @State private var studioPendingLeave: BootstrapResponse.Studio?
    @State private var errorMessage: String?

    private var studios: [BootstrapResponse.Studio] {
        catalogStore.bootstrap?.studios ?? []
    }

    var body: some View {
        List {
            ForEach(studios) { studio in
                HStack(spacing: 12) {
                    Circle()
                        .fill(studio.id == catalogStore.activeStudioId ? DesignSystem.Color.accent : DesignSystem.Color.line)
                        .frame(width: 7, height: 7)

                    Text(studio.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(studio.id == catalogStore.activeStudioId ? DesignSystem.Color.text : DesignSystem.Color.textMuted)
                        .contentShape(Rectangle())
                        .onTapGesture { catalogStore.setActiveStudio(studio.id) }

                    Spacer()

                    Button("Verlassen") { studioPendingLeave = studio }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignSystem.Color.danger)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .listRowBackground(DesignSystem.Color.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DesignSystem.Color.bg)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tippen wechselt. Ein Scan im anderen Studio wechselt von selbst.")
                Text("Ein Studio, das du verlässt, verliert dich als Mitglied — deine Sätze und dein Fortschritt bleiben bei dir.")
                if let errorMessage {
                    InlineBanner(tone: .danger, message: errorMessage)
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(DesignSystem.Color.textFaint)
            .padding(20)
            .background(DesignSystem.Color.bg)
        }
        .navigationTitle("STUDIOS")
        .confirmationDialog(
            "\(studioPendingLeave?.name ?? "Studio") verlassen?",
            isPresented: Binding(
                get: { studioPendingLeave != nil },
                set: { if !$0 { studioPendingLeave = nil } }
            ),
            presenting: studioPendingLeave
        ) { studio in
            Button("Verlassen", role: .destructive) { Task { await leave(studio) } }
            Button("Abbrechen", role: .cancel) {}
        } message: { _ in
            Text("Ein Studio, das du verlässt, verliert dich als Mitglied — deine Sätze und dein Fortschritt bleiben bei dir.")
        }
    }

    private func leave(_ studio: BootstrapResponse.Studio) async {
        errorMessage = nil
        do {
            try await catalogStore.leaveStudio(studio.id)
        } catch {
            errorMessage = "Das hat nicht geklappt. Prüf deine Verbindung."
        }
    }
}
