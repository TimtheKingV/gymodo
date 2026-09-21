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
                    TextField("", text: $manualCode, prompt: Text.platzhalter("ABCD1234"))
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

                // .frame(minHeight: 44) INNERHALB des Labels, sonst
                // bleibt die Trefferflaeche die Glyphenhoehe der Schrift
                // (SS4). textMuted statt textFaint: 13pt liegt unter den
                // 15pt, ab denen textFaint zulaessig waere, und "Abmelden"
                // ist tragend (SS2).
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
        .testnotizScreen()
    }

    private func joinByCode() async {
        errorMessage = nil
        isJoining = true
        defer { isJoining = false }
        // `do throws(APIError)`, damit `error` im catch getippt ist -- derselbe
        // Griff wie in ProfilRootView und TrainingAbschlussView.
        do throws(APIError) {
            try await catalogStore.joinStudio(byCode: manualCode)
        } catch {
            errorMessage = beitrittsfehler(error, ungueltig: "Dieser Code ist ungültig.")
            return
        }
        errorMessage = nachladefehler()
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
        do throws(APIError) {
            try await catalogStore.joinStudio(byTag: token)
        } catch {
            errorMessage = beitrittsfehler(error, ungueltig: "Dieser Code ist ungültig.")
            return
        }
        errorMessage = nachladefehler()
    }

    /// Ein Beitritt kann aus vier Gruenden scheitern, und nur einer davon
    /// ist ein falscher Code. Bis zum 18. September sagte dieser Bildschirm
    /// bei allen vieren denselben Satz -- ein Serverausfall las sich damit
    /// wie ein Tippfehler, und wer den richtigen Code in der Hand hielt,
    /// suchte an der falschen Stelle.
    private func beitrittsfehler(_ fehler: APIError, ungueltig: String) -> String {
        switch fehler {
        case .notFound, .validation: ungueltig
        case .offline: "Keine Verbindung. Der Code wurde nicht gesendet."
        default: fehler.servertext
        }
    }

    /// Der Beitritt kann gelingen und das anschliessende Neuladen trotzdem
    /// scheitern -- dann steht das Studio in der Datenbank, aber nicht auf
    /// dem Bildschirm. Genau das war am 18. September das "es passiert
    /// nichts": `joinStudio` warf nicht, `load()` schluckte seinen Fehler,
    /// und der Knopf blieb stumm.
    ///
    /// Beim allerersten Laden traegt RootView diesen Fall inzwischen auf
    /// den Ladefehler-Bildschirm. Hier bleibt der andere: stand schon ein
    /// Bootstrap (Studio verlassen, dann neu beigetreten), haelt
    /// `CatalogStore.load()` den alten absichtlich fest und bleibt auf
    /// `.loaded` -- dieser Bildschirm bleibt dann stehen und muss es
    /// selbst sagen.
    private func nachladefehler() -> String? {
        guard let fehler = catalogStore.letzterLadefehler else { return nil }
        return fehler == .offline
            ? "Beigetreten. Die Daten deines Studios fehlen noch — keine Verbindung."
            : "Beigetreten. Die Daten deines Studios ließen sich nicht laden: \(fehler.servertext)"
    }
}

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
                // "Abmelden" auf MemberKeinStudioView (SS2, SS4).
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
            ? "Keine Verbindung. gymodo konnte dein Studio nicht abrufen."
            : fehler.servertext
    }
}
