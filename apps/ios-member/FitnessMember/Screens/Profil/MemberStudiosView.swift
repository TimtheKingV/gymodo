import SwiftUI

struct MemberStudiosView: View {
    @Environment(CatalogStore.self) private var catalogStore
    @State private var studioPendingLeave: BootstrapResponse.Studio?
    @Environment(WorkoutSessionStore.self) private var sessions
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?
    @State private var wechselPending: Ort?
    let apiClient: APIClient

    private var studios: [BootstrapResponse.Studio] {
        catalogStore.bootstrap?.studios ?? []
    }

    var body: some View {
        List {
            ForEach(StudiosListe.zeilen(studios: studios, ort: catalogStore.ort)) { zeile in
                HStack(spacing: 12) {
                    Circle()
                        .fill(zeile.istAktiv ? DesignSystem.Color.accent : DesignSystem.Color.line)
                        .frame(width: 7, height: 7)

                    Text(zeile.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(zeile.istAktiv ? DesignSystem.Color.text : DesignSystem.Color.textMuted)

                    Spacer()

                    if zeile.istAktiv {
                        Image(systemName: "checkmark")
                            .foregroundStyle(DesignSystem.Color.accent)
                            .accessibilityHidden(true)
                    }

                    if zeile.darfVerlassen, case .studio(let id) = zeile.ort,
                       let studio = studios.first(where: { $0.id == id }) {
                        Button("Verlassen") { studioPendingLeave = studio }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DesignSystem.Color.danger)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }
                // Trefferflaeche ist die ganze Zeile, nicht nur der ~18pt hohe
                // Text -- >= 44pt gilt in dieser App durchgaengig.
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .onTapGesture { wechseln(zeile.ort) }
                .accessibilityAddTraits(zeile.istAktiv ? .isSelected : [])
                .listRowBackground(DesignSystem.Color.surface)
            }

            NavigationLink("Studio beitreten") {
                StudioBeitretenView(loader: apiClient) { dismiss() }
            }
            .font(.system(size: 15, weight: .bold))
            .frame(minHeight: 44)
            .listRowBackground(DesignSystem.Color.surface)
        }
        .scrollContentBackground(.hidden)
        .background(DesignSystem.Color.bg)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text(StudiosListe.fusstext)
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
        .confirmationDialog(
            "Training in \(StudiosListe.name(fuer: laufenderOrt, studios: studios)) beenden?",
            isPresented: Binding(
                get: { wechselPending != nil },
                set: { if !$0 { wechselPending = nil } }
            ),
            presenting: wechselPending
        ) { ziel in
            Button("Training beenden", role: .destructive) { beendenUndWechseln(zu: ziel) }
            Button("Abbrechen", role: .cancel) {}
        } message: { _ in
            Text("Danach wechselst du den Ort.")
        }
        .testnotizScreen()
    }

    private var laufenderOrt: Ort {
        sessions.aktiveSession()?.ort ?? catalogStore.ort
    }

    private func wechseln(_ ziel: Ort) {
        switch Ortswechsel.pruefen(ziel: ziel, aktuell: catalogStore.ort,
                                   offeneEinheit: sessions.aktiveSession()) {
        case .sofort: catalogStore.setOrt(ziel)
        case .erstBeenden: wechselPending = ziel
        }
    }

    /// Lokal sofort, Server im Hintergrund -- kein Abschluss-Screen in diesem
    /// Pfad, der Server beendet sonst nach vier Stunden selbst.
    private func beendenUndWechseln(zu ziel: Ort) {
        let ende = sessions.beendenFuerOrtswechsel()
        catalogStore.setOrt(ziel)
        let client = apiClient
        Task { await WorkoutSessionStore.melden(ende, loader: client) }
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
