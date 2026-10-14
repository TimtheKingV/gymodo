import SwiftUI

/// Leer und laufend sind kein zweiter Screen, sondern zwei Zustaende
/// derselben Wurzel (TrainingLeer.dc.html / TrainingLaeuft.dc.html). Seit
/// Schnitt 2 teilen sie sich EIN Geruest aus Mitte und Fuss -- der Titel
/// gehoert nur noch zum leeren Zustand, im laufenden nimmt der Kopf
/// ("TRAINING LAEUFT" + Uhr) an derselben Stelle seinen Platz ein.
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
    #if DEBUG
    @Environment(SensorAufnahmeKoordinator.self) private var sensorAufnahme
    #endif
    @Environment(\.scenePhase) private var scenePhase

    let apiClient: APIClient

    @State private var pfad: [GeraetRoute] = []
    @State private var scannerOffen = false
    @State private var scanFehler: String?
    /// Lebt an der Wurzel, nicht in GeraeteAuswahlView: "Geraet waehlen"
    /// wird bei jedem Geraet neu aufgemacht (Suchen -> zurueck -> naechstes
    /// Geraet -> Suchen), und eine signierte Foto-URL ist bei jedem Oeffnen
    /// eine andere. Ohne diesen einen Lader wuerde jedes erneute Oeffnen
    /// dieselben Originalfotos nochmal herunterladen, obwohl die
    /// dekodierten Vorschaubilder schon vorliegen.
    @State private var vorschauLader = VorschauLader(ablage: .fotos)
    /// Die Videoquellen fuer Liste, Geraeteseite und Satzseite (Testnotiz
    /// 11.10., #1, #5, #7). Lebt seit #2 der Sitzung 12:10 an der App,
    /// weil auch Home sie zeigt.
    @Environment(UebungsVideoVorrat.self) private var videoVorrat
    /// Der aktive NFC-Scan. Liegt hier und nicht in ScanWege, weil sein
    /// Ergebnis in dieselbe Aufloesung muendet wie der QR-Scan -- und weil
    /// eine laufende Sitzung einen zweiten Tap ueberstehen muss.
    @State private var nfcLeser = NFCTagLeser()
    /// Der laufende Beitrittsversuch aus oeffneToken(_:) (joinStudio laedt
    /// danach neu), falls gerade einer offen ist. Ohne dieses Handle
    /// wuerden zwei schnelle Scans zwei nebenlaeufige Tasks erzeugen, die beide spaeter scanFehler
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
    /// Der kurze Hinweis ueber den Scan-Knoepfen: "Training beenden" ohne
    /// Satz verwirft die Einheit, und der Tap soll eine lesbare Wirkung
    /// haben (Entschieden 2). Seit der Testnotiz 11.10. (#8) ein Toast, der
    /// von selbst geht, statt eines Banners bis zum Verlassen der Wurzel.
    /// Den Satz "automatisch beendet" gibt es nicht mehr (#9): das Ende
    /// nach vier Stunden passiert still im Hintergrund.
    @State private var toast: Toastmeldung?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Der Dialog "Pausieren / Training beenden" (Testnotiz 05.10., #7).
    @State private var steuerungOffen = false
    /// Die gewaehlte Uebung, fuer die der Drawer offen steht (Testnotiz
    /// 11.10., #6, #10, #11). An der Wurzel, weil er ueber Liste UND
    /// Geraeteseite liegen muss.
    @State private var uebungsstart: UebungsstartAuftrag?
    /// "Training in {Ort} beenden?" nach einem Scan oder einer Auswahl an
    /// einem anderen Ort (Plan, Entscheidung 2) -- derselbe Dialog wie im Profil.
    @State private var scanRueckfrage: ScanRueckfrage?
    /// Was nach dem Beenden fuer den Ortswechsel geoeffnet wird. Wartet auf
    /// den onChange unten: der leert den Pfad, sobald die Einheit endet, und
    /// raeumte ein sofort geoeffnetes Geraet gleich wieder ab.
    @State private var nachOrtswechsel: ScanFolge?
    /// Nach einem Aushang-Scan steht der Studiohinweis auch hier, nicht nur
    /// auf Home -- wer im Training scannt, schaut nicht auf Home.
    @State private var beitrittZeigen = false

    var body: some View {
        NavigationStack(path: $pfad) {
            // Die Kadenz von 60 s zwingt body dazu, sessions.aktiveSession()
            // periodisch neu auszuwerten. @Observable zeichnet sonst nur bei
            // einer Aenderung von gespeicherteSession neu -- beim Ablauf der
            // Vier-Stunden-Frist aendert sich dort nichts, und ohne diese
            // TimelineView bliebe der Screen auf "laufend" stehen, obwohl die
            // Einheit laengst ausgelaufen ist (M2). Die sekundengenaue Uhr im
            // laufenden Zustand hat ihre EIGENE, innere TimelineView weiter
            // unten -- diese hier betrifft nur die Umschaltung.
            TimelineView(.periodic(from: .now, by: 60)) { context in
                // Ein Geruest fuer beide Zustaende: die Geraeteliste "Gerät
                // wählen" ist der Tab selbst (Testnotiz 06.10., #2, #13). Im
                // laufenden Training stehen Uhr und die schon gemachten
                // Uebungen ueber den Geraeten und scrollen mit ihnen. Die
                // Scanwege schweben unten, in beiden Zustaenden an derselben
                // Stelle in der Daumenzone (Sammelstelle Punkt 3 und 8).
                let session = sessions.aktiveSession()
                let mitte = TrainingTab.mitte(session)
                wurzel(mitte: mitte, session: session)
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
                // gespeicherte Einheit noch existiert, mindestens einen Satz
                // hat UND aktiveSession() wegen Zeitablauf nil ist -- das
                // unterscheidet den selbsttaetigen Ablauf sauber von einem
                // manuellen "Training beenden": beenden() nullt
                // gespeicherteSession bereits VOR dem naechsten Tick,
                // abgelaufeneSession() liefert dann nichts mehr (sonst waere
                // M1 wieder da). Nach dem ersten Treffer ist
                // gespeicherteSession geloescht, jeder weitere Tick liefert
                // deshalb von selbst nichts mehr -- ohne eigenes Merker-Flag
                // genau einmal. Deckt zugleich den
                // Kalteinstieg ab -- aber ueber das ERSCHEINEN, nicht
                // ueber einen Tick: .task(id:) laeuft, sobald die View
                // im Baum auftaucht, und danach bei jeder Aenderung
                // der ID. Wer die ID spaeter gegen etwas tauscht, das
                // nicht am Erscheinen haengt, verliert damit den
                // Kalteinstieg -- und das gesonderte .task unten
                // braucht die Pruefung deswegen nicht.
                .task(id: UmschaltTick(datum: context.date, wach: neuAuswerten)) {
                    // Eine ausgelaufene Einheit wird still geraeumt, mit oder
                    // ohne Satz -- kein Hinweis im Nachhinein (Testnotiz
                    // 11.10., #9).
                    sessions.ausgelaufeneQuittieren()
                }
            }
            .background(DesignSystem.Color.bg)
            .testnotizScreen()
            .trainingSteuerung(
                istOffen: $steuerungOffen,
                pausiert: sessions.aktiveSession()?.istPausiert ?? false,
                beiPauseUmschalten: pauseUmschalten,
                beiBeenden: beenden)
            // .id(route): ersetzt navigiere(zu:) den Pfad in einem Zug, landet
            // die neue Route an derselben Stelle wie die alte -- ohne eigene
            // Identitaet behielte der Screen dort sein @State-Modell und zeigte
            // weiter das alte Geraet (Sichtcheck Task 11, Scan auf dem
            // Geraete-Screen eines anderen Orts).
            // Der Vorrat zweimal: einmal fuer die Wurzel selbst, einmal je
            // Ziel -- gepushte Screens erben die Umgebung des
            // NavigationStack, nicht die seines Wurzelinhalts.
            .navigationDestination(for: GeraetRoute.self) { route in
                ziel(route).id(route).environment(videoVorrat)
            }
            .environment(videoVorrat)
            .sheet(item: $uebungsstart) { auftrag in
                if let modell = modell(station: auftrag.station, exerciseId: auftrag.exerciseId,
                                       token: auftrag.token) {
                    UebungsstartSheet(modell: modell, beiStart: { werte in
                        uebungStarten(auftrag, mit: werte)
                    }, beiSchliessen: { uebungsstart = nil })
                    .environment(videoVorrat)
                }
            }
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
            // Ein neues Training macht den Hinweis zum verworfenen alten
            // gegenstandslos, auch wenn seine drei Sekunden noch laufen.
            .onChange(of: sessions.aktiveSession() != nil) { vorher, laeuft in
                if laeuft { toast = nil }
                // Endet die Einheit von aussen (Ortswechsel im Profil), darf
                // kein Geraete-Screen vom alten Ort stehen bleiben.
                if Pfadbereinigung.leeren(laeuftVorher: vorher, laeuftJetzt: laeuft, pfad: pfad) {
                    pfad.removeAll()
                }
                // Erst nach dem Leeren: das Geraet am neuen Ort bleibt stehen.
                if !laeuft, let folge = nachOrtswechsel {
                    nachOrtswechsel = nil
                    ausfuehren(folge)
                }
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
        // Am Stack, nicht an der Wurzel: ein Aufkleber-Tap kommt auch, waehrend
        // ein Geraete-Screen gepusht ist, und ein Dialog an der verdeckten
        // Wurzel erschien erst nach dem Zuruecknavigieren (Sichtcheck Task 11).
        // Der Titel muss sichtbar sein -- er nennt den Ort der laufenden Einheit.
        .confirmationDialog(
            "Training in \(StudiosListe.name(fuer: scanRueckfrage?.laufenderOrt ?? katalog.ort, studios: katalog.bootstrap?.studios ?? [])) beenden?",
            isPresented: Binding(
                get: { scanRueckfrage != nil },
                set: { if !$0 { scanRueckfrageVerwerfen() } }
            ),
            titleVisibility: .visible,
            presenting: scanRueckfrage
        ) { rueckfrage in
            Button("Training beenden", role: .destructive) { beendenUndOeffnen(rueckfrage) }
            Button("Abbrechen", role: .cancel) { scanRueckfrageVerwerfen() }
        } message: { _ in
            Text("Danach wechselst du den Ort.")
        }
    }

    // MARK: - Wurzel

    /// Die Liste braucht den Prefetch; der Ort ist immer gesetzt, auch im
    /// Freien Training. Ohne Prefetch (etwa direkt nach dem Onboarding)
    /// steht der Titel "TRAINING" mit den Scanwegen da, wie vor dem Umbau.
    @ViewBuilder
    private func wurzel(mitte: TrainingTab.Mitte?, session: LokaleSession?) -> some View {
        if katalog.bootstrap != nil {
            GeraeteAuswahlView(fotoLader: apiClient, vorschauLader: vorschauLader) {
                if let mitte, let session {
                    laufendeMitte(mitte, session: session)
                }
            } beiAuswahl: { station, uebungId in
                waehle(station, uebungId: uebungId)
            } beiKachel: { kachel in
                switch GeraeteAuswahl.ziel(kachel) {
                case .station(let station): waehle(station)
                case .liste(let gruppe): pfad.append(.kategorie(gruppe))
                }
            }
            // safeAreaInset statt overlay: die Liste bekommt unten so viel
            // Luft, dass ihr letztes Geraet ueber den Knoepfen landet, und
            // scrollt trotzdem unter ihnen durch -- die Knoepfe schweben.
            .safeAreaInset(edge: .bottom) { fuss }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                titel
                    .padding(.horizontal, 20)
                    .padding(.top, DesignSystem.Spacing.s24)
                if let mitte, let session {
                    laufendeMitte(mitte, session: session)
                        .padding(.horizontal, 20)
                        .padding(.top, DesignSystem.Spacing.s16)
                }
                Spacer(minLength: 0)
                fuss
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var titel: some View {
        Text("TRAINING")
            .font(DesignSystem.Typography.screentitel)
            .tracking(-1)
            .foregroundStyle(DesignSystem.Color.text)
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

    // MARK: - Fuss (beide Zustaende)

    /// Banner und die beiden Scanwege, schwebend ueber der Liste. Die
    /// Banner stehen direkt ueber den Knoepfen, nicht dahinter (M3): ein
    /// Fehler muss im Sichtfeld stehen, nicht unter der Falz. "Suchen" und
    /// die Ueberschrift "Training starten" sind weg -- die Liste darueber
    /// ist die Suche (Testnotiz 06.10., #2, #13). "NÄCHSTES GERÄT" steht
    /// jetzt ueber der Liste, nicht ueber den Knoepfen.
    private var fuss: some View {
        VStack(spacing: DesignSystem.Spacing.s12) {
            if let toast {
                Toast(meldung: toast) { self.toast = nil }
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
            if let scanFehler {
                InlineBanner(tone: .danger, message: scanFehler)
            }
            if beitrittZeigen, let studiohinweis = katalog.studiohinweis {
                InlineBanner(tone: .muted, message: studiohinweis.text)
            }
            ScanWege(beiQR: { scannerOffen = true }, beiNFC: { nfcStarten() })
                .testnotizElement("training.scanwege", typ: "ScanWege")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, DesignSystem.Spacing.s12)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: toast)
    }

    // MARK: - Laufende Mitte (TrainingLaeuft.dc.html)

    /// Kopf und die schon gemachten Uebungen -- ueber der Geraeteliste,
    /// mit der sie scrollen (Testnotiz 06.10., #13). Bis dahin hatte die
    /// laufende Mitte eine eigene ScrollView zwischen festem Kopf und
    /// festem Fuss; jetzt traegt die Liste darunter das Scrollen, und die
    /// Scanwege schweben ohnehin immer in der Daumenzone.
    private func laufendeMitte(_ mitte: TrainingTab.Mitte, session: LokaleSession) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            laufendKopf(mitte, session: session)
                .padding(.bottom, DesignSystem.Spacing.s8)

            ForEach(TrainingTab.zuletztZuerst(session.bloecke)) { block in
                Button { oeffne(block) } label: { blockZeile(block) }
                    .buttonStyle(PressButtonStyle())
            }
            // Vor dem ersten Satz (seit Schnitt 4 moeglich) gibt es
            // keinen Block zum Antippen -- der Satz zum Zirkel waere
            // ein Raetsel.
            if !session.bloecke.isEmpty { zirkelHinweis }

            // Ohne Ueberschrift stuende die Geraeteliste direkt unter den
            // eigenen Uebungen und laese sich wie deren Fortsetzung.
            Text("NÄCHSTES GERÄT")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .padding(.top, DesignSystem.Spacing.s16)
        }
    }

    /// Oben die Zeile "TRAINING LÄUFT" mit dem Pausenknopf rechts, darunter
    /// Uhr und Zahlen. Der Knopf oeffnet "Pausieren / Training beenden"
    /// (Testnotiz 05.10., #7); pausiert zeigt er "Fortsetzen" an.
    private func laufendKopf(_ mitte: TrainingTab.Mitte, session: LokaleSession) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            HStack(spacing: DesignSystem.Spacing.s8) {
                Laufpunkt(pausiert: session.istPausiert)
                // Der Punkt traegt den Akzent und pulsiert (Testnotiz
                // 05.10., #9). Frueher war er grau, weil der Akzent
                // "Training beenden" gehoerte -- den Knopf gibt es hier
                // nicht mehr.
                Text(session.istPausiert ? "TRAINING PAUSIERT" : "TRAINING LÄUFT")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                Spacer()
                pauseKnopf(pausiert: session.istPausiert)
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    TrainingsuhrText(session: session, font: .system(size: 40, weight: .black))
                    // Der Beginn ist seit Schnitt 4 der Tap auf "Training
                    // starten". Die Zeile bleibt: eine Uhr ohne Anker ("23:41 --
                    // seit wann?") sagt nichts.
                    Text("seit \(Zahlformat.uhrzeit(mitte.startedAt))")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                // Fasst Uhr und Beginn zu EINEM gesprochenen Satz zusammen
                // (m4). Der Pausenknopf steht bewusst ausserhalb: .combine
                // verschluckte ihn sonst (wie in Sub-Projekt 2).
                .accessibilityElement(children: .combine)
                Spacer()
                // Ohne Satz gibt es keine bestaetigte Zahl -- also auch keine
                // Geraete- und Satzzahl -- mitte.zahlen ist dann nil, und die
                // rechte Spalte entfaellt ganz statt eine Null zu zeigen.
                if let zahlen = mitte.zahlen {
                    HStack(spacing: DesignSystem.Spacing.s16) {
                        statistik(wert: zahlen.geraete, label: "GERÄTE",
                                  gesprochen: zahlen.geraete == 1 ? "1 Gerät" : "\(zahlen.geraete) Geräte")
                        statistik(wert: zahlen.saetze, label: "SÄTZE",
                                  gesprochen: zahlen.saetze == 1 ? "1 Satz" : "\(zahlen.saetze) Sätze")
                    }
                }
            }
        }
    }

    /// Kontur statt Flaeche: Pausieren ist keine Hauptaktion, und ein
    /// Akzentknopf im Kopf zoege den Blick von der Liste ab.
    private func pauseKnopf(pausiert: Bool) -> some View {
        Button { steuerungOffen = true } label: {
            Image(systemName: pausiert ? "play.fill" : "pause.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DesignSystem.Color.text)
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(DesignSystem.Color.line, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(PressButtonStyle())
        .testnotizElement("training.pause", typ: "Button")
        .accessibilityLabel(pausiert ? "Training fortsetzen oder beenden" : "Training pausieren oder beenden")
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
            // Abweichung vom Artboard: dort text-faint bei 12pt. Dieser Satz
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
        // Ueber die Station statt nur die Geraete: ein Block am Typ traegt
        // keine machineId und bliebe sonst ohne Namen.
        let station = katalog.bootstrap?.station(schluessel: block.stationSchluessel,
                                                 studioId: katalog.activeStudioId)
        let uebung = station?.exercises.first { $0.id == block.exerciseId }
        let gemeldet = block.saetze.contains(where: \.problemFlag)
        return HStack(spacing: DesignSystem.Spacing.s12) {
            // Das Sinnbild der Uebung links vom Namen (Testnotiz 06.10.,
            // #14) -- seit 11.10. (#1) ihr Video in Schleife, der
            // Platzhalter bleibt darunter, bis es da ist.
            UebungsVideoKachel(exerciseId: block.exerciseId, kante: 48) {
                Uebungsbild(kante: 48)
            }
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text([station?.equipmentModel.name, uebung?.name]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                HStack(spacing: DesignSystem.Spacing.s8) {
                    Text(TrainingTab.blockzeile(block))
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
        .padding(DesignSystem.Spacing.s12)
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
        case .kategorie(let gruppe):
            GeraeteAuswahlView(fotoLader: apiClient, vorschauLader: vorschauLader, gruppe: gruppe) { station, uebungId in
                waehle(station, uebungId: uebungId)
            }
        case .erkannt(let station, let token):
            if let modell = modell(station: station, exerciseId: nil, token: token) {
                GeraetErkanntScreen(modell: modell) { uebungId in
                    uebungsstart = UebungsstartAuftrag(station: station, exerciseId: uebungId, token: token)
                }
            }
        case .geraet(let station, let exerciseId, let token, let start):
            if let modell = modell(station: station, exerciseId: exerciseId, token: token, startwerte: start) {
                GeraetScreen(modell: modell, beiZurueckZumTraining: { pfad.removeAll() },
                             beiTrainingBeenden: beenden)
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

    private func modell(station schluessel: String, exerciseId: String?, token: String?,
                        startwerte: Startwerte? = nil) -> GeraetModel? {
        // Ein Typ hat keinen eigenen Ort: die Route traegt nur den
        // Schluessel, und er gilt am aktuellen Ort. Deshalb wechselt jeder Weg
        // hierher (Scan, Liste) den Ort VOR dem Oeffnen, und eine offene
        // Einheit erzwingt ueber Ortswechsel denselben Ort.
        guard let bootstrap = katalog.bootstrap,
              let station = bootstrap.station(schluessel: schluessel, studioId: katalog.activeStudioId)
        else { return nil }
        // Vorauswahl: zuletzt genutzte Uebung, sonst die erste aus der vom
        // Studio gepflegten Reihenfolge (M1-Spec SS5.7).
        let zuletzt = GeraetEinstiegRechner.letzteUebung(station: schluessel, in: bootstrap)
        let gewaehlt = exerciseId ?? zuletzt ?? station.exercises.first?.id
        guard let gewaehlt else { return nil }
        // Im Release gibt es keinen Mitschnitt; im Debug-Build ist es der
        // Sensor-Koordinator.
        var mitschnitt: (any SatzMitschnitt)?
        #if DEBUG
        mitschnitt = sensorAufnahme
        #endif
        return GeraetModel(
            station: station, uebungId: gewaehlt, token: token,
            bootstrap: bootstrap, loader: apiClient, sessions: sessions,
            enqueue: { katalog.enqueue($0); Task { await katalog.flushPending() } },
            mitschnitt: mitschnitt,
            startwerte: startwerte
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
    /// sofort rendern (M1-Spec SS8.1 Schritt 3). Was daraus folgt, steht in
    /// ScanEntscheidung; hier wird nur ausgefuehrt.
    ///
    /// Ein vorheriger Beitrittsversuch wird immer zuerst storniert: sonst
    /// koennte ein noch laufender Versuch aus einem AELTEREN Scan spaeter
    /// fertig werden als dieser Aufruf und dessen Ergebnis -- Navigation
    /// oder Fehlermeldung -- ueberschreiben.
    private func oeffneToken(_ token: String) {
        scanFehler = nil
        beitrittZeigen = false
        neuladeVersuch?.cancel()
        TagProtokoll.log.info("Token wird aufgeloest")
        switch ScanEntscheidung.fuer(token: token, bootstrap: katalog.bootstrap, ort: katalog.ort,
                                     offeneEinheit: sessions.aktiveSession()) {
        case .oeffnen(let station):
            navigiere(zu: station, token: token)
        case .wechselnUndOeffnen(let ziel, let station):
            katalog.setOrt(ziel)
            navigiere(zu: station, token: token)
        case .erstBeenden(let laufenderOrt, let ziel, let station):
            scanRueckfrage = ScanRueckfrage(laufenderOrt: laufenderOrt, ziel: ziel,
                                            folge: .oeffnen(station, token: token), beitritt: nil)
        case .beitreten:
            // Auch ohne Prefetch (Kalteinstieg): joinStudio laedt danach neu,
            // und ein Geraet aus dem eigenen Studio, das erst nach dem letzten
            // Prefetch dazukam, kommt so ebenfalls an.
            beitreten(token)
        }
    }

    /// Ein Code, den der Prefetch nicht kennt, macht zum Mitglied seines
    /// Studios -- der Beitritt passiert immer (Plan, Entscheidung 2). Den
    /// Ort wechselt erst die Entscheidung danach: sofort, oder nach
    /// "Training beenden". Bis dahin bleibt der alte Ort auch gespeichert --
    /// wird die App waehrend der Rueckfrage beendet, gilt nichts Halbes.
    private func beitreten(_ token: String) {
        neuladeVersuch = Task {
            let ergebnis: JoinResult
            do throws(APIError) {
                ergebnis = try await katalog.joinStudio(byTag: token)
            } catch {
                // Ein Abbruch bedeutet: ein neuerer Scan oder das
                // Verschwinden der View hat diesen Versuch bereits ersetzt.
                guard !Task.isCancelled else { return }
                TagProtokoll.log.error("Token keinem Geraet zugeordnet, kein Beitritt")
                scanFehler = ScanEntscheidung.fehlertext(error)
                return
            }
            guard !Task.isCancelled else { return }
            switch ScanEntscheidung.nachBeitritt(ergebnis, bootstrap: katalog.bootstrap, ort: katalog.ort,
                                                 offeneEinheit: sessions.aktiveSession()) {
            case .oeffnen(let station):
                katalog.ortNachBeitritt(ergebnis)
                navigiere(zu: station, token: token)
            case .listeZeigen:
                katalog.ortNachBeitritt(ergebnis)
                listeZeigen()
            case .erstBeenden(let laufenderOrt, let station):
                scanRueckfrage = ScanRueckfrage(
                    laufenderOrt: laufenderOrt, ziel: .studio(ergebnis.studioId),
                    folge: station.map { .oeffnen($0, token: token) } ?? .liste, beitritt: ergebnis)
            }
        }
    }

    /// Ein Aushang nennt kein Geraet: die Liste des neuen Studios ist die
    /// Wurzel, dazu der Hinweis, wem man jetzt angehoert.
    private func listeZeigen() {
        pfad.removeAll()
        beitrittZeigen = true
    }

    /// Eine Station aus der Liste nimmt denselben Weg wie ein Scan: steht
    /// sie an einem anderen Ort ("Auch in X suchen"), wird erst gewechselt
    /// oder gefragt, dann geoeffnet.
    /// `uebungId`: ein Uebungstreffer der Suche -- dann direkt diese Uebung.
    private func waehle(_ station: Station, uebungId: String? = nil) {
        switch ScanEntscheidung.fuer(station: station, ort: katalog.ort,
                                     offeneEinheit: sessions.aktiveSession()) {
        case .oeffnen(let station):
            oeffneAusListe(station, uebungId: uebungId)
        case .wechselnUndOeffnen(let ziel, let station):
            katalog.setOrt(ziel)
            oeffneAusListe(station, uebungId: uebungId)
        case .erstBeenden(let laufenderOrt, let ziel, let station):
            scanRueckfrage = ScanRueckfrage(laufenderOrt: laufenderOrt, ziel: ziel,
                                            folge: .auswahl(station, uebungId: uebungId), beitritt: nil)
        case .beitreten:
            // Kommt aus der Liste nicht vor: sie kennt nur Stationen aus dem
            // Bootstrap.
            break
        }
    }

    private func oeffneAusListe(_ station: Station, uebungId: String? = nil) {
        // Ein Uebungstreffer der Suche oeffnet genau diese Uebung, ueber den
        // Drawer wie jeder Direktweg -- die Geraeteseite haette nur noch
        // einmal gefragt, was schon gesucht war (Testnotiz 14.10., 18:45 #2).
        if let uebungId {
            uebungsstart = UebungsstartAuftrag(station: station.schluessel, exerciseId: uebungId, token: nil)
            return
        }
        // Besuche 0: aus der Liste bleibt die Uebungswahl wie bisher
        // sichtbar -- nur ein Geraet mit einer einzigen Uebung springt
        // direkt, wie beim Scan (Testnotiz 11.10., #4).
        oeffne(station, token: nil, besuche: 0)
    }

    private func ausfuehren(_ folge: ScanFolge) {
        switch folge {
        case .oeffnen(let station, let token): navigiere(zu: station, token: token)
        case .auswahl(let station, let uebungId): oeffneAusListe(station, uebungId: uebungId)
        case .liste: listeZeigen()
        }
    }

    /// Lokal sofort, Server im Hintergrund, kein Abschluss-Screen -- genau
    /// wie der Ortswechsel in der Studioliste: das Mitglied wollte an den
    /// neuen Ort, nicht auf einen Rueckblick.
    private func beendenUndOeffnen(_ rueckfrage: ScanRueckfrage) {
        scanRueckfrage = nil
        let lief = sessions.aktiveSession() != nil
        let ende = sessions.beendenFuerOrtswechsel()
        // Nach einem Beitritt nennt der Hinweis den Beitritt, nicht den Wechsel.
        if let beitritt = rueckfrage.beitritt {
            katalog.ortNachBeitritt(beitritt)
        } else {
            katalog.setOrt(rueckfrage.ziel)
        }
        let client = apiClient
        Task { await WorkoutSessionStore.melden(ende, loader: client) }
        // Lief die Einheit gar nicht mehr (in genau diesem Moment
        // ausgelaufen), kommt kein onChange -- dann sofort.
        if lief { nachOrtswechsel = rueckfrage.folge } else { ausfuehren(rueckfrage.folge) }
    }

    /// Abbrechen laesst alles, wie es war -- bis auf die Mitgliedschaft: der
    /// Beitritt hat den Ort nicht gewechselt, also gibt es nichts
    /// zurueckzunehmen.
    private func scanRueckfrageVerwerfen() {
        scanRueckfrage = nil
    }

    private func navigiere(zu station: Station, token: String) {
        // Ein neu gescannter Tag ERSETZT einen offenen Geraete-Screen, statt
        // sich davor zu stapeln -- M1-Spec SS5.1 will "ein Ort fuer alles,
        // was am Geraet passiert", keinen Turm aus Screens fuer nacheinander
        // gescannte Geraete. Der legitime Zweifach-Push GeraetErkannt ->
        // GeraetView bleibt unberuehrt: er haengt in ziel(_:) an derselben,
        // gerade erst geleerten Wurzel und wird hier nicht ausgeloest.
        pfad.removeAll()
        guard let bootstrap = katalog.bootstrap else { return }
        TagProtokoll.log.info("Geraet aufgeloest, Navigation folgt")
        // Besuche kennt nur das Geraet; ein Typ zaehlt wie ein erster Besuch.
        let besuche = station.machineId.flatMap { id in
            bootstrap.machines.first { $0.id == id }?.visitCount
        } ?? 0
        oeffne(station, token: token, besuche: besuche)
    }

    /// Geraeteseite oder Direktsprung -- ein Weg fuer Liste und Scan, damit
    /// beide fuer dasselbe Geraet dasselbe tun.
    private func oeffne(_ station: Station, token: String?, besuche: Int) {
        guard let bootstrap = katalog.bootstrap else { return }
        let genutzte = GeraetEinstiegRechner.genutzteUebungen(station: station.schluessel, in: bootstrap)
        switch GeraetEinstiegRechner.einstieg(visitCount: besuche, genutzteUebungen: genutzte,
                                              uebungsanzahl: station.exercises.count) {
        case .erkannt:
            pfad.append(.erkannt(station: station.schluessel, token: token))
        case .direktZumSatz:
            let uebung = GeraetEinstiegRechner.letzteUebung(station: station.schluessel, in: bootstrap)
                ?? station.exercises.first?.id
            guard let uebung else { return }
            // Auch der Direktweg geht ueber den Drawer: dort startet "Übung
            // starten" ein noch nicht laufendes Training mit.
            uebungsstart = UebungsstartAuftrag(station: station.schluessel, exerciseId: uebung, token: token)
        }
    }

    /// "Übung starten" im Drawer: ein noch nicht laufendes Training
    /// beginnt jetzt, nicht schon mit der Einweisung (Testnotiz 06.10., #5;
    /// 11.10., #11). Die Satzseite kommt mit den Startwerten und beginnt
    /// mit dem Countdown.
    private func uebungStarten(_ auftrag: UebungsstartAuftrag, mit werte: Startwerte) {
        if sessions.aktiveSession() == nil { sessions.trainingStarten() }
        uebungsstart = nil
        pfad.append(.geraet(station: auftrag.station, exerciseId: auftrag.exerciseId,
                            token: auftrag.token, start: werte))
    }

    private func oeffne(_ block: LokalerBlock) {
        // Der Zirkelfall: ein Tap statt eines Scans (M1-Spec SS5.3).
        // Kein Drawer: die Blockliste gibt es nur, solange ein
        // Training laeuft. Geraet und Typ nehmen denselben Weg; nur ein
        // Block ohne beide Kennungen ("unbekannt:") hat kein Ziel.
        guard Station.art(schluessel: block.stationSchluessel) != nil else { return }
        pfad.append(.geraet(station: block.stationSchluessel, exerciseId: block.exerciseId, token: nil))
    }

    private func pauseUmschalten() {
        if sessions.aktiveSession()?.istPausiert == true {
            sessions.fortsetzen()
        } else {
            sessions.pausieren()
        }
    }

    /// Kommt vom Dialog -- auf dem Tab ODER aus dem Geraete-Screen
    /// (Testnotiz 05.10., #11). Deshalb ersetzt der Abschluss den Pfad,
    /// statt sich davorzulegen: "Zurueck" vom Abschluss fuehrte sonst in
    /// ein Geraet eines beendeten Trainings.
    private func beenden() {
        guard let session = sessions.aktiveSession(),
              let zusammenfassung = Trainingszusammenfassung(session)
        else {
            // Ohne Satz gibt es keinen Abschluss und nichts, was der Server
            // wissen muesste: die Einheit wird verworfen (Entschieden 2). Das
            // trifft seit Schnitt 4 den Regelfall "Training starten, dann doch
            // nicht" -- und weiterhin den seltenen, dass die Einheit zwischen
            // Neuzeichnen und Tap ausgelaufen ist. sessions.beenden() raeumt
            // unbedingt, anders als ausgelaufeneQuittieren().
            toast = Toastmeldung(text: "Kein Satz gesichert — das Training wurde verworfen.")
            sessions.beenden()
            // Der Hinweis dazu steht im Fuss der Wurzel.
            pfad.removeAll()
            return
        }
        // Ein noch stehender Hinweis zu einer frueheren Einheit gilt mit dem
        // manuellen Beenden hier nicht mehr.
        toast = nil
        // Erst festhalten, dann beenden -- andersherum sind die Zahlen weg,
        // bevor der Screen sie zeigt.
        sessions.beenden()
        pfad = [.abschluss(sessionId: session.id, zusammenfassung: zusammenfassung)]
    }
}

/// Was nach "Training beenden" fuer einen Scan oder eine Auswahl an einem
/// anderen Ort folgt.
private enum ScanFolge: Equatable {
    case oeffnen(Station, token: String)
    /// Aus der Liste gewaehlt: ohne Token, ohne Einstiegsregel des Scans.
    case auswahl(Station, uebungId: String?)
    /// Aushang: kein Geraet, die Liste des Studios.
    case liste
}

/// Die offene Rueckfrage "Training in {Ort} beenden?" nach einem Scan oder
/// einer Auswahl.
private struct ScanRueckfrage: Equatable {
    let laufenderOrt: Ort
    let ziel: Ort
    let folge: ScanFolge
    /// Gesetzt nach einem Beitritt per Scan: der Wechsel nennt dann den
    /// Beitritt im Hinweis.
    let beitritt: JoinResult?
}

/// Die ID fuer .task(id:) an der Umschalt-TimelineView (siehe body oben):
/// aendert sich sowohl bei jedem 60-Sekunden-Tick als auch bei jedem
/// scenePhase-Ausloeser, damit das Raeumen der ausgelaufenen Einheit
/// beide Wege erreicht, nicht nur den Tick.
private struct UmschaltTick: Equatable {
    let datum: Date
    let wach: Bool
}
