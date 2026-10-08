import SwiftUI

/// Studio beitreten per Scan oder Code. Der Presenter schliesst den Screen
/// in `beiErfolg`; der Ortswechsel und der `studiohinweis` kommen aus dem
/// CatalogStore (`joinStudio`), nicht von hier.
struct StudioBeitretenView: View {
    @Environment(CatalogStore.self) private var catalogStore
    let beiErfolg: () -> Void
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
                Text("STUDIO BEITRETEN").font(DesignSystem.Typography.screentitel)

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
        abschliessen()
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
        abschliessen()
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

    /// Schliesst nur, wenn das Neuladen gelang: sonst steht das Studio in der
    /// Datenbank, aber nicht auf dem Bildschirm, und der Screen muss es sagen.
    private func abschliessen() {
        errorMessage = nachladefehler()
        if errorMessage == nil { beiErfolg() }
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
