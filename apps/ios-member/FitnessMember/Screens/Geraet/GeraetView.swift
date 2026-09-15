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
/// Gewicht verstellen und den naechsten Satz sichern, was den eben
/// gestarteten Timer sofort wieder neu startete.
struct GeraetView: View {
    @Bindable var modell: GeraetModel
    let beiUebungWechseln: () -> Void
    let beiProblem: () -> Void
    let beiZurueckZumTraining: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(NetzwerkMonitor.self) private var netz
    @Environment(CatalogStore.self) private var katalog
    @State private var geradeGesendet = false
    // Zaehlt jede Runde "Warteschlange leergelaufen" hoch. .task(id:) bindet
    // den Zwei-Sekunden-Timer daran statt an einen freilaufenden Task: laeuft
    // die Schlange waehrend der zwei Sekunden erneut leer, bricht SwiftUI den
    // alten Timer beim id-Wechsel selbst ab, statt dass zwei Timer um die
    // Anzeige konkurrieren -- und verlaesst die Ansicht die Buehne, endet der
    // Timer mit ihr statt auf einen verschwundenen Zustand zu schreiben.
    @State private var gesendetRunde = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                kopfzeile
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
                    if !katalog.pendingWrites.isEmpty || geradeGesendet {
                        WarteschlangeKarte(offen: katalog.pendingWrites.count,
                                           geradeGesendet: geradeGesendet)
                    }
                    if !katalog.verworfeneWrites.isEmpty {
                        AbgelehnteKarte(anzahl: katalog.verworfeneWrites.count,
                                        beiQuittieren: katalog.verworfeneQuittieren)
                    }
                }
                geraetUndUebung
                inhalt
            }
            .padding(.horizontal, 20)
            .padding(.bottom, DesignSystem.Spacing.s32)
            .animation(reduceMotion ? nil : DesignSystem.Motion.pause, value: modell.phase)
        }
        .background(DesignSystem.Color.bg)
        .navigationBarTitleDisplayMode(.inline)
        // Die Trainingsuhr startet am ersten Geraet, nicht am ersten
        // gesicherten Satz -- deshalb hier und nicht in satzSichern.
        .task { modell.geraetBetreten(); await modell.kontextLaden() }
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
        // Der Reconnect-Moment: laeuft die Schlange leer, steht zwei
        // Sekunden "Gesendet". Der eigentliche Timer sitzt im .task(id:)
        // unten -- hier wird nur die naechste Runde ausgeloest.
        .onChange(of: katalog.pendingWrites.count) { alt, neu in
            guard alt > 0, neu == 0 else { return }
            geradeGesendet = true
            gesendetRunde += 1
        }
        // An gesendetRunde gebunden statt an einen freilaufenden Task: ein
        // erneutes Leerlaufen waehrend der zwei Sekunden (Nachschub kommt
        // rein und geht sofort wieder raus) hebt die Runde an, SwiftUI
        // bricht den alten Timer ab und die neuen zwei Sekunden zaehlen ab
        // dem zweiten Ereignis -- ohne dieses Bindung wuerde der erste Timer
        // "Gesendet" abschalten, waehrend die zweite Runde noch laufen soll.
        // Verlaesst die View die Buehne, cancelt SwiftUI den Task automatisch.
        .task(id: gesendetRunde) {
            guard gesendetRunde > 0 else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            geradeGesendet = false
        }
        .testnotizScreen(kontext: [
            "machineId": modell.maschine.id,
            "exerciseId": modell.uebungId,
            // Nur der Fallname: .pause traegt einen Timer, dessen Text sich jede Sekunde aendert.
            "phase": String(String(describing: modell.phase).prefix { $0 != "(" }),
        ])
    }

    /// Die eine Stelle, an der der Screen entscheidet, was er ist.
    @ViewBuilder
    private var inhalt: some View {
        if let pause = modell.laufendePause {
            PausenRad(timer: pause,
                      beiVerlaengern: modell.pauseVerlaengern,
                      beiWeiter: modell.pauseBeenden,
                      // Derselbe Weg wie "Geraet abschliessen" unter den
                      // Raedern -- nur ohne den Umweg ueber "Weiter".
                      beiAbschliessen: beiZurueckZumTraining)
                .transition(.opacity)
        } else if modell.phase == .abschluss {
            abschlussEntscheidung
                .transition(.opacity)
        } else {
            einstellung
            WertZeile(modell: modell)
            aktionen
        }
    }

    private var kopfzeile: some View {
        HStack(alignment: .firstTextBaseline) {
            Text([modell.maschine.label, modell.maschine.locationNote]
                .compactMap { $0 }.joined(separator: " · ").uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textFaint)
            Spacer(minLength: DesignSystem.Spacing.s12)
            trainingsuhr
        }
    }

    /// Wie lange das Training schon laeuft -- oben rechts, in derselben
    /// Zeile wie der Ort.
    ///
    /// Gegen einen gespeicherten Zeitpunkt gerechnet statt mitgezaehlt, wie
    /// auf dem Training-Tab und beim Resttimer: ein Zeitpunkt ueberlebt
    /// Hintergrund und Sperrbildschirm, ein Zaehler nicht. Ohne
    /// Trainingsbeginn (die Vier-Stunden-Grenze ist waehrend des Screens
    /// abgelaufen) steht hier nichts -- eine Uhr auf 00:00 waere eine
    /// Behauptung ueber ein Training, das nicht mehr laeuft.
    @ViewBuilder
    private var trainingsuhr: some View {
        if let beginn = modell.trainingsbeginn {
            TimelineView(.periodic(from: .now, by: 1)) { zeit in
                Text(Zahlformat.verstrichen(seit: beginn, bis: zeit.date))
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    // Ohne Label liest VoiceOver "23:41" als Uhrzeit
                    // (designsystem.md SS12, wie auf dem Training-Tab).
                    .accessibilityLabel(Zahlformat.verstrichenGesprochen(seit: beginn, bis: zeit.date))
            }
            .fixedSize()
        }
    }

    private var geraetUndUebung: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(modell.maschine.equipmentModel.name.uppercased())
                    .font(DesignSystem.Typography.geraetename)
                    .tracking(-0.8)
                    .foregroundStyle(DesignSystem.Color.text)
                Text(modell.aktiveUebung?.name ?? "")
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            Spacer()
            // Nur im Eingabezustand: Pause und Abschlussentscheidung zeigen
            // Geraet und Uebung zur Orientierung, nicht als Auswahl.
            //
            // Und nur, wenn das Geraet ueberhaupt eine zweite Uebung kennt:
            // sonst fuehrte der Knopf zu einem Sheet mit genau der Uebung,
            // die ohnehin schon laeuft.
            if modell.phase == .eingabe && modell.hatWeitereUebungen {
                // Abweichung vom Artboard (Spec Abschnitt 9): dort accent. Die
                // eine Akzentflaeche des Screens ist die Hauptaktion.
                Button("andere Übung", action: beiUebungWechseln)
                    .testnotizElement("geraet.uebung-wechseln", typ: "Button")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .frame(minHeight: 44)
                    .buttonStyle(PressButtonStyle())
            }
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
                aendernKnopf
            }
        }
    }

    private var aendernKnopf: some View {
        Button("ändern") { modell.kalibrierungOeffnen() }
            .testnotizElement("geraet.kalibrierung-aendern", typ: "Button")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(DesignSystem.Color.textMuted)
            .frame(minHeight: 44)
            .buttonStyle(PressButtonStyle())
    }

    private var aktionen: some View {
        VStack(spacing: DesignSystem.Spacing.s12) {
            // Sichert direkt aus dem Rad heraus: scrollen, dann sichern --
            // zwei Interaktionen, kein Tap dazwischen
            // (Interaktionsbudget SS9).
            PrimaryButton(title: hauptaktion) {
                await modell.satzSichern(problemFlag: false, problemReason: nil)
            }
            .testnotizElement("geraet.satz-sichern", typ: "PrimaryButton")
            .accessibilityLabel("\(hauptaktion), \(Zahlformat.gewichtGesprochen(modell.gewicht))")

            // Steht direkt unter dem Weg zum naechsten Satz, weil es die
            // andere Haelfte derselben Frage ist: noch einer, oder fertig
            // hier? Vorher gab es dafuer nur ein kleingesetztes "Zurueck zum
            // Training" ganz unten -- eine Navigation, kein Abschluss.
            SecondaryButton(title: "Gerät abschließen", action: beiZurueckZumTraining)
                .testnotizElement("geraet.abschliessen", typ: "SecondaryButton")

            problemMelden
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
            Text("\(modell.satzZiel) SÄTZE GESCHAFFT")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            PrimaryButton(title: "Gerät abschließen") { beiZurueckZumTraining() }
                .testnotizElement("geraet.abschliessen", typ: "PrimaryButton")
            SecondaryButton(title: "Weiterer Satz") { modell.weitererSatz() }
                .testnotizElement("geraet.weiterer-satz", typ: "SecondaryButton")

            problemMelden
        }
    }

    /// In beiden Aktionsgruppen dieselbe Zeile -- zweimal getippt waere sie
    /// die naechste, die auseinanderlaeuft.
    private var problemMelden: some View {
        Button("Problem melden", action: beiProblem)
            .testnotizElement("geraet.problem", typ: "Button")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(DesignSystem.Color.textMuted)
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(PressButtonStyle())
            .accessibilityHint("Verhindert einen Steigerungsvorschlag")
    }

    /// Haptik beim Sichern, ueber das Profil abschaltbar (SS6: Haptik nie
    /// als einzige Rueckmeldung -- die sichtbare Bestaetigung bleibt in
    /// jedem Fall bestehen).
    @AppStorage(Einstellungen.vibrationBeimSichernKey) private var vibrationBeimSichern = true
}

/// Bindet Sheets und den Dreischritt an GeraetView. Getrennt, damit
/// GeraetView selbst nur den Screen beschreibt und in der Preview ohne
/// Umgebung lauffaehig bleibt.
struct GeraetScreen: View {
    @State var modell: GeraetModel
    let beiZurueckZumTraining: () -> Void

    @State private var uebungWechselnOffen = false
    @State private var problemOffen = false

    var body: some View {
        GeraetView(
            modell: modell,
            beiUebungWechseln: { uebungWechselnOffen = true },
            beiProblem: { problemOffen = true },
            beiZurueckZumTraining: beiZurueckZumTraining
        )
        .sheet(isPresented: $uebungWechselnOffen) {
            UebungWechselnSheet(modell: modell) { modell.uebungWechseln(zu: $0) }
        }
        .sheet(isPresented: $problemOffen) {
            ProblemSheet(modell: modell) {}
        }
        // Der Dreischritt: fullScreenCover verdeckt die Tab-Leiste.
        .fullScreenCover(isPresented: Binding(
            get: { modell.istErstkontakt || modell.kalibrierungOffen },
            set: { if !$0 { modell.kalibrierungOffen = false } }
        )) {
            if modell.kalibrierungOffen && !modell.istErstkontakt {
                // "aendern" ausserhalb des Dreischritts: ein eigenstaendiger
                // Screen ohne vorherigen Schritt, deshalb schliessen sowohl
                // der Zurueck-Chevron als auch "Speichern und weiter" das
                // Cover -- KalibrierungSchritt verlangt beiZurueck immer,
                // auch wenn es hier kein "davor" gibt, zu dem er fuehren
                // koennte.
                KalibrierungSchritt(
                    modell: modell, titel: "Deine Einstellung",
                    beiZurueck: { modell.kalibrierungOffen = false }
                ) {
                    modell.kalibrierungOffen = false
                }
            } else {
                // beiAbbruch teilt sich bewusst beiZurueckZumTraining: ein
                // fullScreenCover kennt kein Swipe-to-dismiss, und ein
                // Ausstieg aus dem Dreischritt soll denselben Weg zurueck
                // nehmen wie ein regulaeres "Zurueck zum Training" -- die
                // GeraetScreen-Instanz (und mit ihr das Modell) verschwindet
                // dabei ganz, statt dass hier zusaetzlich am Cover gedreht
                // werden muesste. erstkontaktAbschliessen() faellt bewusst
                // weg: ein Abbruch ist kein Abschluss, sonst zeigte
                // istErstkontakt beim naechsten Mal faelschlich "erledigt".
                ErstkontaktFlow(modell: modell, beiAbschluss: { modell.erstkontaktAbschliessen() },
                                beiAbbruch: beiZurueckZumTraining)
            }
        }
    }
}
