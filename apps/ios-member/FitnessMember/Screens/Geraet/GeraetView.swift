import SwiftUI

/// Main, Pause und Abschluss sind derselbe Screen in drei Zustaenden --
/// keine Navigationsziele. Einen vierten (Raeder zu / offen) gibt es seit
/// Schnitt 3 nicht mehr: die Raeder sind immer aktiv, und was am
/// geschlossenen Zustand hing, ist weg oder im Drawer (Sammelstelle
/// Punkt 11 bis 13).
///
/// Die Pause ist unter ihnen der einzige AUSSCHLIESSENDE Zustand: sie
/// ersetzt Raeder, Einstellwerte und Aktionen, statt sich darueberzulegen.
/// Vorher blieb alles bedienbar -- man konnte mitten in der Pause das
/// Belastung verstellen und den naechsten Satz sichern, was den eben
/// gestarteten Timer sofort wieder neu startete.
struct GeraetView: View {
    @Bindable var modell: GeraetModel
    let beiProblem: () -> Void
    /// "Uebung abschliessen" -- an allen drei Stellen (Raeder, Pause,
    /// Abschluss). Ob danach gefragt wird oder es gleich zurueck zur Liste
    /// geht, entscheidet GeraetScreen (Testnotiz 06.10., #10, #12).
    let beiUebungAbschliessen: () -> Void
    /// "Training beenden" aus dem Dialog an der Uhr (Testnotiz 05.10.,
    /// #11). Den Abschluss zeigt die Wurzel des Training-Tabs.
    var beiTrainingBeenden: () -> Void = {}
    /// "Gewicht" in der Pause (Testnotiz 11.10., #12): ein Drawer mit dem
    /// Rad, der Wert gilt ab dem naechsten Satz.
    var beiGewichtAendern: () -> Void = {}
    /// Tipp auf Titel oder Video: die Einweisung noch einmal (#13).
    var beiEinweisung: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(WorkoutSessionStore.self) private var sessions
    @Environment(NetzwerkMonitor.self) private var netz
    @Environment(CatalogStore.self) private var katalog
    #if DEBUG
    @Environment(SensorAufnahmeKoordinator.self) private var sensorAufnahme
    #endif
    @State private var steuerungOffen = false
    /// Beim Erscheinen der Reserve-Frage einmal aus den Einstellungen gelesen.
    @State private var reserveErklaerungZeigen = false

    var body: some View {
        // Die Hoehe des sichtbaren Bereichs, damit der Inhalt sie mindestens
        // fuellt: dann stehen die Knoepfe unten in der Daumenzone und das
        // Pausenrad in der Mitte, statt alles oben zu sammeln (Testnotiz
        // 05.10., #12, #13). Passt der Inhalt nicht, scrollt er wie bisher.
        GeometryReader { sichtbar in
            ScrollView {
                // 16 statt 24 zwischen den Bloecken: der Satzpfad muss auf ein
                // 667-pt-iPhone passen, ohne dass die Seite scrollt -- und iOS 26
                // laesst dem Inhalt dort nur 510 pt (54 pt Navigationsleiste,
                // 83 pt Safe Area fuer die schwebende Tab-Leiste; Sammelstelle
                // Punkt 12, Rechnung im Plan zu Schnitt 3). Die
                // Einstellwerte-Zeile ist 44 pt hoch bei 15 pt Schrift und traegt
                // ihre Luft selbst. Scrollen tut die Seite nur noch mit
                // Statuskarten -- deshalb basedOnSize, sonst federt ein Pfad, der
                // passt.
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                    // Label ueber seinem Titel: Kopfzeile und Geraetename sind
                    // eine Einheit und stehen deshalb 8 auseinander, nicht 16.
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                        kopfzeile
                        // Unter der Trainingsuhr statt ueber den Raedern
                        // (Testnotiz 16.10., #3): Karte, Zaehlerstand und
                        // Marken gehoeren zum Sensor, nicht zum Satzwert.
                        // Sichtbar wie zuvor nur, solange die Raeder stehen.
                        #if DEBUG
                        if zeigtRaeder {
                            SensorZeile(station: modell.station.schluessel)
                        }
                        #endif
                        // Sichtbarkeit hier entschieden, nicht in den Komponenten
                        // selbst -- damit kein VStack einen leer rendernden
                        // Kindzustand umschliesst (Review-Fund Task 15).
                        //
                        // Waehrend der Pause schweigen die drei Statuskarten. Die
                        // Pause ist der ausschliessende Zustand (siehe oben), und
                        // die Warteschlangenkarte war dort das Gegenteil davon: sie
                        // blitzte nach jedem gesicherten Satz kurz auf ("wartet auf
                        // Empfang", dann "gesendet", dann weg) und riss beim
                        // Verschwinden das Rad samt Ziffern nach oben. Ein
                        // erfolgreicher Normalfall braucht diese Meldung nicht --
                        // sie steht nach der Pause wieder da, solange sie gilt.
                        if modell.laufendePause == nil {
                            if !netz.istOnline {
                                OfflineLeiste(istOnline: netz.istOnline)
                            }
                            // Kein "Gesendet" nach dem Leerlaufen: der Normalfall braucht
                            // keine Meldung (Testnotiz 18.10., #1).
                            if !katalog.pendingWrites.isEmpty {
                                WarteschlangeKarte(offen: katalog.pendingWrites.count)
                            }
                            if !katalog.verworfeneWrites.isEmpty {
                                AbgelehnteKarte(anzahl: katalog.verworfeneWrites.count,
                                                beiQuittieren: katalog.verworfeneQuittieren)
                            }
                            // Nicht gesichert, weil das Geraet an einem anderen
                            // Ort steht als die Einheit -- sagt, was gilt.
                            if let abgelehnt = modell.satzAbgelehnt {
                                InlineBanner(tone: .danger, message: abgelehnt)
                            }
                        }
                        geraetUndUebung
                    }
                    inhalt
                }
                .padding(.horizontal, 20)
                // 8 statt 32: die 83 pt Safe Area der schwebenden Tab-Leiste
                // tragen den Abstand nach unten schon.
                .padding(.bottom, DesignSystem.Spacing.s8)
                .frame(minHeight: sichtbar.size.height, alignment: .top)
                .animation(reduceMotion ? nil : DesignSystem.Motion.pause, value: modell.phase)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(DesignSystem.Color.bg)
        .navigationBarTitleDisplayMode(.inline)
        // Die Trainingsuhr startet nicht hier, sondern mit "Übung starten"
        // im Drawer davor (Testnotiz 11.10., #11). geraetGeoeffnet()
        // beginnt einmal beim Oeffnen den Mitschnitt, nicht nach jedem Satz.
        .task { modell.geraetGeoeffnet(); await modell.kontextLaden() }
        // Die Pause muss sich selbst beenden. Vorher lief sie gegen einen
        // Zustand, den niemand zuruecksetzte: der Balken blieb auf 00:00
        // stehen, bis irgendein anderes Ereignis ein Re-Render ausloeste.
        // Als Band war das nur haesslich; als ausschliessender Zustand
        // waere es eine Sackgasse. Der Endzeitpunkt ist die id, damit
        // "+30 s" den Task neu aufsetzt statt zu frueh zu feuern.
        .task(id: modell.laufendePause?.endetAm) {
            guard let ende = modell.laufendePause?.endetAm else { return }
            let rest = ende.timeIntervalSinceNow
            if rest > 0 { try? await Task.sleep(for: .seconds(rest)) }
            guard !Task.isCancelled else { return }
            modell.pauseBeenden()
        }
        // Ein verlassener Screen ohne gesicherten Satz ist ein abgebrochener
        // Mitschnitt. Im Release ist das ein Aufruf auf nil.
        .onDisappear { modell.screenVerlassen() }
        #if DEBUG
        // Ohne Hintergrundmodus reisst der Mitschnitt ab, sobald der
        // Bildschirm sperrt (Spec Sensor-Anbindung 5.3). Zurueck auf false
        // beim Verlassen, sonst bleibt das Telefon in der ganzen App wach.
        .onChange(of: sensorAufnahme.quelle.zustand.istVerbunden, initial: true) { _, verbunden in
            UIApplication.shared.isIdleTimerDisabled = verbunden
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        #endif
        // Spec B 6.5: ein kurzes Signal je gezaehlter Wiederholung, nicht
        // beim Wechsel nach bereit, pruefen oder vonHand.
        .sensoryFeedback(trigger: modell.zaehlerZustand) { _, neu in
            if case .zaehlt = neu { return .increase }
            return nil
        }
        .testnotizScreen(kontext: testnotizKontext)
        .trainingSteuerung(
            istOffen: $steuerungOffen,
            pausiert: sessions.aktiveSession()?.istPausiert ?? false,
            beiPauseUmschalten: {
                if sessions.aktiveSession()?.istPausiert == true {
                    sessions.fortsetzen()
                } else {
                    sessions.pausieren()
                }
            },
            beiBeenden: beiTrainingBeenden)
    }

    private var testnotizKontext: [String: String] {
        var kontext = [
            "station": modell.station.schluessel,
            "exerciseId": modell.uebungId,
            // Nur der Fallname: .pause traegt einen Timer, dessen Text sich jede Sekunde aendert.
            "phase": String(String(describing: modell.phase).prefix { $0 != "(" }),
        ]
        #if DEBUG
        kontext["sensor"] = sensorAufnahme.quelle.zustand.istVerbunden ? "verbunden" : "aus"
        kontext["zaehler"] = String(describing: modell.zaehlerZustand)
        #endif
        return kontext
    }

    /// Der letzte Zweig von `inhalt`: kein Countdown, keine Pause, kein
    /// Abschluss -- die Satzeingabe.
    private var zeigtRaeder: Bool {
        if case .bereit = modell.phase { return false }
        return modell.laufendePause == nil && modell.phase != .abschluss
    }

    /// Die eine Stelle, an der der Screen entscheidet, was er ist.
    @ViewBuilder
    private var inhalt: some View {
        if case .bereit(let countdown) = modell.phase {
            startcountdown(countdown)
                .transition(.opacity)
        } else if let pause = modell.laufendePause {
            PausenRad(timer: pause,
                      beiVerlaengern: modell.pauseVerlaengern,
                      beiGewicht: beiGewichtAendern,
                      einheit: modell.loadUnit,
                      naechsterSatz: modell.satzNummer,
                      beiWeiter: modell.pauseBeenden,
                      // Derselbe Weg wie "Uebung abschliessen" unter den
                      // Raedern -- nur ohne den Umweg ueber den naechsten
                      // Satz. Der letzte Satz ist schon gesichert, deshalb
                      // ohne die Frage nach dem offenen Satz (#5).
                      beiAbschliessen: beiUebungAbschliessen)
                .transition(.opacity)
        } else if modell.phase == .abschluss {
            abschlussEntscheidung
                .transition(.opacity)
        } else {
            einstellung
            if modell.istCardio {
                CardioRaster(modell: modell)
            } else {
                WertZeile(modell: modell)
            }
            Spacer(minLength: 0)
            aktionen
        }
    }

    /// Fuenf Sekunden und "Los!" im Ring der Pause, dann die Raeder
    /// (Testnotiz 11.10., #10). Ein Tipp auf den Ring ueberspringt ihn --
    /// wer schon in Position ist, wartet nicht.
    private func startcountdown(_ countdown: Resttimer) -> some View {
        VStack(spacing: DesignSystem.Spacing.s24) {
            Spacer(minLength: 0)
            Button(action: modell.countdownBeenden) {
                Zeitring(timer: countdown, beschriftung: "GLEICH GEHT’S LOS",
                         fortschritt: { Startcountdown.fortschritt(start: countdown.start, jetzt: $0) }) {
                    Startcountdown.anzeige(restsekunden: $0)
                }
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityLabel("Gleich geht’s los")
            .accessibilityHint("Startet sofort")
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Wie der Ablauf der Pause: der Countdown beendet sich selbst.
        .task(id: countdown.endetAm) {
            let rest = countdown.endetAm.timeIntervalSinceNow
            if rest > 0 { try? await Task.sleep(for: .seconds(rest)) }
            guard !Task.isCancelled else { return }
            modell.countdownBeenden()
        }
    }

    private var kopfzeile: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(modell.ortsangabe.uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textFaint)
            Spacer(minLength: DesignSystem.Spacing.s12)
            trainingsuhr
        }
    }

    /// Wie lange das Training schon laeuft -- oben rechts, in derselben
    /// Zeile wie der Ort, mit dem pulsierenden Punkt davor (Testnotiz
    /// 05.10., #10). Ein Tipp oeffnet "Pausieren / Training beenden" (#11).
    ///
    /// Ohne laufende Einheit (die Vier-Stunden-Grenze ist waehrend des
    /// Screens abgelaufen) steht hier nichts -- eine Uhr auf 00:00 waere
    /// eine Behauptung ueber ein Training, das nicht mehr laeuft.
    @ViewBuilder
    private var trainingsuhr: some View {
        if let session = sessions.aktiveSession() {
            Button { steuerungOffen = true } label: {
                HStack(spacing: 6) {
                    Laufpunkt(pausiert: session.istPausiert)
                    TrainingsuhrText(session: session, font: .system(size: 15, weight: .semibold))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressButtonStyle())
            .testnotizElement("geraet.trainingsuhr", typ: "Button")
            .accessibilityHint("Pausieren oder Training beenden")
            .fixedSize()
            // Die 44 pt Trefferflaeche ragen aus der Kopfzeile heraus,
            // statt sie zu strecken -- dasselbe Hoehenbudget wie bei
            // "andere Übung".
            .padding(.vertical, -DesignSystem.Spacing.s12)
        }
    }

    /// Links das Video der aktiven Uebung in Schleife (Testnotiz 11.10.,
    /// #7) -- daneben statt darueber, weil das Hoehenbudget auf 667 pt
    /// keine eigene Zeile hergibt (siehe unten). Ohne Video faellt die
    /// Kachel samt Abstand weg, statt dem Namen Breite zu nehmen.
    /// Ein Knopf fuer Video und Namen: wer mitten im Training nachsehen
    /// will, wie die Uebung geht, tippt auf das, was er sieht (Testnotiz
    /// 11.10., #13).
    private var geraetUndUebung: some View {
        Button(action: beiEinweisung) {
            HStack(alignment: .center, spacing: 0) {
                UebungsVideoKachel(exerciseId: modell.aktiveUebung?.id, kante: 56)
                namen
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityHint("Zeigt die Einweisung")
        .testnotizElement("geraet.einweisung", typ: "Button")
    }

    private var namen: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            // Eine Zeile: ein zweizeiliger Name (BEINPRESSE SITZEND misst
            // rund 380 pt bei 32 pt Black) kostete 38 pt, die das
            // Hoehenbudget auf 667 pt nicht hat. Schrumpfen statt kuerzen --
            // ein abgeschnittener Name sagt nicht, an welchem Geraet man
            // steht. Der Name steht ueber der Uebungszeile und nicht neben
            // "andere Uebung", weil der Knopf ihm sonst 100 pt Breite nimmt
            // und schon "RUDERMASCHINE" auf dem SE umbricht. Nebenbei
            // behoben: der Name hat dadurch in jedem Zustand dieselbe volle
            // Breite, statt sie zwischen Eingabe und Pause zu wechseln --
            // genau das liess den Namen im Sichtcheck zu Schnitt 2 in der
            // Pause links abgeschnitten aufblitzen, waehrend die Breite
            // unter der Zustandsanimation interpolierte.
            Text(modell.station.equipmentModel.name.uppercased())
                .font(DesignSystem.Typography.geraetename)
                .tracking(-0.8)
                .foregroundStyle(DesignSystem.Color.text)
                .lineLimit(1)
                // 0.6 statt 0.75, seit das Video links 68 pt nimmt
                // (Testnotiz 11.10., #7): 45-GRAD-SCHLITTENPRESSE brach
                // mit 0.75 sonst zu "SCHLITTENP..." ab.
                .minimumScaleFactor(0.6)
            // "andere Übung" stand bis zur Testnotiz 06.10. (#11) rechts
            // daneben. Gewechselt wird jetzt nach "Übung abschließen" --
            // dann, wenn die eine Uebung fertig ist (#12).
            Text(modell.aktiveUebung?.name ?? "")
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    /// Eine Zeile, nicht die Karte: derselbe Inhalt stand vorher in zwei
    /// Gestalten (Sammelstelle Punkt 13), und die Karte mit grossen Zahlen kostete
    /// 71 pt, die der Satzpfad auf einem 667-pt-iPhone nicht hat (Punkt 12).
    /// Die Zeile ist 44 pt hoch, weil "aendern" es ist -- ein Hit-Target unter
    /// 44 pt gibt es nicht.
    @ViewBuilder
    private var einstellung: some View {
        if !modell.einstellwerte.isEmpty {
            HStack {
                Text(modell.einstellwerte.map { "\($0.label) \($0.anzeige)" }
                    .joined(separator: " · "))
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .lineLimit(1)
                Spacer()
                // Am Typ bleiben die Werte Anzeige: ohne Geraet gibt es
                // keinen Ort, an dem eine neue Einstellung gelten koennte.
                if modell.kannKalibrieren { aendernKnopf }
            }
        }
    }

    private var aendernKnopf: some View {
        // Der Rahmen steht im Label, nicht um den Button: mit eigenem
        // ButtonStyle ist nur das gestylte Label tippbar.
        Button { modell.kalibrierungOeffnen() } label: {
            Text("ändern")
                .font(.system(size: 13, weight: .semibold))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .testnotizElement("geraet.kalibrierung-aendern", typ: "Button")
        .foregroundStyle(DesignSystem.Color.textMuted)
        .buttonStyle(PressButtonStyle())
    }

    private var aktionen: some View {
        VStack(spacing: DesignSystem.Spacing.s12) {
            // Sichert direkt aus dem Rad heraus: scrollen, dann sichern --
            // zwei Interaktionen, kein Tap dazwischen
            // (Interaktionsbudget SS9).
            PrimaryButton(title: hauptaktion, isEnabled: modell.kannSichern) {
                await modell.satzSichern(problemFlag: false, problemReason: nil)
            }
            .testnotizElement("geraet.satz-sichern", typ: "PrimaryButton")
            .accessibilityLabel(modell.istCardio
                ? hauptaktion
                : "\(hauptaktion), \(Zahlformat.belastungGesprochen(modell.belastung, modell.loadUnit))")

            // Abschliessen und Problem melden in EINER Zeile (Sammelstelle
            // Punkt 12): als dritte Zeile kostete "Problem melden" 56 pt, die
            // auf einem 667-pt-iPhone fehlten. Es bleibt ein Textknopf mit
            // 44 pt Hoehe, kein zweiter Umriss -- die Ausnahme, nicht die
            // Alternative. "Uebung abschliessen" steht weiter direkt unter dem
            // Weg zum naechsten Satz, weil es die andere Haelfte derselben
            // Frage ist: noch einer, oder fertig hier? Bis zur Testnotiz
            // 06.10. (#10) hiess er "Gerät abschließen" -- abgeschlossen
            // wird aber die Uebung, das Geraet kann noch eine zweite haben.
            HStack(spacing: DesignSystem.Spacing.s12) {
                SecondaryButton(title: "Übung abschließen", action: beiUebungAbschliessen)
                    .testnotizElement("geraet.abschliessen", typ: "SecondaryButton")
                problemMelden
            }
        }
        // Am umschliessenden VStack, nicht am PrimaryButton selbst: der
        // Knopf verschwindet je nach Zustand aus der Hierarchie, der
        // Modifier soll trotzdem am Leben bleiben.
        //
        // Trigger ist gesicherteSaetze, nicht satzNummer: satzNummer ist
        // die naechste Satznummer der GERADE ANGEZEIGTEN Uebung und
        // springt schon beim blossen Wechsel auf eine Uebung mit mehr
        // bereits gesicherten Saetzen (Review-Fund Task 9) -- das Geraet
        // vibrierte dann bei einer Navigation, nicht bei einem Satz.
        .sensoryFeedback(trigger: modell.gesicherteSaetze) { alt, neu in
            // Haptik nie als einzige Rueckmeldung (designsystem.md SS6):
            // die sichtbare Bestaetigung bleibt daneben bestehen.
            vibrationBeimSichern && neu > alt ? .impact(weight: .medium) : nil
        }
    }

    private var hauptaktion: String {
        "Satz \(modell.satzNummer) sichern"
    }

    /// Nach dem letzten geplanten Satz. Eine Pause vor einem Satz, der nicht
    /// mehr kommt, ist nur Wartezeit -- an ihrer Stelle steht die Frage, die
    /// jetzt wirklich ansteht.
    private var abschlussEntscheidung: some View {
        VStack(spacing: DesignSystem.Spacing.s12) {
            Text(modell.satzZiel == 1 ? "1 SATZ GESCHAFFT" : "\(modell.satzZiel) SÄTZE GESCHAFFT")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Wo sonst die Pause laeuft, ein voller Ring (Testnotiz 14.10.,
            // 18:45 #5). Die Knoepfe bleiben unten, wie im Eingabezustand
            // (Testnotiz 05.10., #13).
            Spacer(minLength: 0)
            // An Kraftgeraeten steht hier die Reserve-Frage statt des Rings
            // (Trainingsplan-Spec Abschnitt 6): der Screen wartet ohnehin,
            // und die Antwort macht den naechsten Vorschlag besser.
            if modell.zeigtReserveFrage {
                ReserveSkala(auswahl: modell.reserve, mitErklaerung: reserveErklaerungZeigen) {
                    modell.reserveSetzen($0)
                }
                .testnotizElement("geraet.reserve", typ: "ReserveSkala")
                .onAppear {
                    reserveErklaerungZeigen = !UserDefaults.standard.bool(forKey: Einstellungen.reserveErklaertKey)
                    UserDefaults.standard.set(true, forKey: Einstellungen.reserveErklaertKey)
                }
            } else {
                FertigRing()
                    .testnotizElement("geraet.fertig", typ: "FertigRing")
            }
            Spacer(minLength: 0)

            // Wie in der Pause "Nächste Übung" (Testnotiz 12.10. abends,
            // #6, #7): dieselbe Aktion soll nicht an zwei Stellen zwei Namen
            // tragen.
            PrimaryButton(title: "Nächste Übung") { beiUebungAbschliessen() }
                .testnotizElement("geraet.naechste-uebung", typ: "PrimaryButton")
            // Dieselbe Zeile wie unter den Raedern (Sammelstelle Punkt 12).
            HStack(spacing: DesignSystem.Spacing.s12) {
                SecondaryButton(title: "Weiterer Satz") { modell.weitererSatz() }
                    .testnotizElement("geraet.weiterer-satz", typ: "SecondaryButton")
                problemMelden
            }
        }
        .frame(maxHeight: .infinity)
    }

    /// In beiden Aktionsgruppen dieselbe Zeile -- zweimal getippt waere sie
    /// die naechste, die auseinanderlaeuft.
    private var problemMelden: some View {
        // Der Rahmen steht im Label, nicht um den Button: mit eigenem
        // ButtonStyle ist nur das gestylte Label tippbar.
        Button(action: beiProblem) {
            Text("Problem melden")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .testnotizElement("geraet.problem", typ: "Button")
        .foregroundStyle(DesignSystem.Color.textMuted)
        .buttonStyle(PressButtonStyle())
        .accessibilityHint("Verhindert einen Steigerungsvorschlag")
    }

    /// Haptik beim Sichern, ueber das Profil abschaltbar (SS6: Haptik nie
    /// als einzige Rueckmeldung -- die sichtbare Bestaetigung bleibt in
    /// jedem Fall bestehen).
    @AppStorage(Einstellungen.vibrationBeimSichernKey) private var vibrationBeimSichern = true
}

/// Bindet die Sheets an GeraetView. Getrennt, damit
/// GeraetView selbst nur den Screen beschreibt und in der Preview ohne
/// Umgebung lauffaehig bleibt.
struct GeraetScreen: View {
    @State var modell: GeraetModel
    let beiZurueckZumTraining: () -> Void
    let beiTrainingBeenden: () -> Void

    @State private var uebungWechselnOffen = false
    @State private var gewichtOffen = false
    @State private var einweisungOffen = false
    @State private var problemOffen = false
    @State private var abschlussfrageOffen = false
    /// "Satz speichern / Satz verwerfen" vor dem Abschluss (Testnotiz
    /// 12.10. abends, #5).
    @State private var satzfrageOffen = false
    /// Wie nachAbschlussfrage: was nach dem Schliessen der Satzfrage
    /// folgt, erst in onDismiss.
    @State private var abschlussNachSatzfrage = false
    /// Was nach dem Schliessen der Abschlussfrage folgt. Zwei Sheets
    /// nacheinander gehen nur ueber onDismiss: solange das eine noch
    /// verschwindet, praesentiert SwiftUI das naechste nicht. Dasselbe gilt
    /// fuer den Weg zurueck: ein Pop waehrend der Dismiss-Animation verwirft
    /// UIKit, der Pfad ist leer, der Screen bleibt stehen (Testnotiz 14.10.,
    /// 18:41 #1/#2: haengen, dann schwarzer Screen beim Zurueck).
    @State private var nachAbschlussfrage: AbschlussFolge?
    /// Nach der Wahl einer weiteren Uebung der Start-Drawer wie aus der
    /// Liste (Testnotiz 13.10., #3) -- auch er erst in onDismiss.
    @State private var startNachWechsel = false
    @State private var uebungsstartOffen = false

    private enum AbschlussFolge {
        case weitereUebung
        case zurueckZumTraining
    }

    var body: some View {
        GeraetView(
            modell: modell,
            beiProblem: { problemOffen = true },
            beiUebungAbschliessen: {
                if modell.abschlussFragtNachSatz {
                    satzfrageOffen = true
                } else {
                    uebungAbschliessen()
                }
            },
            beiTrainingBeenden: beiTrainingBeenden,
            beiGewichtAendern: { gewichtOffen = true },
            beiEinweisung: { einweisungOffen = true }
        )
        .sheet(isPresented: $gewichtOffen) {
            GewichtAendernSheet(modell: modell) { gewichtOffen = false }
        }
        // Nur ansehen: kein Weiter in Einstellung oder Startwerte, die
        // Uebung laeuft ja schon (Testnotiz 11.10., #13).
        .sheet(isPresented: $einweisungOffen) {
            EinweisungSchritt(
                modell: modell, titel: "Einweisung",
                hauptaktion: "Zurück zum Satz",
                beiAbbruch: { einweisungOffen = false },
                beiWeiter: { einweisungOffen = false },
                beiUeberspringen: nil)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $uebungWechselnOffen, onDismiss: {
            if startNachWechsel {
                startNachWechsel = false
                // Bekannte Cardio-Uebung: ohne Drawer (Testnotiz 14.10., 18:45 #6).
                if Uebungsstart.direktStart(erstkontakt: modell.istErstkontakt,
                                            fragtEinstellung: modell.erstkontaktFragtEinstellung,
                                            volumeKind: modell.volumeKind) {
                    if !modell.trainingLaeuft { modell.trainingStarten() }
                    modell.uebungStarten(mit: modell.startwerte)
                } else {
                    uebungsstartOffen = true
                }
            }
        }) {
            UebungWechselnSheet(modell: modell) {
                modell.uebungWechseln(zu: $0)
                startNachWechsel = true
            }
        }
        // Ohne ihn fehlte bei einer neuen Uebung die Einweisung (Testnotiz
        // 13.10., #3). Schliessen laesst die Raeder der neuen Uebung stehen;
        // der Erstkontakt bleibt offen und kommt beim naechsten Mal wieder.
        .sheet(isPresented: $uebungsstartOffen) {
            UebungsstartSheet(modell: modell, beiStart: { werte in
                // Wie uebungStarten in TrainingRootView: der Drawer sagt
                // ohne laufendes Training, dass dieser Tipp die Uhr startet.
                if !modell.trainingLaeuft { modell.trainingStarten() }
                modell.uebungStarten(mit: werte)
                uebungsstartOffen = false
            }, beiSchliessen: { uebungsstartOffen = false })
        }
        // Vor dem Abschluss unter den Raedern: der offene Satz (Testnotiz
        // 12.10. abends, #5). Wegwischen bricht ab, die Raeder bleiben.
        .sheet(isPresented: $satzfrageOffen, onDismiss: {
            if abschlussNachSatzfrage {
                abschlussNachSatzfrage = false
                uebungAbschliessen()
            }
        }) {
            SatzOffenSheet(
                satzNummer: modell.satzNummer,
                beiSpeichern: {
                    // Abgelehnt (anderes Studio): zurueck auf die Satzseite,
                    // die den Grund zeigt -- nicht still aus der Uebung.
                    abschlussNachSatzfrage = await modell.satzSichernVorAbschluss()
                    satzfrageOffen = false
                },
                beiVerwerfen: {
                    abschlussNachSatzfrage = true
                    satzfrageOffen = false
                })
        }
        // Der Drawer nach "Übung abschließen" (Testnotiz 06.10., #12).
        .sheet(isPresented: $abschlussfrageOffen, onDismiss: {
            let folge = nachAbschlussfrage
            nachAbschlussfrage = nil
            switch folge {
            case .weitereUebung: uebungWechselnOffen = true
            case .zurueckZumTraining: beiZurueckZumTraining()
            case nil: break
            }
        }) {
            UebungAbschliessenSheet(
                beiWeitereUebung: {
                    nachAbschlussfrage = .weitereUebung
                    abschlussfrageOffen = false
                },
                beiGeraetAbschliessen: {
                    nachAbschlussfrage = .zurueckZumTraining
                    abschlussfrageOffen = false
                })
        }
        .sheet(isPresented: $problemOffen) {
            ProblemSheet(modell: modell) {}
        }
        // "Einstellung aendern" auf der Satzseite. Der Erstkontakt selbst
        // laeuft seit der Testnotiz 11.10. (#6) im Drawer VOR der Seite.
        .fullScreenCover(isPresented: $modell.kalibrierungOffen) {
            // Ein eigenstaendiger Screen ohne vorherigen Schritt, deshalb
            // schliessen sowohl der Zurueck-Chevron als auch "Einstellung
            // speichern" das Cover -- KalibrierungSchritt verlangt beiZurueck
            // immer, auch wenn es hier kein "davor" gibt.
            KalibrierungSchritt(
                modell: modell, titel: "Deine Einstellung",
                beiZurueck: { modell.kalibrierungOffen = false }
            ) {
                modell.kalibrierungOffen = false
            }
        }
    }

    /// Der Weg aus der Uebung, wenn kein Satz mehr offen ist: bei mehreren
    /// Uebungen die Frage, sonst zurueck zum Training.
    private func uebungAbschliessen() {
        if modell.abschlussFragtNach {
            abschlussfrageOffen = true
        } else {
            beiZurueckZumTraining()
        }
    }
}

/// Das Gewicht fuer den naechsten Satz, waehrend die Pause weiterlaeuft
/// (Testnotiz 11.10., #12) -- typischerweise steckt man in der Pause um.
/// Das Rad schreibt direkt ins Modell: wer den Drawer wegwischt, erwartet
/// das gedrehte Gewicht (Testnotiz 13.10., #1). Bis dahin galt es erst mit
/// "Übernehmen".
private struct GewichtAendernSheet: View {
    @Bindable var modell: GeraetModel
    let beiFertig: () -> Void

    var body: some View {
        let einheit = modell.loadUnit
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
            Text("GEWICHT FÜR DEN NÄCHSTEN SATZ")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textFaint)
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.s4) {
                RastRad(
                    werte: modell.belastungsWerte,
                    // Ueber belastungGewaehlt wie in WertZeile: ein spaeter
                    // Vorschlag ersetzt den gedrehten Wert nicht.
                    auswahl: Binding(
                        get: { modell.belastung },
                        set: { modell.belastungGewaehlt($0) }
                    ),
                    unterstrich: .held,
                    voLabel: "Belastung",
                    voWert: { Zahlformat.belastungGesprochen($0, einheit) },
                    anschlagText: modell.anschlagText,
                    text: { Zahlformat.belastung($0, einheit) },
                    sichtbareZeilen: 3
                )
                Text(einheit.kurz)
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .accessibilityHidden(true)
            }
            // Schliesst nur noch; uebernommen ist schon beim Drehen.
            PrimaryButton(title: "Fertig") { beiFertig() }
                .testnotizElement("geraet.gewicht-fertig", typ: "PrimaryButton")
        }
        .padding(.horizontal, 20)
        .padding(.top, DesignSystem.Spacing.s24)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(DesignSystem.Color.bg)
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
        .testnotizScreen()
    }
}

/// Die Frage nach "Übung abschließen", wenn das Geraet mehr als eine Uebung
/// kennt (Testnotiz 06.10., #12): an diesem Geraet weitermachen oder weiter
/// zum naechsten. Ein Drawer von unten statt eines Dialogs, wie die
/// Trainingssteuerung (#4).
private struct UebungAbschliessenSheet: View {
    let beiWeitereUebung: () -> Void
    let beiGeraetAbschliessen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text("ÜBUNG ABGESCHLOSSEN")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
            Text("An diesem Gerät gibt es noch weitere Übungen.")
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.text)
                .padding(.bottom, DesignSystem.Spacing.s8)
            PrimaryButton(title: "Weitere Übung an dem Gerät") { beiWeitereUebung() }
                .testnotizElement("geraet.weitere-uebung", typ: "PrimaryButton")
            SecondaryButton(title: "Gerät abschließen", action: beiGeraetAbschliessen)
                .testnotizElement("geraet.geraet-abschliessen", typ: "SecondaryButton")
        }
        .padding(.horizontal, 20)
        .padding(.top, DesignSystem.Spacing.s24)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(DesignSystem.Color.bg)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .testnotizScreen()
    }
}

/// Die Frage nach dem offenen Satz, wenn unter den Raedern "Übung
/// abschließen" getippt wird (Testnotiz 12.10. abends, #5): wer dort
/// abschliesst, kann erwarten, dass der eingestellte Satz gespeichert wird.
/// Ein Drawer wie die Abschlussfrage darunter.
private struct SatzOffenSheet: View {
    let satzNummer: Int
    let beiSpeichern: () async -> Void
    let beiVerwerfen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text("SATZ \(satzNummer) IST NOCH OFFEN")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
            Text("Speichern, was auf den Rädern steht, oder ohne diesen Satz abschließen?")
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, DesignSystem.Spacing.s8)
            PrimaryButton(title: "Satz speichern") { await beiSpeichern() }
                .testnotizElement("geraet.satz-speichern", typ: "PrimaryButton")
            SecondaryButton(title: "Satz verwerfen", action: beiVerwerfen)
                .testnotizElement("geraet.satz-verwerfen", typ: "SecondaryButton")
        }
        .padding(.horizontal, 20)
        .padding(.top, DesignSystem.Spacing.s24)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(DesignSystem.Color.bg)
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
        .testnotizScreen()
    }
}
