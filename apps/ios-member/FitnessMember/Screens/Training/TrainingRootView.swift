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
    @State private var vorschauLader = VorschauLader()
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
    /// beenden() (manuelles Beenden mit Satz setzt nil, ohne Satz
    /// `.verworfen`). Er bleibt stehen, bis die Wurzel verlassen wird --
    /// ODER bis er selbst nicht mehr gilt: beenden() setzt ihn beim
    /// manuellen Beenden zurueck, der onChange unten zusaetzlich beim
    /// Uebergang in einen neuen laufenden Zustand. Der Satz gehoert zu
    /// GENAU EINER abgelaufenen Einheit, nicht zur View.
    @State private var hinweis: TabHinweis?

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
                // Ein Geruest fuer beide Zustaende: nur die Mitte haengt daran, ob
                // ein Training laeuft. Die Startwege stehen so immer an derselben
                // Stelle in der Daumenzone, statt beim ersten Satz von oben nach unten
                // zu springen (Sammelstelle Punkt 3 und 8).
                let session = sessions.aktiveSession()
                let mitte = TrainingTab.mitte(session)
                VStack(alignment: .leading, spacing: 0) {
                    if let mitte, let session {
                        laufendeMitte(mitte, session: session)
                    } else {
                        // Der Titel steht nur im leeren Zustand. Im laufenden
                        // uebernimmt der Kopf ("TRAINING LAEUFT" + Uhr) an
                        // derselben Stelle dessen Rolle -- auf 667-pt-iPhones
                        // (SE, weiterhin unter iOS 17 im Einsatz) reicht die
                        // Hoehe sonst nicht fuer Titel UND Kopf UND Liste UND
                        // Beenden-Gruppe UND Fuss, und der Liste bliebe kein
                        // Platz zum Schrumpfen.
                        titel
                            .padding(.horizontal, 20)
                            .padding(.top, DesignSystem.Spacing.s24)
                        // Leer heisst leer: keine Uhr auf null, kein Platzhaltersatz.
                        Spacer(minLength: 0)
                    }
                    fuss(laeuft: mitte != nil)
                        .padding(.horizontal, 20)
                        .padding(.bottom, DesignSystem.Spacing.s24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                    // Mit Satz bekommt die ausgelaufene Einheit den Satz im Fuss; ohne
                    // Satz liefert abgelaufeneSession() nichts, und sie wird still
                    // geraeumt (Entschieden 2). ausgelaufeneQuittieren() raeumt beide.
                    if sessions.abgelaufeneSession() != nil { hinweis = .ausgelaufen }
                    sessions.ausgelaufeneQuittieren()
                }
            }
            .background(DesignSystem.Color.bg)
            .testnotizScreen()
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
                if laeuft { hinweis = nil }
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

    // MARK: - Titel (nur leerer Zustand)

    private var titel: some View {
        Text("TRAINING")
            .font(DesignSystem.Typography.screentitel)
            .tracking(-1)
            .foregroundStyle(DesignSystem.Color.text)
    }

    /// Die drei Wege zum Geraet -- Kontur, keine Akzentflaeche. Der leere
    /// Zustand hatte bis M1 gar keine Hauptaktion auf dem Bildschirm (die
    /// Anweisung lautete "halt dein iPhone an den Aufkleber"), der laufende
    /// hatte "Naechstes Geraet" als Akzent. Seit Schnitt 2 rendert
    /// `fuss(laeuft:)` sie an EINER Stelle fuer beide Zustaende statt
    /// zweimal, und die eine Akzentflaeche pro Screen bleibt frei
    /// (designsystem.md SS2).
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
        .testnotizElement("training.scanwege", typ: "ScanWege")
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

    /// Banner, Ueberschrift, die drei Wege -- in beiden Zustaenden an derselben
    /// Stelle. Die Banner stehen direkt ueber der Aktionsgruppe, nicht dahinter
    /// (M3): ein Fehler muss im Sichtfeld stehen, nicht unter der Falz.
    @ViewBuilder
    private func fuss(laeuft: Bool) -> some View {
        VStack(spacing: DesignSystem.Spacing.s12) {
            if let hinweis {
                InlineBanner(tone: .muted, message: hinweis.text)
            }
            if let scanFehler {
                InlineBanner(tone: .danger, message: scanFehler)
            }
            if laeuft {
                // Zwei gleich aussehende Scan-Knoepfe sagen fuer sich genommen
                // nicht, WOZU man mitten im Training scannt.
                Text("NÄCHSTES GERÄT")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Abweichung vom Artboard TrainingLeer.dc.html: dort tragen eine
                // grosse NFC-Zeichnung und die Ueberschrift "HALT DEIN IPHONE AN DEN
                // AUFKLEBER" den leeren Zustand. Beides ist raus, seit es einen
                // echten NFC-Knopf gibt: die Zeichnung war die Anleitung fuer einen
                // Weg, den man nicht antippen konnte, und eine Anleitung neben dem
                // Knopf, den sie beschreibt, ist nur noch Laerm.
                //
                // Aus demselben Grund ist auch der erklaerende Fliesstext raus, der
                // hier stand: ueber der Knopfgruppe steht jetzt nur noch, WOZU sie
                // da ist.
                Text("Training starten")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.text)
                    .frame(maxWidth: .infinity)
            }
            scanWege
        }
    }

    // MARK: - Laufende Mitte (TrainingLaeuft.dc.html)

    /// Kopf, scrollende Geraeteliste, Beenden -- die Mitte des laufenden
    /// Zustands zwischen ihrem eigenen Kopf (er ersetzt den Titel) und dem
    /// gemeinsamen Fuss darunter.
    ///
    /// Bis zum Umbau war der ganze laufende Zustand EIN Scrollinhalt. Die
    /// Knoepfe standen damit hinter der Liste: wer sechs Geraete hatte,
    /// musste zum siebten erst scrollen -- und das mitten im Training, mit
    /// dem Handy in einer Hand. Jetzt wandert nur die Liste, Kopf und
    /// Beenden bleiben stehen.
    private func laufendeMitte(_ mitte: TrainingTab.Mitte, session: LokaleSession) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
            laufendKopf(mitte)
                .padding(.horizontal, 20)
                .padding(.top, DesignSystem.Spacing.s24)

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.s12) {
                    ForEach(TrainingTab.zuletztZuerst(session.bloecke)) { block in
                        Button { oeffne(block) } label: { blockZeile(block) }
                            .buttonStyle(PressButtonStyle())
                    }
                    // Vor dem ersten Satz (seit Schnitt 4 moeglich) gibt es
                    // keinen Block zum Antippen -- der Satz zum Zirkel waere
                    // ein Raetsel.
                    if !session.bloecke.isEmpty { zirkelHinweis }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, DesignSystem.Spacing.s12)
            }
            // Die Liste gibt nach, Kopf und Beenden nicht: bei einem Geraet
            // steht die Liste dicht unter dem Kopf, bei zehn scrollt sie.
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: DesignSystem.Spacing.s12) {
                // Die eine Akzentflaeche dieses Screens (designsystem.md SS2):
                // das Beenden ist die einzige Aktion hier, die etwas abschliesst
                // -- die Wege im Fuss darunter tragen den Akzent nur in der Kontur.
                PrimaryButton(title: "Training beenden") { beenden() }
                    .testnotizElement("training.beenden", typ: "PrimaryButton")
                // Zulaessig in textFaint: der Satz erklaert nur eine Alternative,
                // er traegt selbst nichts (designsystem.md SS2).
                //
                // fixedSize(vertical:): ohne das ist dieser Text das einzige
                // schrumpfbare Kind der Beenden-Gruppe, und auf dem SE (667 pt)
                // gibt die ScrollView darueber ihre Hoehe nicht her -- der Satz
                // wuerde auf eine Zeile mit Ellipse zusammengedrueckt statt
                // umzubrechen.
                Text("Ohne neuen Satz endet das Training nach vier Stunden von selbst.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            // Der Abstand zum Fuss darunter ist s12, nicht s24 wie zwischen
            // Kopf und Liste: die Beenden-Gruppe und die Startwege im Fuss
            // gehoerten vor dem Umbau zu EINER Fussgruppe mit s12 -- dieser
            // Abstand bleibt bestehen, obwohl beide jetzt getrennte Funktionen
            // sind, sonst waechst die feste Hoehe auf Kosten der Liste.
            .padding(.bottom, DesignSystem.Spacing.s12)
        }
    }

    private func laufendKopf(_ mitte: TrainingTab.Mitte) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                HStack(spacing: DesignSystem.Spacing.s8) {
                    Circle()
                        .fill(DesignSystem.Color.textMuted)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    // Abweichung vom Artboard: dort accent fuer Punkt und
                    // Label. Die bleiben textMuted, weil die eine
                    // Akzentflaeche dieses Screens "Training beenden" gehoert
                    // (designsystem.md SS2).
                    Text("TRAINING LÄUFT")
                        .font(DesignSystem.Typography.label)
                        .tracking(1.5)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                // Gegen mitte.startedAt gerechnet, nicht gegen einen
                // mitgezaehlten Wert: ein gespeicherter Zeitpunkt ueberlebt
                // Hintergrund und Sperrbildschirm, ein Zaehler nicht --
                // dasselbe Muster wie der Resttimer aus Sub-Projekt 2.
                TimelineView(.periodic(from: .now, by: 1)) { zeit in
                    // Ohne .accessibilityLabel liest VoiceOver "23:41" mit
                    // hoher Wahrscheinlichkeit als Uhrzeit -- direkt ueber
                    // dem echten "seit 18:04" darunter. verstrichenGesprochen
                    // macht daraus "23 Minuten trainiert" (designsystem.md
                    // SS12, wie Zahlformat.gewichtGesprochen).
                    Text(Zahlformat.verstrichen(seit: mitte.startedAt, bis: zeit.date))
                        .font(.system(size: 40, weight: .black).monospacedDigit())
                        .foregroundStyle(DesignSystem.Color.text)
                        .accessibilityLabel(Zahlformat.verstrichenGesprochen(seit: mitte.startedAt, bis: zeit.date))
                }
                // Der Beginn ist seit Schnitt 4 der Tap auf "Training
                // starten". Die Zeile bleibt: eine Uhr ohne Anker ("23:41 --
                // seit wann?") sagt nichts.
                Text("seit \(Zahlformat.uhrzeit(mitte.startedAt))")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            Spacer()
            // Ohne Satz zeigt "die App misst nichts" (SS10) auch keine
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
            GeraeteAuswahlView(fotoLader: apiClient, vorschauLader: vorschauLader) { machineId in
                pfad.append(.erkannt(machineId: machineId, token: nil))
            }
        case .erkannt(let machineId, let token):
            if let modell = modell(machineId: machineId, exerciseId: nil, token: token) {
                GeraetErkanntScreen(modell: modell) { uebungId in
                    pfad.append(TrainingStart.ziel(machineId: machineId, exerciseId: uebungId, token: token,
                                                    trainingLaeuft: sessions.aktiveSession() != nil))
                }
            }
        case .start(let machineId, let exerciseId, let token):
            if let modell = modell(machineId: machineId, exerciseId: exerciseId, token: token) {
                TrainingStartView(modell: modell) {
                    sessions.trainingStarten()
                    // ERSETZEN, nicht stapeln: "Zurueck" vom Satzpfad soll auf
                    // "Geraet erkannt" fuehren, nicht auf einen Startknopf fuer ein
                    // Training, das schon laeuft. Der Startscreen ist immer der
                    // oberste Eintrag, wenn sein Knopf gedrueckt wird; der Guard
                    // schuetzt nur vor einem Tap waehrend einer laufenden
                    // Pop-Animation.
                    let satzpfad = GeraetRoute.geraet(machineId: machineId, exerciseId: exerciseId, token: token)
                    if case .start = pfad.last { pfad[pfad.count - 1] = satzpfad } else { pfad.append(satzpfad) }
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
            // Auch der Direktweg beginnt ohne laufendes Training auf dem
            // Startscreen -- sonst entstuende die Einheit fuer Stammgaeste
            // weiter erst mit dem Satz.
            pfad.append(TrainingStart.ziel(machineId: maschine.id, exerciseId: uebung, token: token,
                                            trainingLaeuft: sessions.aktiveSession() != nil))
        }
    }

    private func oeffne(_ block: LokalerBlock) {
        // Der Zirkelfall: ein Tap statt eines Scans (M1-Spec SS5.3).
        // Kein TrainingStart.ziel: die Blockliste gibt es nur, solange ein
        // Training laeuft.
        pfad.append(.geraet(machineId: block.machineId, exerciseId: block.exerciseId, token: nil))
    }

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
            hinweis = .verworfen
            sessions.beenden()
            return
        }
        // Der Satz im Fuss gehoert zu GENAU EINER frueheren Einheit (M1): mit
        // dem manuellen Beenden hier gilt er nicht mehr.
        hinweis = nil
        // Erst festhalten, dann beenden -- andersherum sind die Zahlen weg,
        // bevor der Screen sie zeigt.
        sessions.beenden()
        pfad.append(.abschluss(sessionId: session.id, zusammenfassung: zusammenfassung))
    }
}

/// Der Satz im Fuss ueber einer Einheit, die nicht mehr laeuft. Zwei
/// Faelle, ein Zustand: gleichzeitig gelten sie nie, und ein zweites Bool
/// haette zwei Banner uebereinander erlaubt.
private enum TabHinweis {
    /// Vier Stunden ohne neuen Satz -- die Einheit MIT Saetzen ist beim
    /// Server (oder in der Warteschlange) und gilt als beendet.
    case ausgelaufen
    /// "Training beenden" ohne einen Satz: verworfen, nie gemeldet
    /// (Sammelstelle, Entschieden 2). Nie stumm -- der Tap hatte eine
    /// Wirkung, und die soll man lesen koennen.
    case verworfen

    var text: String {
        switch self {
        case .ausgelaufen: "Dein letztes Training wurde automatisch beendet."
        case .verworfen: "Kein Satz gesichert — das Training wurde verworfen."
        }
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
