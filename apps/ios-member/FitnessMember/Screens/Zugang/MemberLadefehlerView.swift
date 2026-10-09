import SwiftUI

/// Der Bootstrap ist gescheitert. Das ist etwas anderes als "kein Studio",
/// und seit dem 18. September hat es einen eigenen Bildschirm -- die
/// Begruendung steht bei `RootDestinationLogic.destination`.
///
/// Kein Beitrittsformular hier: ein Code hilft gegen einen Serverausfall
/// nicht, und ihn trotzdem anzubieten war der Teil, der aus dem Ausfall
/// eine Sackgasse gemacht hat. Was bleibt, sind die zwei Wege, die wirklich
/// weiterfuehren: noch einmal versuchen, oder sich abmelden.
struct MemberLadefehlerView: View {
    @Environment(CatalogStore.self) private var catalogStore
    @Environment(SessionStore.self) private var sessionStore
    @State private var laedtNeu = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("NICHT GELADEN").font(DesignSystem.Typography.screentitel)

                InlineBanner(tone: .danger, message: meldung)

                // Der Satz, der den Fehlgriff von damals ausschliesst: wer
                // hier landet, soll nicht anfangen, seine Mitgliedschaft in
                // Frage zu stellen.
                Text("Das ist ein Ladefehler, keine Aussage über deine Mitgliedschaft. Dein Studio bleibt, wo es ist.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                    .fixedSize(horizontal: false, vertical: true)

                PrimaryButton(title: "Erneut versuchen", isLoading: laedtNeu) {
                    await erneutVersuchen()
                }

                Spacer()

                // Dieselbe Trefferflaeche und dieselbe Farbstufe wie das
                // "Abmelden" auf StudioBeitretenView (SS2, SS4).
                Button { Task { await sessionStore.signOut() } } label: {
                    Text("Abmelden")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
            .padding(28)
        }
        .background(DesignSystem.Color.bg)
        .testnotizScreen()
    }

    /// Dieselbe Form wie `joinByCode()` nebenan: die Arbeit in einer
    /// Methode, der Knopf ruft sie nur.
    private func erneutVersuchen() async {
        laedtNeu = true
        defer { laedtNeu = false }
        await catalogStore.load()
    }

    /// `.offline` zuerst: APIError.servertext weist seinen eigenen
    /// .offline-Zweig ausdruecklich als Notnagel aus, nicht als Antwort.
    private var meldung: String {
        guard let fehler = catalogStore.letzterLadefehler else {
            return "Dein Studio ließ sich nicht laden."
        }
        return fehler == .offline
            ? "Keine Verbindung. Gymtavo konnte dein Studio nicht abrufen."
            : fehler.servertext
    }
}
