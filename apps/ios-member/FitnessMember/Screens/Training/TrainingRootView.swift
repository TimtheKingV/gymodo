import SwiftUI

/// Bewusst schmucklos: Scan-Button, Blockliste, "Training beenden".
///
/// Der Artboard-Ausbau nach TrainingLeer / TrainingLaeuft / TrainingAbschluss
/// gehoert zu Sub-Projekt 3. Diese Wurzel kommt hier mit, weil der Kernflow
/// sonst nicht schliessbar waere: POST .../complete haette keinen Ausloeser,
/// "Zurueck zum Training" liefe ins Leere, und der Zirkelfall aus M1-Spec
/// SS5.3 waere nicht baubar.
struct TrainingRootView: View {
    @Environment(CatalogStore.self) private var katalog
    @Environment(WorkoutSessionStore.self) private var sessions
    @Environment(PendingTagStore.self) private var pendingTag

    let apiClient: APIClient

    @State private var pfad: [GeraetRoute] = []
    @State private var scannerOffen = false
    @State private var scanFehler: String?
    /// Der laufende Neulade-und-Retry-Versuch aus oeffneToken(_:), falls
    /// gerade einer offen ist. Ohne dieses Handle wuerden zwei schnelle
    /// Scans zwei nebenlaeufige Tasks erzeugen, die beide spaeter scanFehler
    /// schreiben -- der zuletzt FERTIGE gewinnt dann, nicht der zuletzt
    /// GESTARTETE, und ein alter Fehltreffer koennte so ueber einem
    /// zwischenzeitlich erfolgreichen Scan landen.
    @State private var neuladeVersuch: Task<Void, Never>?

    var body: some View {
        NavigationStack(path: $pfad) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                    kopf
                    if let session = sessions.aktiveSession(), !session.bloecke.isEmpty {
                        ForEach(session.bloecke) { block in
                            Button { oeffne(block) } label: { blockZeile(block) }
                                .buttonStyle(PressButtonStyle())
                        }
                    } else {
                        Text("Tippe ein Gerät an oder scanne den Code — dein Training beginnt von allein.")
                            .font(DesignSystem.Typography.fliesstext)
                            .foregroundStyle(DesignSystem.Color.textMuted)
                            .lineSpacing(4)
                    }
                    if let scanFehler {
                        InlineBanner(tone: .danger, message: scanFehler)
                    }
                    PrimaryButton(title: "Gerät scannen") { scannerOffen = true }
                    if sessions.aktiveSession() != nil {
                        SecondaryButton(title: "Training beenden") { await beenden() }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s24)
            }
            .background(DesignSystem.Color.bg)
            .navigationDestination(for: GeraetRoute.self, destination: ziel)
            .sheet(isPresented: $scannerOffen) {
                MemberScannerView { code in
                    scannerOffen = false
                    oeffneToken(code)
                }
            }
            // Ein ueber Universal Link erfasster Token wird hier verbraucht --
            // Sub-Projekt 1 hat ihn nur fuer das Banner auf LoginMail genutzt.
            // Deckt den Kalteinstieg ab: der Token liegt beim ersten Aufbau
            // dieser View schon vor.
            .task {
                if let token = pendingTag.consume() { oeffneToken(token) }
            }
            // Deckt die beiden anderen Faelle ab: ein Tag-Tap, waehrend die
            // App schon auf einem anderen Tab laeuft, UND -- der haeufigere
            // Fall -- waehrend das Mitglied schon auf Training ist, egal wie
            // tief in pfad verschachtelt. onChange feuert bei jeder Aenderung
            // von pendingTag.token, solange diese View im Baum haengt --
            // anders als .task/.onAppear haengt das nicht daran, ob der
            // Training-Tab gerade ausgewaehlt ist, und die Wurzel bleibt
            // gemountet, waehrend Ziele darueber gepusht werden.
            .onChange(of: pendingTag.token) { _, neu in
                guard neu != nil, let token = pendingTag.consume() else { return }
                oeffneToken(token)
            }
            // Verlaesst die Wurzel die Buehne (z.B. Kontowechsel reisst die
            // gesamte Umgebung neu auf), soll ein noch laufender Retry nicht
            // in einen verschwundenen Zustand hinein schreiben.
            .onDisappear { neuladeVersuch?.cancel() }
        }
    }

    // MARK: - Kopf und Zeilen

    private var kopf: some View {
        Text(sessions.aktiveSession() == nil ? "TRAINING" : "TRAINING LÄUFT")
            .font(DesignSystem.Typography.screentitel)
            .tracking(-1)
            .foregroundStyle(DesignSystem.Color.text)
    }

    private func blockZeile(_ block: LokalerBlock) -> some View {
        let maschine = katalog.bootstrap?.machines.first { $0.id == block.machineId }
        let uebung = maschine?.exercises.first { $0.id == block.exerciseId }
        let letztes = block.saetze.last
        return HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text([maschine?.equipmentModel.name, uebung?.name]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                Text("\(block.saetze.count) \(block.saetze.count == 1 ? "Satz" : "Sätze")"
                     + (letztes.map { " · \(Zahlformat.gewichtMitEinheit($0.weightKg))" } ?? ""))
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.textFaint)
        }
        .padding(DesignSystem.Spacing.s16)
        .frame(minHeight: 44)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Öffnet das Gerät")
    }

    // MARK: - Navigation

    @ViewBuilder
    private func ziel(_ route: GeraetRoute) -> some View {
        switch route {
        case .erkannt(let machineId, let token):
            if let modell = modell(machineId: machineId, exerciseId: nil, token: token) {
                GeraetErkanntView(modell: modell) { uebungId in
                    pfad.append(.geraet(machineId: machineId, exerciseId: uebungId, token: token))
                }
            }
        case .geraet(let machineId, let exerciseId, let token):
            if let modell = modell(machineId: machineId, exerciseId: exerciseId, token: token) {
                GeraetScreen(modell: modell) { pfad.removeAll() }
            }
        }
    }

    private func modell(machineId: String, exerciseId: String?, token: String?) -> GeraetModel? {
        guard let bootstrap = katalog.bootstrap,
              let maschine = bootstrap.machines.first(where: { $0.id == machineId })
        else { return nil }
        // Vorauswahl: zuletzt genutzte Uebung, sonst die erste aus der vom
        // Studio gepflegten Reihenfolge (M1-Spec SS5.7).
        let zuletzt = bootstrap.lastSets
            .filter { $0.machineId == machineId }
            .max { $0.performedAt < $1.performedAt }?.exerciseId
        let gewaehlt = exerciseId ?? zuletzt ?? maschine.exercises.first?.id
        guard let gewaehlt else { return nil }
        return GeraetModel(
            maschine: maschine, uebungId: gewaehlt, token: token,
            bootstrap: bootstrap, loader: apiClient, sessions: sessions,
            enqueue: { katalog.enqueue($0); Task { await katalog.flushPending() } }
        )
    }

    /// Der Kalteinstieg: Token lokal hashen, Geraet im Prefetch finden,
    /// sofort rendern (M1-Spec SS8.1 Schritt 3).
    ///
    /// Ein vorheriger Neulade-Versuch wird immer zuerst storniert: sonst
    /// koennte ein noch laufender Retry aus einem AELTEREN Scan spaeter
    /// fertig werden als dieser Aufruf und dessen Ergebnis -- Navigation
    /// oder Fehlermeldung -- ueberschreiben.
    private func oeffneToken(_ token: String) {
        scanFehler = nil
        neuladeVersuch?.cancel()
        guard let bootstrap = katalog.bootstrap else { return }
        guard let maschine = MachineResolver.maschine(fuerToken: token, in: bootstrap) else {
            // Ein Geraet, das nach dem letzten Prefetch dazukam. Einmal neu
            // laden, dann erneut versuchen -- sonst dieselbe neutrale
            // Antwort wie serverseitig fuer unbekannt/gesperrt.
            neuladeVersuch = Task {
                await katalog.load()
                // Ein Abbruch bedeutet: ein neuerer Scan oder das
                // Verschwinden der View hat diesen Versuch bereits ersetzt.
                // Dann darf dieser hier weder navigieren noch scanFehler
                // setzen -- beides wuerde einen aktuelleren Zustand
                // ueberschreiben.
                guard !Task.isCancelled else { return }
                guard let frisch = katalog.bootstrap,
                      let maschine = MachineResolver.maschine(fuerToken: token, in: frisch) else {
                    scanFehler = "Dieser Code ist nicht aktiv. Frag im Studio nach."
                    return
                }
                navigiere(zu: maschine, token: token, in: frisch)
            }
            return
        }
        navigiere(zu: maschine, token: token, in: bootstrap)
    }

    private func navigiere(zu maschine: BootstrapResponse.Machine, token: String, in bootstrap: BootstrapResponse) {
        // Ein neu gescannter Tag ERSETZT einen offenen Geraete-Screen, statt
        // sich davor zu stapeln -- M1-Spec SS5.1 will "ein Ort fuer alles,
        // was am Geraet passiert", keinen Turm aus Screens fuer nacheinander
        // gescannte Geraete. Der legitime Zweifach-Push GeraetErkannt ->
        // GeraetView bleibt unberuehrt: er haengt in ziel(_:) an derselben,
        // gerade erst geleerten Wurzel und wird hier nicht ausgeloest.
        pfad.removeAll()
        let genutzte = GeraetEinstiegRechner.genutzteUebungen(machineId: maschine.id, in: bootstrap)
        switch GeraetEinstiegRechner.einstieg(visitCount: maschine.visitCount,
                                              genutzteUebungen: genutzte) {
        case .erkannt:
            pfad.append(.erkannt(machineId: maschine.id, token: token))
        case .direktZumSatz:
            let uebung = bootstrap.lastSets.first { $0.machineId == maschine.id }?.exerciseId
                ?? maschine.exercises.first?.id
            guard let uebung else { return }
            pfad.append(.geraet(machineId: maschine.id, exerciseId: uebung, token: token))
        }
    }

    private func oeffne(_ block: LokalerBlock) {
        // Der Zirkelfall: ein Tap statt eines Scans (M1-Spec SS5.3).
        pfad.append(.geraet(machineId: block.machineId, exerciseId: block.exerciseId, token: nil))
    }

    private func beenden() async {
        guard let id = sessions.beenden() else { return }
        _ = try? await apiClient.completeSession(sessionId: id)
    }
}
