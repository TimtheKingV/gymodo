import AVFoundation
import SwiftUI

/// Der Follow-along-Lauf: Countdown, Arbeit, Pause, Fertig. Die View liest
/// nur `FlowLauf.zustand` im Takt einer TimelineView; die Zeit selbst steckt
/// in der Wanduhr-Rechnung des FlowLauf, nicht im Takt.
struct FlowLaufView: View {
    let flow: Flow
    let store: FlowStore
    let uebungen: FlowUebungen
    let videos: UebungsVideoVorrat
    /// Die Ansicht je Schritt, einmal berechnet statt je Takt.
    private let ansichten: [FlowSchrittAnsicht]

    /// Erkennt Kamera-Schritte (Blickzeile in der Pause). Die Arbeitsphase eines
    /// Kamera-Schritts zeigt bis zur Kamera-Ansicht dasselbe wie ein Video-Schritt.
    private static let mitKamera = true

    @Environment(\.dismiss) private var dismiss
    @State private var lauf: FlowLauf
    @State private var rueckfrage = false
    /// Lief schon vor der Rueckfrage eine Pause des Nutzers?
    @State private var warPausiert = false
    /// Der Run wird genau einmal gemeldet.
    @State private var beendet = false
    /// Die vorbereiteten Videos; fehlt eines, bleibt der Ring.
    @State private var videoStand: FlowVideoStand
    /// Die laufende Phase, fuer das Nachladen der Videos bei jedem Wechsel.
    @State private var aktuellePhase = FlowPhase.countdown

    /// `vorgeladen`: schon fertige Videos je Uebungs-ID (aus der Detailansicht),
    /// damit der Countdown sein Video von Anfang an zeigen kann.
    init(flow: Flow, store: FlowStore, uebungen: FlowUebungen, videos: UebungsVideoVorrat,
         vorgeladen: [String: AVAsset] = [:]) {
        self.flow = flow
        self.store = store
        self.uebungen = uebungen
        self.videos = videos
        ansichten = flow.schritte.map { uebungen.ansicht($0, mitKamera: Self.mitKamera) }
        _videoStand = State(initialValue: FlowVideoStand(vorgeladen: vorgeladen))
        _lauf = State(initialValue: FlowLauf(flow: flow))
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            let zustand = lauf.zustand
            let phase = FlowPhase(zustand)
            VStack(spacing: DesignSystem.Spacing.s16) {
                if let seite = videoSeite(zustand, phase) {
                    // Oben ausgerichtet, die Pille am oberen Rand des Bereichs: in jeder
                    // Phase an derselben Stelle, unabhaengig von der Textlaenge.
                    videoInhalt(seite.seite, video: seite.video)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .overlay(alignment: .topTrailing) { FlowZeitPille(restS: seite.seite.restS) }
                } else {
                    inhalt(zustand)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                knoepfe(fertig: phase == .fertig)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, DesignSystem.Spacing.s16)
            .sensoryFeedback(.impact(weight: .medium), trigger: phase)
            .onChange(of: phase) { _, neu in
                aktuellePhase = neu
                if neu == .fertig { abschliessen(lauf.abgeschlossenerRun()) }
            }
        }
        .background(DesignSystem.Color.bg)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            lauf.starten()
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .task(id: aktuellePhase) { await videosLaden(aktuellePhase) }
        .onChange(of: rueckfrage) { _, offen in
            // Waehrend der Rueckfrage steht die Uhr, sonst ginge Zeit verloren.
            if offen {
                warPausiert = lauf.istPausiert
                lauf.pausieren()
            } else if !warPausiert && !beendet {
                lauf.fortsetzen()
            }
        }
        .confirmationDialog("Flow abbrechen?", isPresented: $rueckfrage, titleVisibility: .visible) {
            Button("Abbrechen und beenden", role: .destructive) {
                abschliessen(lauf.abbrechen())
                dismiss()
            }
            Button("Weitermachen", role: .cancel) {}
        }
    }

    // MARK: - Phasen

    /// Die Video-Seite der Phase, wenn ihr Schritt ein Video zeigt und es beim
    /// Beginn der Phase schon bereit war; sonst nil (Ring und Layout wie bisher).
    private func videoSeite(_ zustand: FlowZustand, _ phase: FlowPhase) -> (seite: FlowVideoSeite, video: AVAsset)? {
        guard let seite = FlowVideoPlan.seite(zustand: zustand, schritte: flow.schritte),
              ansichten[seite.schrittIndex] != .ring,
              let video = videoStand.asset(fuer: flow.schritte[seite.schrittIndex].exerciseId, in: phase)
        else { return nil }
        return (seite, video)
    }

    /// Eine einzige View-Struktur fuer Countdown, Pause und Arbeit: bleibt das
    /// Video beim Phasenwechsel dasselbe, baut sich nichts neu auf.
    private func videoInhalt(_ seite: FlowVideoSeite, video: AVAsset) -> some View {
        let schritt = flow.schritte[seite.schrittIndex]
        return VStack(spacing: DesignSystem.Spacing.s16) {
            FlowVideoSchritt(
                ueberschrift: seite.ueberschrift, zeile: seite.zeile, name: schritt.name,
                beschreibung: schritt.beschreibung,
                blickzeile: seite.mitBlickzeile
                    ? FlowAnzeige.pausenzeile(ansicht: ansichten[seite.schrittIndex]) : nil,
                video: video, ringErsatz: arbeitRing(rest: seite.restS, schritt: schritt, kante: 160))
            if let naechster = seite.naechsterName {
                Text("Als Nächstes: \(naechster)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func countdownRing(rest: Int, kante: CGFloat) -> FlowRing {
        FlowRing(rest: Double(rest) / Double(FlowAblauf.countdownS), beschriftung: "START IN",
                 ziffer: "\(rest)", kante: kante)
    }

    private func arbeitRing(rest: Int, schritt: FlowSchritt, kante: CGFloat) -> FlowRing {
        FlowRing(rest: Double(rest) / Double(max(1, schritt.workS)), beschriftung: "ARBEIT",
                 ziffer: "\(rest)", kante: kante)
    }

    /// Die Pause gehoert zum Schritt davor; `naechster` ist der kommende.
    private func pauseRing(rest: Int, naechster: Int, kante: CGFloat) -> FlowRing {
        let davor = flow.schritte[max(0, min(naechster, flow.schritte.count) - 1)]
        return FlowRing(rest: Double(rest) / Double(max(1, davor.restS)), beschriftung: "PAUSE",
                        ziffer: "\(rest)", kante: kante)
    }

    @ViewBuilder
    private func inhalt(_ zustand: FlowZustand) -> some View {
        switch zustand {
        case .countdown(let rest):
            VStack(spacing: DesignSystem.Spacing.s24) {
                ueberschrift("GLEICH GEHT'S LOS")
                countdownRing(rest: rest, kante: 240)
                Text(flow.schritte.first?.name ?? flow.titel)
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
        case .arbeit(let index, let rest):
            let schritt = flow.schritte[min(index, flow.schritte.count - 1)]
            VStack(spacing: DesignSystem.Spacing.s16) {
                ueberschrift("SCHRITT \(index + 1) VON \(flow.schritte.count)")
                Text(schritt.name)
                    .font(DesignSystem.Typography.detailScreentitel)
                    .foregroundStyle(DesignSystem.Color.text)
                    .multilineTextAlignment(.center)
                if let text = schritt.beschreibung, !text.isEmpty {
                    Text(text)
                        .font(DesignSystem.Typography.fliesstext)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .multilineTextAlignment(.center)
                }
                arbeitRing(rest: rest, schritt: schritt, kante: 220)
                if index + 1 < flow.schritte.count {
                    Text("Als Nächstes: \(flow.schritte[index + 1].name)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .multilineTextAlignment(.center)
                }
            }
        case .pause(let naechster, let rest):
            // FlowAblauf erzeugt nach dem letzten Schritt nie eine Pause; die
            // Klammer haelt den Zugriff trotzdem im Bereich.
            let schritt = flow.schritte[min(naechster, flow.schritte.count - 1)]
            VStack(spacing: DesignSystem.Spacing.s24) {
                ueberschrift("PAUSE")
                Text("Als Nächstes")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.accent)
                Text(schritt.name)
                    .font(DesignSystem.Typography.screentitel)
                    .foregroundStyle(DesignSystem.Color.text)
                    .multilineTextAlignment(.center)
                pauseRing(rest: rest, naechster: naechster, kante: 160)
            }
        case .fertig:
            VStack(spacing: DesignSystem.Spacing.s16) {
                ueberschrift("GESCHAFFT")
                Text(flow.titel)
                    .font(DesignSystem.Typography.detailScreentitel)
                    .foregroundStyle(DesignSystem.Color.text)
                    .multilineTextAlignment(.center)
                Text(FlowAnzeige.uhr(flow.dauerS))
                    .font(DesignSystem.Typography.wertHeld)
                    .foregroundStyle(DesignSystem.Color.accent)
                Text("\(flow.schritte.count) Schritte absolviert")
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
        }
    }

    /// Holt bei jedem Phasenwechsel die fehlenden Videos des gezeigten und des
    /// folgenden Schritts, den gezeigten zuerst; ein frueherer Fehlschlag wird so
    /// wiederholt. Endet mit der Phase und mit dem Schliessen der Ansicht.
    private func videosLaden(_ phase: FlowPhase) async {
        for id in FlowVideoStand.fehlende(schritte: flow.schritte, ansichten: ansichten, phase: phase,
                                          stand: videoStand) {
            if Task.isCancelled { return }
            guard let asset = await FlowVideoStand.laden(exerciseId: id, videos: videos),
                  !Task.isCancelled else { continue }
            videoStand.eingetroffen(id, asset: asset, in: aktuellePhase)
        }
    }

    private func ueberschrift(_ text: String) -> some View {
        Text(text)
            .font(DesignSystem.Typography.label)
            .tracking(1.5)
            .foregroundStyle(DesignSystem.Color.textMuted)
    }

    // MARK: - Knoepfe

    @ViewBuilder
    private func knoepfe(fertig: Bool) -> some View {
        VStack(spacing: DesignSystem.Spacing.s8) {
            if fertig {
                PrimaryButton(title: "Fertig") { dismiss() }
            } else {
                PrimaryButton(title: lauf.istPausiert ? "Weiter" : "Anhalten") {
                    if lauf.istPausiert { lauf.fortsetzen() } else { lauf.pausieren() }
                }
                SecondaryButton(title: "Abbrechen") { rueckfrage = true }
            }
        }
    }

    // MARK: - Abschluss

    /// Meldet den Run genau einmal; der Store sichert ihn vor dem Senden.
    private func abschliessen(_ run: FlowRunEingabe?) {
        guard !beendet else { return }
        beendet = true
        UIApplication.shared.isIdleTimerDisabled = false
        guard let run else { return }
        let store = store
        Task { await store.runAbschliessen(run) }
    }
}
