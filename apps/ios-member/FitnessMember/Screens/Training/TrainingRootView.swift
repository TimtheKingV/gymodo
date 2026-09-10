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
    @Environment(\.scenePhase) private var scenePhase

    let apiClient: APIClient

    @State private var pfad: [GeraetRoute] = []
    @State private var scannerOffen = false
    @State private var scanFehler: String?
    /// Der aktive NFC-Scan. Liegt hier und nicht in ScanWege, weil sein
    /// Ergebnis in dieselbe Aufloesung muendet wie der QR-Scan -- und weil
    /// eine laufende Sitzung einen zweiten Tap ueberstehen muss.
    @State private var nfcLeser = NFCTagLeser()
    /// Der laufende Neulade-und-Retry-Versuch aus oeffneToken(_:), falls
    /// gerade einer offen ist. Ohne dieses Handle wuerden zwei schnelle
    /// Scans zwei nebenlaeufige Tasks erzeugen, die beide spaeter scanFehler
    /// schreiben -- der zuletzt FERTIGE gewinnt dann, nicht der zuletzt
    /// GESTARTETE, und ein alter Fehltreffer koennte so ueber einem
    /// zwischenzeitlich erfolgreichen Scan landen.
    @State private var neuladeVersuch: Task<Void, Never>?
    /// Reiner Ausloeser, wird selbst nirgends gelesen: eine @State-Aenderung
    /// erzwingt IMMER einen body-Neuaufbau der eigenen View, unabhaengig
    /// davon, ob der Wert irgendwo verwendet wird -- anders als bei
    /// @Environment, wo SwiftUI nur invalidiert, was tatsaechlich gelesen
    /// wurde. Siehe .onChange(of: scenePhase) unten (M2): kehrt das
    /// Mitglied aus dem Hintergrund zurueck, soll sessions.aktiveSession()
    /// sofort neu ausgewertet werden, nicht erst bei der naechsten
    /// 60-Sekunden-Kadenz der TimelineView.
    @State private var neuAuswerten = false
    /// Aus sessions.abgelaufeneSession() gelesen, BEVOR ausgelaufeneQuittieren()
    /// die Einheit raeumt -- an drei Stellen, aber mit derselben Regel: erst
    /// lesen, den Satz aus DIESEM Zustand zeigen, danach quittieren.
    /// ausgelaufeneQuittieren() loescht seit einer Fehlerbehebung Speicher
    /// und Datei, statt nur ein Bool zu setzen -- wuerde der Satz reaktiv aus
    /// abgelaufeneSession() gerendert und im selben Atemzug quittiert,
    /// verschwaende er, bevor das Mitglied ihn liest.
    ///
    /// Die drei Stellen: das .task(id: UmschaltTick(...)) in der
    /// TimelineView unten (Kalteinstieg UND der selbsttaetige Ablauf
    /// waehrend die App offen bleibt -- M2b), und die beiden Zweige von
    /// beenden() (manuelles
    /// Beenden setzt false, der Fehlerfall dort setzt true). Er bleibt
    /// stehen, bis die Wurzel verlassen wird -- ODER bis er selbst nicht
    /// mehr gilt: beenden() setzt ihn beim manuellen Beenden zurueck, der
    /// onChange unten zusaetzlich beim Uebergang in einen neuen laufenden
    /// Zustand. Der Satz gehoert zu GENAU EINER abgelaufenen Einheit, nicht
    /// zur View.
    @State private var zeigeAusgelaufenHinweis = false

    var body: some View {
        NavigationStack(path: $pfad) {
            ScrollView {
                // Die Kadenz von 60 s zwingt body dazu, sessions.aktiveSession()
                // periodisch neu auszuwerten. @Observable zeichnet sonst nur bei
                // einer Aenderung von gespeicherteSession neu -- beim Ablauf der
                // Vier-Stunden-Frist aendert sich dort nichts, und ohne diese
                // TimelineView bliebe der Screen auf "laufend" stehen, obwohl die
                // Einheit laengst ausgelaufen ist (M2). Die sekundengenaue Uhr im
                // laufenden Zustand hat ihre EIGENE, innere TimelineView weiter
                // unten -- diese hier betrifft nur die Umschaltung.
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                        if let session = sessions.aktiveSession() {
                            laufendInhalt(session)
                        } else {
                            leerInhalt
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, DesignSystem.Spacing.s24)
                    // Der Umschalttick selbst wertet nur SEINEN Inhalt neu
                    // aus, nicht den aeusseren body -- und aus einem
                    // ViewBuilder heraus darf ohnehin kein Zustand
                    // geschrieben werden. .task(id:) ist der Ort, der den
                    // Tick wirklich erreicht und schreiben darf. Die ID
                    // kombiniert context.date (den 60-Sekunden-Tick) UND
                    // neuAuswerten (den scenePhase-Ausloeser): faellt
                    // context.date bei einem vom scenePhase-Wechsel
                    // erzwungenen Neuaufbau zufaellig mit dem letzten
                    // Tick-Wert zusammen, macht neuAuswerten die ID trotzdem
                    // neu -- ohne diese Kombination koennte die Erklaerung
                    // bis zu 60 s hinter der bereits umgeschalteten Anzeige
                    // zurueckbleiben.
                    //
                    // abgelaufeneSession() liefert NUR etwas, wenn die
                    // gespeicherte Einheit noch existiert UND
                    // aktiveSession() wegen Zeitablauf nil ist -- das
                    // unterscheidet den selbsttaetigen Ablauf sauber von
                    // einem manuellen "Training beenden": beenden() nullt
                    // gespeicherteSession bereits VOR dem naechsten Tick,
                    // abgelaufeneSession() liefert dann nichts mehr (sonst
                    // waere M1 wieder da). Nach dem ersten Treffer ist
                    // gespeicherteSession geloescht, jeder weitere Tick
                    // liefert deshalb von selbst nichts mehr -- ohne
                    // eigenes Merker-Flag genau einmal. Deckt zugleich den
                    // Kalteinstieg ab -- aber ueber das ERSCHEINEN, nicht
                    // ueber einen Tick: .task(id:) laeuft, sobald die View
                    // im Baum auftaucht, und danach bei jeder Aenderung
                    // der ID. Wer die ID spaeter gegen etwas tauscht, das
                    // nicht am Erscheinen haengt, verliert damit den
                    // Kalteinstieg -- und das gesonderte .task unten
                    // braucht die Pruefung deswegen nicht.
                    .task(id: UmschaltTick(datum: context.date, wach: neuAuswerten)) {
                        guard sessions.abgelaufeneSession() != nil else { return }
                        zeigeAusgelaufenHinweis = true
                        sessions.ausgelaufeneQuittieren()
                    }
                }
            }
            .background(DesignSystem.Color.bg)
            .navigationDestination(for: GeraetRoute.self, destination: ziel)
            .sheet(isPresented: $scannerOffen) {
                ScannerSheet(
                    titel: "Gerät finden",
                    hinweis: "QR-Code auf dem Aufkleber ins Feld halten.",
                    nebenweg: .nfc(
                        titel: "Oder NFC-Tag scannen",
                        text: "Halt die Oberkante deines iPhones an den Aufkleber."
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
            // dieser View schon vor. Die ggf. abgelaufene Einheit liest und
            // quittiert das .task(id: UmschaltTick(...)) in der TimelineView
            // oben -- das laeuft beim ERSCHEINEN der View, nicht erst beim
            // ersten Tick, und deckt den Kalteinstieg damit genauso ab.
            // Deshalb reicht EIN Ort fuer diese Pruefung.
            .task {
                if let eingang = pendingTag.consume() { verarbeite(eingang) }
            }
            // Deckt die beiden anderen Faelle ab: ein Tag-Tap, waehrend die
            // App schon auf einem anderen Tab laeuft, UND -- der haeufigere
            // Fall -- waehrend das Mitglied schon auf Training ist, egal wie
            // tief in pfad verschachtelt. onChange feuert bei jeder Aenderung
            // von pendingTag.token, solange diese View im Baum haengt --
            // anders als .task/.onAppear haengt das nicht daran, ob der
            // Training-Tab gerade ausgewaehlt ist, und die Wurzel bleibt
            // gemountet, waehrend Ziele darueber gepusht werden.
            .onChange(of: pendingTag.eingang) { _, neu in
                guard neu != nil, let eingang = pendingTag.consume() else { return }
                verarbeite(eingang)
            }
            // Zweiter Ausloeser fuer die Neuauswertung von
            // sessions.aktiveSession() (siehe TimelineView oben): kehrt das
            // Mitglied aus dem Hintergrund zurueck, soll das sofort gelten,
            // nicht erst bei der naechsten 60-Sekunden-Kadenz. Es gibt sonst
            // keinen scenePhase-Beobachter im Projekt.
            .onChange(of: scenePhase) { _, neu in
                guard neu == .active else { return }
                neuAuswerten.toggle()
            }
            // Der Satz zur ausgelaufenen Einheit gehoert zu GENAU EINER
            // abgelaufenen Einheit (M1): sobald wieder eine laufende Einheit
            // entsteht -- egal ob durch einen neuen Satz oder weil beenden()
            // ihn schon zurueckgesetzt hat --, gilt er nicht mehr.
            .onChange(of: sessions.aktiveSession() != nil) { _, laeuft in
                if laeuft { zeigeAusgelaufenHinweis = false }
            }
            // Ein gescheiterter NFC-Scan landet im selben Banner wie ein
            // gescheiterter QR-Scan. Der Leser haelt seinen Fehler getrennt,
            // weil er auch aus dem Scanner-Sheet heraus benutzt wird -- hier
            // wird er in den einen Ort ueberfuehrt, den der Screen anzeigt.
            .onChange(of: nfcLeser.fehler) { _, neu in
                if let neu { scanFehler = neu }
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

        // Abweichung vom Artboard TrainingLeer.dc.html: dort tragen eine
        // grosse NFC-Zeichnung und die Ueberschrift "HALT DEIN IPHONE AN DEN
        // AUFKLEBER" den leeren Zustand. Beides ist raus, seit es einen
        // echten NFC-Knopf gibt: die Zeichnung war die Anleitung fuer einen
        // Weg, den man nicht antippen konnte, und eine Anleitung neben dem
        // Knopf, den sie beschreibt, ist nur noch Laerm.
        Text("Am Gerät klebt ein Aufkleber mit dem gymodo-Zeichen. Dein Training startet von selbst, sobald du den ersten Satz sicherst — es gibt keinen Startknopf.")
            .font(DesignSystem.Typography.fliesstext)
            .foregroundStyle(DesignSystem.Color.textMuted)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.s24)

        if zeigeAusgelaufenHinweis {
            InlineBanner(tone: .muted, message: "Dein letztes Training wurde automatisch beendet.")
        }

        // Direkt ueber der Aktionsgruppe, nicht dahinter (M3): ein Fehler
        // muss im Sichtfeld stehen, nicht unter der Falz.
        if let scanFehler {
            InlineBanner(tone: .danger, message: scanFehler)
        }

        VStack(spacing: DesignSystem.Spacing.s12) {
            scanWege
            // Abweichung vom Artboard: dort text-faint bei 12pt. Der Satz
            // traegt die Gleichwertigkeit von Scan und Antippen, die die
            // Optik allein nicht zeigt (SS11) -- das ist tragende
            // Information, und die faellt unter 15pt nicht unter textFaint
            // (designsystem.md SS2). Der zweite Halbsatz uebernimmt, was
            // vorher die geloeschte Ueberschrift trug: der Aufkleber
            // funktioniert auch, wenn die App gar nicht offen ist.
            Text("Auf jedem Aufkleber ist beides — antippen oder scannen, gleiches Ergebnis. Antippen geht auch, ohne dass die App offen ist.")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
    }

    /// Die zwei Wege, in beiden Zustaenden dieselben -- Kontur, keiner
    /// Akzentflaeche. Der leere Zustand hatte bis M1 gar keine Hauptaktion
    /// auf dem Bildschirm (die Anweisung lautete "halt dein iPhone an den
    /// Aufkleber"), der laufende hatte "Naechstes Geraet" als Akzent. Jetzt
    /// steht an beiden Stellen dasselbe Paar, und die eine Akzentflaeche pro
    /// Screen bleibt frei (designsystem.md SS2).
    private var scanWege: some View {
        ScanWege(
            beiQR: { scannerOffen = true },
            beiNFC: { nfcStarten() },
            // Ohne geladenen Prefetch gaebe es nichts zu waehlen. Ohne ein
            // aktives Studio (activeStudioId == nil, etwa direkt nach dem
            // Onboarding oder bei Mitgliedschaft in null Studios) liefert
            // GeraeteAuswahl.gruppen(studioId: nil) still leere Gruppen --
            // der Knopf fuehrte dann auf einen Screen, der aussieht, als
            // waere er kaputt.
            beiListe: (katalog.bootstrap == nil || katalog.activeStudioId == nil)
                ? nil
                : { pfad.append(.auswahl) }
        )
    }

    /// Der aktive NFC-Scan aus der App heraus. Sein Ergebnis geht durch
    /// dasselbe TagLink.token(fromScan:) wie ein QR-Code -- es gibt
    /// weiterhin nur EINEN Ort fuer diese Extraktion.
    private func nfcStarten() {
        scanFehler = nil
        nfcLeser.fehlerQuittieren()
        nfcLeser.starten { roh in
            oeffneToken(TagLink.token(fromScan: roh))
        }
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

        // Direkt ueber der Aktionsgruppe, nicht dahinter (M3): stand vor dem
        // Umbau zwischen Blockliste und Hauptknopf, ist beim Ausbau der
        // Fussgruppe versehentlich ganz nach unten gewandert. Ab etwa fuenf
        // Bloecken waere das unter der Falz -- ein Scanfehler mitten im
        // Training muss im Sichtfeld stehen.
        if let scanFehler {
            InlineBanner(tone: .danger, message: scanFehler)
        }

        VStack(spacing: DesignSystem.Spacing.s12) {
            // Die Beschriftung, die vorher auf dem einen Knopf stand. Sie
            // wird gebraucht: zwei gleich aussehende Scan-Knoepfe sagen fuer
            // sich genommen nicht, WOZU man hier scannt.
            Text("NÄCHSTES GERÄT")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            scanWege
            // Abgesetzt, damit "Training beenden" nicht als dritter,
            // gleichrangiger Knopf in der Reihe steht -- es beendet etwas,
            // die beiden darueber setzen es fort.
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
            .padding(.top, DesignSystem.Spacing.s8)
        }
    }

    private func laufendKopf(_ session: LokaleSession) -> some View {
        let geraeteAnzahl = Set(session.bloecke.map(\.machineId)).count
        let saetzeAnzahl = session.bloecke.flatMap(\.saetze).count
        return HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                HStack(spacing: DesignSystem.Spacing.s8) {
                    Circle()
                        .fill(DesignSystem.Color.textMuted)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    // Abweichung vom Artboard: dort accent fuer Punkt und
                    // Label. Die eine Akzentflaeche dieses Screens ist
                    // "Naechstes Geraet" (designsystem.md SS2, siehe Bericht).
                    Text("TRAINING LÄUFT")
                        .font(DesignSystem.Typography.label)
                        .tracking(1.5)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                // Gegen session.startedAt gerechnet, nicht gegen einen
                // mitgezaehlten Wert: ein gespeicherter Zeitpunkt ueberlebt
                // Hintergrund und Sperrbildschirm, ein Zaehler nicht --
                // dasselbe Muster wie der Resttimer aus Sub-Projekt 2.
                TimelineView(.periodic(from: .now, by: 1)) { zeit in
                    // Ohne .accessibilityLabel liest VoiceOver "23:41" mit
                    // hoher Wahrscheinlichkeit als Uhrzeit -- direkt ueber
                    // dem echten "seit 18:04" darunter. verstrichenGesprochen
                    // macht daraus "23 Minuten trainiert" (designsystem.md
                    // SS12, wie Zahlformat.gewichtGesprochen).
                    Text(Zahlformat.verstrichen(seit: session.startedAt, bis: zeit.date))
                        .font(.system(size: 40, weight: .black).monospacedDigit())
                        .foregroundStyle(DesignSystem.Color.text)
                        .accessibilityLabel(Zahlformat.verstrichenGesprochen(seit: session.startedAt, bis: zeit.date))
                }
                // M1-Spec SS5.6: es gibt keinen Startknopf. Ohne diesen Satz
                // wuesste niemand, warum ploetzlich ein Training laeuft.
                Text("seit \(Zahlformat.uhrzeit(session.startedAt))")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            Spacer()
            HStack(spacing: DesignSystem.Spacing.s16) {
                statistik(wert: geraeteAnzahl, label: "GERÄTE",
                          gesprochen: geraeteAnzahl == 1 ? "1 Gerät" : "\(geraeteAnzahl) Geräte")
                statistik(wert: saetzeAnzahl, label: "SÄTZE",
                          gesprochen: saetzeAnzahl == 1 ? "1 Satz" : "\(saetzeAnzahl) Sätze")
            }
        }
        // Fasst Kopf und Statistik zu EINEM gesprochenen Satz zusammen statt
        // vier Bruchstuecken (m4) -- unbedenklich hier, weil kein
        // Bedienelement in diesem Kopfbereich steckt, das dabei verschwinden
        // koennte (anders als in Sub-Projekt 2, wo .combine einen Knopf
        // verschluckt hat).
        .accessibilityElement(children: .combine)
    }

    private func statistik(wert: Int, label: String, gesprochen: String) -> some View {
        VStack(alignment: .trailing, spacing: DesignSystem.Spacing.s4) {
            Text("\(wert)")
                .font(.system(size: 21, weight: .black).monospacedDigit())
                .foregroundStyle(DesignSystem.Color.text)
            Text(label)
                .font(DesignSystem.Typography.label)
                .tracking(1)
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(gesprochen)
    }

    private var zirkelHinweis: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.s8) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
            // Abweichung vom Artboard: dort text-faint bei 12pt. Dieselbe
            // Begruendung wie beim Gleichwertigkeitssatz oben: dieser Satz
            // ist die einzige Stelle in der App, die den Zirkelweg aus
            // M1-Spec SS5.3 erklaert -- tragende Information, und die faellt
            // unter 15pt nicht unter textFaint (designsystem.md SS2).
            Text("Zweiter Durchgang? Tipp auf den Block statt neu zu scannen — du landest direkt beim nächsten Satz mit deinem Gewicht.")
                .font(.system(size: 12))
                .lineSpacing(3)
        }
        .foregroundStyle(DesignSystem.Color.textMuted)
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
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        // clipShape VOR overlay: umgekehrt schneidet die Maske die
        // aeussere Haelfte der Kontur weg und laesst eine halbe uebrig
        // (Vorlage: InlineBanner).
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(gemeldet ? DesignSystem.Color.warn : DesignSystem.Color.line,
                        lineWidth: gemeldet ? 1.5 : 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint("Öffnet das Gerät")
    }

    // MARK: - Navigation

    @ViewBuilder
    private func ziel(_ route: GeraetRoute) -> some View {
        switch route {
        case .auswahl:
            GeraeteAuswahlView { machineId in
                pfad.append(.erkannt(machineId: machineId, token: nil))
            }
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
        case .abschluss(let sessionId, let zusammenfassung):
            // "Fertig" nimmt den Pfad zur Wurzel zurueck (Aufgabenbrief):
            // pfad.removeAll() statt eines einzelnen pop, weil ein Zirkel-
            // Tap (oeffne(_:)) zwischen "Training beenden" und diesem Push
            // theoretisch keinen weiteren Eintrag hinterlaesst, aber ein
            // einzelnes removeLast waere trotzdem die falsche Annahme --
            // "Fertig" fuehrt IMMER zur Wurzel, nie nur einen Schritt
            // zurueck.
            TrainingAbschlussView(
                sessionId: sessionId,
                zusammenfassung: zusammenfassung,
                apiClient: apiClient,
                beiFertig: { pfad.removeAll() }
            )
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

    /// Was aus PendingTagStore herauskommt, an einer Stelle beantwortet.
    ///
    /// Der ungueltige Fall ist neu: bis M1 verwarf FitnessMemberApp so eine
    /// URL still, und die App startete wortlos auf dem Home-Tab -- von
    /// aussen ununterscheidbar davon, dass der Link nie ankam. Er bekommt
    /// dieselbe neutrale Antwort wie ein unbekannter Tag (M1-Spec SS10.4).
    private func verarbeite(_ eingang: PendingTagStore.Eingang) {
        switch eingang {
        case .token(let token):
            oeffneToken(token)
        case .ungueltig:
            TagProtokoll.log.error("Eingang ungueltig -- neutrale Meldung auf Training")
            neuladeVersuch?.cancel()
            scanFehler = "Dieser Code ist nicht aktiv. Frag im Studio nach."
        }
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
        TagProtokoll.log.info("Token wird aufgeloest")
        // Kein frueher `guard let bootstrap ... else { return }` mehr: der
        // Token ist an dieser Stelle schon aus dem PendingTagStore
        // verbraucht, ein stilles return haette ihn endgueltig verloren --
        // genau dann, wenn der Katalog beim Kalteinstieg noch nicht im
        // Speicher ist. Fehlt der Prefetch, geht der Aufruf stattdessen in
        // denselben Neulade-und-Retry-Pfad wie ein Geraet, das erst nach
        // dem letzten Prefetch dazukam.
        guard let bootstrap = katalog.bootstrap,
              let maschine = MachineResolver.maschine(fuerToken: token, in: bootstrap) else {
            // Einmal neu laden, dann erneut versuchen -- sonst dieselbe
            // neutrale Antwort wie serverseitig fuer unbekannt/gesperrt.
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
                    TagProtokoll.log.error("Token auch nach Neuladen keinem Geraet zugeordnet")
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
        TagProtokoll.log.info("Geraet aufgeloest, Navigation folgt")
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
        else {
            // Der Knopf sah bedienbar aus -- "laufend" stand auf dem
            // Bildschirm --, aber die Einheit ist zwischen dem letzten
            // Neuzeichnen und diesem Tap verschwunden, meist weil die
            // Vier-Stunden-Grenze waehrend einer laengeren Pause im
            // Vordergrund ablief (M2). "Nie stumm": das Mitglied muss
            // erfahren, was jetzt gilt, nicht nur, dass der Tap wirkungslos
            // war. sessions.beenden() raeumt unbedingt auf -- anders als
            // ausgelaufeneQuittieren() auch dann, wenn die Einheit technisch
            // noch als aktiv gilt, aber ohne Saetze keine Zusammenfassung
            // hergibt.
            zeigeAusgelaufenHinweis = true
            sessions.beenden()
            return
        }
        // Der Satz zur ausgelaufenen Einheit gehoert zu GENAU EINER
        // abgelaufenen Einheit (M1): mit dem manuellen Beenden hier gilt er
        // nicht mehr.
        zeigeAusgelaufenHinweis = false
        // Erst festhalten, dann beenden -- andersherum sind die Zahlen weg,
        // bevor der Screen sie zeigt.
        sessions.beenden()
        pfad.append(.abschluss(sessionId: session.id, zusammenfassung: zusammenfassung))
    }
}

/// Die ID fuer .task(id:) an der Umschalt-TimelineView (siehe body oben):
/// aendert sich sowohl bei jedem 60-Sekunden-Tick als auch bei jedem
/// scenePhase-Ausloeser, damit die Erklaerung zur ausgelaufenen Einheit
/// beide Wege erreicht, nicht nur den Tick.
private struct UmschaltTick: Equatable {
    let datum: Date
    let wach: Bool
}
