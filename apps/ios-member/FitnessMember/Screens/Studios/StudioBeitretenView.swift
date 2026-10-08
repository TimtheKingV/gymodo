import SwiftUI

/// Studio beitreten per Scan oder Code. Der Presenter schliesst den Screen
/// in `beiErfolg`. Der Beitritt passiert immer; den Ort wechselt dieser
/// Screen danach ueber dieselbe Pruefung wie die Studioliste im Profil --
/// laeuft anderswo eine Einheit, fragt er erst "Training in X beenden?".
struct StudioBeitretenView: View {
    @Environment(CatalogStore.self) private var catalogStore
    @Environment(WorkoutSessionStore.self) private var sessions
    /// Meldet den Abschluss einer fuer den Wechsel beendeten Einheit.
    let loader: any GeraetLoading
    let beiErfolg: () -> Void
    /// Der Beitritt, der auf "Training in X beenden?" wartet.
    @State private var wechselPending: JoinResult?
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
        .confirmationDialog(
            "Training in \(StudiosListe.name(fuer: laufenderOrt, studios: catalogStore.bootstrap?.studios ?? [])) beenden?",
            isPresented: Binding(
                get: { wechselPending != nil },
                set: { if !$0 { wechselPending = nil } }
            ),
            presenting: wechselPending
        ) { ergebnis in
            Button("Training beenden", role: .destructive) { beendenUndWechseln(ergebnis) }
            // Mitglied bleibt man; der Ort bleibt, wo die Einheit laeuft.
            Button("Abbrechen", role: .cancel) { wechselPending = nil; beiErfolg() }
        } message: { _ in
            Text("Danach wechselst du den Ort.")
        }
        .testnotizScreen()
    }

    private var laufenderOrt: Ort {
        sessions.aktiveSession()?.ort ?? catalogStore.ort
    }

    private func joinByCode() async {
        errorMessage = nil
        isJoining = true
        defer { isJoining = false }
        // `do throws(APIError)`, damit `error` im catch getippt ist -- derselbe
        // Griff wie in ProfilRootView und TrainingAbschlussView.
        let ergebnis: JoinResult
        do throws(APIError) {
            ergebnis = try await catalogStore.joinStudio(byCode: manualCode)
        } catch {
            errorMessage = beitrittsfehler(error, ungueltig: "Dieser Code ist ungültig.")
            return
        }
        abschliessen(ergebnis)
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
        let ergebnis: JoinResult
        do throws(APIError) {
            ergebnis = try await catalogStore.joinStudio(byTag: token)
        } catch {
            errorMessage = beitrittsfehler(error, ungueltig: "Dieser Code ist ungültig.")
            return
        }
        abschliessen(ergebnis)
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
    /// Gewechselt wird nur, wenn keine Einheit an einem anderen Ort laeuft
    /// (Plan, Entscheidung 1) -- sonst erst nach der Rueckfrage.
    private func abschliessen(_ ergebnis: JoinResult) {
        errorMessage = nachladefehler()
        guard errorMessage == nil else { return }
        switch Ortswechsel.pruefen(ziel: .studio(ergebnis.studioId), aktuell: catalogStore.ort,
                                   offeneEinheit: sessions.aktiveSession()) {
        case .sofort:
            catalogStore.ortNachBeitritt(ergebnis)
            beiErfolg()
        case .erstBeenden:
            wechselPending = ergebnis
        }
    }

    /// Wie in der Studioliste: lokal sofort beenden, den Abschluss im
    /// Hintergrund melden, kein Abschluss-Screen.
    private func beendenUndWechseln(_ ergebnis: JoinResult) {
        wechselPending = nil
        let ende = sessions.beendenFuerOrtswechsel()
        catalogStore.ortNachBeitritt(ergebnis)
        let client = loader
        Task { await WorkoutSessionStore.melden(ende, loader: client) }
        beiErfolg()
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
