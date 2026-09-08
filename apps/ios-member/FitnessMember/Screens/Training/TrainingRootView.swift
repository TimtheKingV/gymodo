import SwiftUI

/// Leer und laufend sind kein zweiter Screen, sondern zwei Zustaende
/// derselben Wurzel (TrainingLeer.dc.html / TrainingLaeuft.dc.html).
///
/// Sub-Projekt 2 hatte diese Wurzel als Rumpf gebaut, damit der Kernflow
/// schliessbar war: POST .../complete brauchte einen Ausloeser,
/// "Zurueck zum Training" haette sonst ins Leere gefuehrt, und der
/// Zirkelfall aus M1-Spec SS5.3 waere nicht baubar gewesen. Hier bekommt sie
/// ihre Gestalt.
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
    /// Einmal beim Erscheinen aus sessions.abgelaufeneSession() gelesen, BEVOR
    /// ausgelaufeneQuittieren() die Einheit raeumt. ausgelaufeneQuittieren()
    /// loescht seit einer Fehlerbehebung Speicher und Datei, statt nur ein
    /// Bool zu setzen -- wuerde der Satz reaktiv aus abgelaufeneSession()
    /// gerendert und im selben Atemzug quittiert, verschwaende er, bevor das
    /// Mitglied ihn liest. Deshalb: einmal in diesen Zustand lesen, den Satz
    /// aus DIESEM Zustand zeigen, danach quittieren. Er bleibt so stehen,
    /// bis die Wurzel verlassen wird.
    @State private var zeigeAusgelaufenHinweis = false

    var body: some View {
        NavigationStack(path: $pfad) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                    if let session = sessions.aktiveSession() {
                        laufendInhalt(session)
                    } else {
                        leerInhalt
                    }
                    if let scanFehler {
                        InlineBanner(tone: .danger, message: scanFehler)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s24)
            }
            .background(DesignSystem.Color.bg)
            .navigationDestination(for: GeraetRoute.self, destination: ziel)
            .sheet(isPresented: $scannerOffen) {
                ScannerSheet(
                    titel: "Gerät finden",
                    hinweis: "QR-Code auf dem Aufkleber ins Feld halten.",
                    nebenweg: .karte(
                        titel: "Oder einfach antippen",
                        text: "Halt die Oberkante deines iPhones an den Aufkleber — dafür musst du diesen Bildschirm nicht offen haben."
                    ),
                    beiCode: { code in
                        scannerOffen = false
                        // Die Gym-QR-Codes tragen den vollstaendigen Universal
                        // Link, nicht den blanken Token -- oeffneToken hasht und
                        // vergleicht gegen tokenHashes, die nur den Token kennen.
                        oeffneToken(TagLink.token(fromScan: code))
                    }
                )
            }
            // Ein ueber Universal Link erfasster Token wird hier verbraucht --
            // Sub-Projekt 1 hat ihn nur fuer das Banner auf LoginMail genutzt.
            // Deckt den Kalteinstieg ab: der Token liegt beim ersten Aufbau
            // dieser View schon vor. Derselbe einmalige Moment liest auch die
            // ggf. abgelaufene Einheit (siehe zeigeAusgelaufenHinweis oben).
            .task {
                if sessions.abgelaufeneSession() != nil {
                    zeigeAusgelaufenHinweis = true
                    // Erst gelesen (Zeile darueber), jetzt erst quittiert --
                    // und nur, wenn es ueberhaupt etwas zu quittieren gab.
                    // ausgelaufeneQuittieren() loescht unbedingt, ohne selbst
                    // zu pruefen, ob gerade eine aktive Einheit laeuft; ein
                    // Aufruf ins Leere waere zwar in der Sache folgenlos, ein
                    // unbedachter Aufruf HIER waere es nicht das Risiko wert.
                    sessions.ausgelaufeneQuittieren()
                }
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

    // MARK: - Leerer Zustand (TrainingLeer.dc.html)

    @ViewBuilder
    private var leerInhalt: some View {
        Text("TRAINING")
            .font(DesignSystem.Typography.screentitel)
            .tracking(-1)
            .foregroundStyle(DesignSystem.Color.text)

        VStack(spacing: DesignSystem.Spacing.s24) {
            nfcZeichnung
            VStack(spacing: DesignSystem.Spacing.s12) {
                Text("HALT DEIN IPHONE\nAN DEN AUFKLEBER")
                    .font(.system(size: 25, weight: .black))
                    .tracking(-0.6)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DesignSystem.Color.text)
                Text("Am Gerät klebt ein Aufkleber mit dem gymodo-Zeichen. Dein Training startet von selbst, sobald du den ersten Satz sicherst — es gibt keinen Startknopf.")
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.s24)

        if zeigeAusgelaufenHinweis {
            InlineBanner(tone: .muted, message: "Dein letztes Training wurde automatisch beendet.")
        }

        VStack(spacing: DesignSystem.Spacing.s12) {
            qrReihe
            // Abweichung vom Artboard: dort text-faint bei 12pt. Der Satz
            // traegt die Gleichwertigkeit von Scan und Antippen, die die
            // Optik allein nicht zeigt (SS11) -- das ist tragende
            // Information, und die faellt unter 15pt nicht unter textFaint
            // (designsystem.md SS2).
            Text("Auf jedem Aufkleber ist beides — antippen oder scannen, gleiches Ergebnis.")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
    }

    /// Die NFC-Zeichnung als SF-Symbol-Komposition statt Bild-Asset -- das
    /// Projekt hat keine und soll keine bekommen, solange ein Symbol reicht.
    /// Rein dekorativ: die Bedeutung steht in der Ueberschrift und dem Satz
    /// daneben.
    private var nfcZeichnung: some View {
        ZStack {
            Circle()
                .stroke(DesignSystem.Color.line, lineWidth: 1)
                .frame(width: 148, height: 148)
            Circle()
                .stroke(DesignSystem.Color.surfaceRaised, lineWidth: 1)
                .frame(width: 108, height: 108)
            Image(systemName: "wave.3.right")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(DesignSystem.Color.accent)
        }
        .frame(width: 148, height: 148)
        .accessibilityHidden(true)
    }

    /// Der QR-Weg, kleiner zweiter Weg neben der NFC-Zeichnung -- Kontur,
    /// keine Akzentflaeche. Die Hauptaktion des leeren Zustands ist der
    /// NFC-Tipp gegen den Aufkleber, kein Knopf auf dem Bildschirm; die
    /// einzige Akzentflaeche hier ist die NFC-Zeichnung selbst
    /// (designsystem.md SS2, siehe Bericht).
    private var qrReihe: some View {
        Button { scannerOffen = true } label: {
            HStack(spacing: DesignSystem.Spacing.s12) {
                Image(systemName: "qrcode")
                    .font(.system(size: 19, weight: .semibold))
                Text("QR-Code am Gerät scannen")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(DesignSystem.Color.text)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
        .buttonStyle(PressButtonStyle())
    }

    // MARK: - Laufender Zustand (TrainingLaeuft.dc.html)

    @ViewBuilder
    private func laufendInhalt(_ session: LokaleSession) -> some View {
        laufendKopf(session)

        VStack(spacing: DesignSystem.Spacing.s12) {
            ForEach(session.bloecke) { block in
                Button { oeffne(block) } label: { blockZeile(block) }
                    .buttonStyle(PressButtonStyle())
            }
            zirkelHinweis
        }

        VStack(spacing: DesignSystem.Spacing.s8) {
            PrimaryButton(title: "Nächstes Gerät") { scannerOffen = true }
            VStack(spacing: DesignSystem.Spacing.s4) {
                SecondaryButton(title: "Training beenden") { beenden() }
                // Zulaessig in textFaint (anders als der Gleichwertigkeitssatz
                // oben): der Satz erklaert nur eine Alternative, er traegt
                // selbst nichts (designsystem.md SS2).
                Text("Ohne neuen Satz endet das Training nach vier Stunden von selbst.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func laufendKopf(_ session: LokaleSession) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                HStack(spacing: DesignSystem.Spacing.s8) {
                    Circle()
                        .fill(DesignSystem.Color.textMuted)
                        .frame(width: 8, height: 8)
                    // Abweichung vom Artboard: dort accent fuer Punkt und
                    // Label. Die eine Akzentflaeche dieses Screens ist
                    // "Naechstes Geraet" (designsystem.md SS2, siehe Bericht).
                    Text("TRAINING LÄUFT")
                        .font(DesignSystem.Typography.label)
                        .tracking(1.5)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                TimelineView(.periodic(from: .now, by: 1)) { zeit in
                    Text(verstrichen(seit: session.startedAt, bis: zeit.date))
                        .font(.system(size: 40, weight: .black).monospacedDigit())
                        .foregroundStyle(DesignSystem.Color.text)
                }
                // M1-Spec SS5.6: es gibt keinen Startknopf. Ohne diesen Satz
                // wuesste niemand, warum ploetzlich ein Training laeuft.
                Text("seit \(Zahlformat.uhrzeit(session.startedAt))")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            Spacer()
            HStack(spacing: DesignSystem.Spacing.s16) {
                statistik(wert: Set(session.bloecke.map(\.machineId)).count, label: "GERÄTE")
                statistik(wert: session.bloecke.flatMap(\.saetze).count, label: "SÄTZE")
            }
        }
    }

    private func statistik(wert: Int, label: String) -> some View {
        VStack(alignment: .trailing, spacing: DesignSystem.Spacing.s4) {
            Text("\(wert)")
                .font(.system(size: 21, weight: .black).monospacedDigit())
                .foregroundStyle(DesignSystem.Color.text)
            Text(label)
                .font(DesignSystem.Typography.label)
                .tracking(1)
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    /// "23:41" -- Minuten:Sekunden, tabellarisch, nach oben unbegrenzt (eine
    /// Einheit laeuft bis zu vier Stunden, WorkoutSessionStore.sessionPause).
    /// Gegen session.startedAt gerechnet, nicht gegen einen mitgezaehlten
    /// Wert: ein gespeicherter Zeitpunkt ueberlebt Hintergrund und
    /// Sperrbildschirm, ein Zaehler nicht -- dasselbe Muster wie der
    /// Resttimer aus Sub-Projekt 2.
    private func verstrichen(seit start: Date, bis jetzt: Date) -> String {
        let sekunden = max(0, Int(jetzt.timeIntervalSince(start)))
        return String(format: "%02d:%02d", sekunden / 60, sekunden % 60)
    }

    private var zirkelHinweis: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.s8) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
            Text("Zweiter Durchgang? Tipp auf den Block statt neu zu scannen — du landest direkt beim nächsten Satz mit deinem Gewicht.")
                .font(.system(size: 12))
                .lineSpacing(3)
        }
        .foregroundStyle(DesignSystem.Color.textFaint)
        .padding(.top, DesignSystem.Spacing.s4)
    }

    // MARK: - Kopf und Zeilen

    private func blockZeile(_ block: LokalerBlock) -> some View {
        let maschine = katalog.bootstrap?.machines.first { $0.id == block.machineId }
        let uebung = maschine?.exercises.first { $0.id == block.exerciseId }
        let letztes = block.saetze.last
        let gemeldet = block.saetze.contains(where: \.problemFlag)
        return HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text([maschine?.equipmentModel.name, uebung?.name]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                HStack(spacing: DesignSystem.Spacing.s8) {
                    Text("\(block.saetze.count) \(block.saetze.count == 1 ? "Satz" : "Sätze")"
                         + (letztes.map { " · \(Zahlformat.gewichtMitEinheit($0.weightKg))" } ?? ""))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                    if gemeldet {
                        // Umriss, nie Flaeche -- warn markiert eine
                        // Rueckmeldung des Mitglieds, keinen Systemfehler
                        // (designsystem.md SS2). Hier nur als Textfarbe/Icon,
                        // nicht als gefuellte Form -- die Kartenkontur unten
                        // traegt den eigentlichen Umriss.
                        Label("gemeldet", systemImage: "exclamationmark.triangle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignSystem.Color.warn)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.textFaint)
        }
        .padding(DesignSystem.Spacing.s16)
        .frame(minHeight: 44)
        .background(DesignSystem.Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(gemeldet ? DesignSystem.Color.warn : DesignSystem.Color.line,
                        lineWidth: gemeldet ? 1.5 : 1)
        )
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
                GeraetErkanntScreen(modell: modell) { uebungId in
                    pfad.append(.geraet(machineId: machineId, exerciseId: uebungId, token: token))
                }
            }
        case .geraet(let machineId, let exerciseId, let token):
            if let modell = modell(machineId: machineId, exerciseId: exerciseId, token: token) {
                GeraetScreen(modell: modell) { pfad.removeAll() }
            }
        case .abschluss(sessionId: _, zusammenfassung: let zusammenfassung):
            // Platzhalter: der eigentliche TrainingAbschlussScreen samt
            // completeSession-Aufruf ist Aufgabe 6 (Sub-Projekt 3). Der Fall
            // muss hier bereits existieren, damit der Pfad-Push aus
            // beenden() ein Ziel findet.
            Text("Trainingsabschluss – \(zusammenfassung.satzAnzahl) Sätze")
                .foregroundStyle(DesignSystem.Color.text)
        }
    }

    private func modell(machineId: String, exerciseId: String?, token: String?) -> GeraetModel? {
        guard let bootstrap = katalog.bootstrap,
              let maschine = bootstrap.machines.first(where: { $0.id == machineId })
        else { return nil }
        // Vorauswahl: zuletzt genutzte Uebung, sonst die erste aus der vom
        // Studio gepflegten Reihenfolge (M1-Spec SS5.7).
        let zuletzt = GeraetEinstiegRechner.letzteUebung(machineId: machineId, in: bootstrap)
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
            let uebung = GeraetEinstiegRechner.letzteUebung(machineId: maschine.id, in: bootstrap)
                ?? maschine.exercises.first?.id
            guard let uebung else { return }
            pfad.append(.geraet(machineId: maschine.id, exerciseId: uebung, token: token))
        }
    }

    private func oeffne(_ block: LokalerBlock) {
        // Der Zirkelfall: ein Tap statt eines Scans (M1-Spec SS5.3).
        pfad.append(.geraet(machineId: block.machineId, exerciseId: block.exerciseId, token: nil))
    }

    private func beenden() {
        guard let session = sessions.aktiveSession(),
              let zusammenfassung = Trainingszusammenfassung(session)
        else { return }
        // Erst festhalten, dann beenden -- andersherum sind die Zahlen weg,
        // bevor der Screen sie zeigt.
        sessions.beenden()
        pfad.append(.abschluss(sessionId: session.id, zusammenfassung: zusammenfassung))
    }
}
