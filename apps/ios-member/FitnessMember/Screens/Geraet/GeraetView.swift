import SwiftUI

/// Main, GeraetWertRad und GeraetResttimer sind derselbe Screen in drei
/// Zustaenden -- keine Navigationsziele. designsystem.md SS7 verlangt
/// dieselbe Silhouette in Ruhe und Offen; zwei Views waeren hier der Fehler.
///
/// Die Pause ist der vierte Zustand und der einzige AUSSCHLIESSENDE: sie
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
                geraetUndUebung
                inhalt
            }
            .padding(.horizontal, 20)
            .padding(.bottom, DesignSystem.Spacing.s32)
            .animation(reduceMotion ? nil : DesignSystem.Motion.pause, value: modell.phase)
            .animation(reduceMotion ? nil : DesignSystem.Motion.oeffnen, value: modell.radOffen)
        }
        .background(DesignSystem.Color.bg)
        .navigationBarTitleDisplayMode(.inline)
        .task { await modell.kontextLaden() }
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
    }

    /// Die eine Stelle, an der der Screen entscheidet, was er ist.
    @ViewBuilder
    private var inhalt: some View {
        if let pause = modell.laufendePause {
            PausenRad(timer: pause,
                      beiVerlaengern: modell.pauseVerlaengern,
                      beiWeiter: modell.pauseBeenden)
                .transition(.opacity)
        } else if modell.phase == .abschluss {
            abschlussEntscheidung
                .transition(.opacity)
        } else {
            einstellung
            WertZeile(modell: modell)
            aktionen
            produktgrenze
        }
    }

    private var kopfzeile: some View {
        Text([modell.maschine.label, modell.maschine.locationNote]
            .compactMap { $0 }.joined(separator: " · ").uppercased())
            .font(DesignSystem.Typography.label)
            .tracking(1.5)
            .foregroundStyle(DesignSystem.Color.textFaint)
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
            if modell.phase == .eingabe {
                // Abweichung vom Artboard (Spec Abschnitt 9): dort accent. Die
                // eine Akzentflaeche des Screens ist die Hauptaktion.
                Button("andere Übung", action: beiUebungWechseln)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .frame(minHeight: 44)
                    .buttonStyle(PressButtonStyle())
            }
        }
    }

    /// Schrumpft auf eine Zeile, sobald die Raeder offen sind -- damit das
    /// Rad Platz hat (Artboard-Kommentar in GeraetWertRad.dc.html).
    @ViewBuilder
    private var einstellung: some View {
        if !modell.einstellwerte.isEmpty {
            if modell.radOffen {
                HStack {
                    Text(modell.einstellwerte.map { "\($0.label) \($0.anzeige)" }
                        .joined(separator: " · "))
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .lineLimit(1)
                    Spacer()
                    aendernKnopf
                }
            } else {
                HStack(alignment: .top) {
                    ForEach(modell.einstellwerte) { wert in
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                            Text(wert.label.uppercased())
                                .font(DesignSystem.Typography.label)
                                .tracking(1.5)
                                .foregroundStyle(DesignSystem.Color.textFaint)
                            Text(wert.anzeige)
                                .font(DesignSystem.Typography.wertSekundaer)
                                .foregroundStyle(DesignSystem.Color.text)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                    aendernKnopf
                }
                .padding(DesignSystem.Spacing.s16)
                .background(DesignSystem.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
            }
        }
    }

    private var aendernKnopf: some View {
        Button("ändern") { modell.kalibrierungOeffnen() }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(DesignSystem.Color.textMuted)
            .frame(minHeight: 44)
            .buttonStyle(PressButtonStyle())
    }

    private var aktionen: some View {
        VStack(spacing: DesignSystem.Spacing.s12) {
            // Bleibt im offenen Zustand sichtbar und sichert direkt -- kein
            // Schliessen-Tap dazwischen (Interaktionsbudget SS9).
            PrimaryButton(title: hauptaktion) {
                await modell.satzSichern(problemFlag: false, problemReason: nil)
            }
            .accessibilityLabel("\(hauptaktion), \(Zahlformat.gewichtGesprochen(modell.gewicht))")

            // Steht direkt unter dem Weg zum naechsten Satz, weil es die
            // andere Haelfte derselben Frage ist: noch einer, oder fertig
            // hier? Vorher gab es dafuer nur ein kleingesetztes "Zurueck zum
            // Training" ganz unten -- eine Navigation, kein Abschluss.
            SecondaryButton(title: "Gerät abschließen", action: beiZurueckZumTraining)

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
            SecondaryButton(title: "Weiterer Satz") { modell.weitererSatz() }

            problemMelden
        }
    }

    /// In beiden Aktionsgruppen dieselbe Zeile -- zweimal getippt waere sie
    /// die naechste, die auseinanderlaeuft.
    private var problemMelden: some View {
        Button("Problem melden", action: beiProblem)
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

    private var produktgrenze: some View {
        Text(modell.produktgrenze)
            .font(.system(size: 12))
            .foregroundStyle(DesignSystem.Color.textFaint)
            .lineSpacing(3)
    }
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
