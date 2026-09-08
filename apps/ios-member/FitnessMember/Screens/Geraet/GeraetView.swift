import SwiftUI

/// Main, GeraetWertRad und GeraetResttimer sind derselbe Screen in drei
/// Zustaenden -- keine Navigationsziele. designsystem.md SS7 verlangt
/// dieselbe Silhouette in Ruhe und Offen; zwei Views waeren hier der Fehler.
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
                // selbst -- derselbe Aufbau wie beim ResttimerBalken unten,
                // damit kein VStack einen leer rendernden Kindzustand
                // umschliesst (Review-Fund Task 15).
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
                if let pause = modell.pause, pause.laeuft() {
                    ResttimerBalken(timer: pause, beiVerlaengern: modell.pauseVerlaengern)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                einstellung
                WertZeile(modell: modell)
                aktionen
                produktgrenze
            }
            .padding(.horizontal, 20)
            .padding(.bottom, DesignSystem.Spacing.s32)
            .animation(reduceMotion ? nil : DesignSystem.Motion.pause, value: modell.pause)
            .animation(reduceMotion ? nil : DesignSystem.Motion.oeffnen, value: modell.radOffen)
        }
        .background(DesignSystem.Color.bg)
        .navigationBarTitleDisplayMode(.inline)
        .task { await modell.kontextLaden() }
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
            // Abweichung vom Artboard (Spec Abschnitt 9): dort accent. Die
            // eine Akzentflaeche des Screens ist die Hauptaktion.
            Button("andere Übung", action: beiUebungWechseln)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .frame(minHeight: 44)
                .buttonStyle(PressButtonStyle())
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
            reserveZeile
            // Bleibt im offenen Zustand sichtbar und sichert direkt -- kein
            // Schliessen-Tap dazwischen (Interaktionsbudget SS9).
            PrimaryButton(title: hauptaktion) {
                await modell.satzSichern(problemFlag: false, problemReason: nil)
            }
            .accessibilityLabel("\(hauptaktion), \(Zahlformat.gewichtGesprochen(modell.gewicht))")

            if modell.pause != nil {
                SecondaryButton(title: "Übung wechseln", action: beiUebungWechseln)
            }
            Button("Problem melden", action: beiProblem)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(PressButtonStyle())
                .accessibilityHint("Verhindert einen Steigerungsvorschlag")
            Button("← Zurück zum Training", action: beiZurueckZumTraining)
                .font(.system(size: 15))
                .foregroundStyle(DesignSystem.Color.textFaint)
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(PressButtonStyle())
        }
    }

    private var hauptaktion: String {
        "Satz \(modell.satzNummer) sichern"
    }

    /// RIR, laut SS9 optional und ueber das Profil abschaltbar. Der Schalter
    /// selbst gehoert zu Sub-Projekt 4; hier steht schon die Ablage, damit
    /// SP4 nur noch den Schalter anhaengen muss.
    @AppStorage("rirSichtbar") private var rirSichtbar = true

    @ViewBuilder
    private var reserveZeile: some View {
        if rirSichtbar {
            HStack(spacing: DesignSystem.Spacing.s8) {
                Text("RESERVE")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textFaint)
                Text("optional")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                Spacer()
                ForEach([0.0, 1.0, 2.0, 3.0, 4.0], id: \.self) { wert in
                    // Umriss, nie Flaeche -- die dokumentierte Abweichung vom
                    // Artboard (Spec Abschnitt 9).
                    Button(wert == 4 ? "4+" : String(Int(wert))) {
                        modell.reserve = modell.reserve == wert ? nil : wert
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(modell.reserve == wert
                                     ? DesignSystem.Color.text : DesignSystem.Color.textMuted)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Capsule().stroke(
                            modell.reserve == wert
                                ? DesignSystem.Color.text : DesignSystem.Color.line,
                            lineWidth: modell.reserve == wert ? 2 : 1)
                    )
                    .buttonStyle(PressButtonStyle())
                    .accessibilityLabel("Reserve \(Int(wert))\(wert == 4 ? " oder mehr" : "")")
                }
            }
        }
    }

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
