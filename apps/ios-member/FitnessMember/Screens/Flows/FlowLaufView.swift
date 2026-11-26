import SwiftUI

/// Der Follow-along-Lauf: Countdown, Arbeit, Pause, Fertig. Die View liest
/// nur `FlowLauf.zustand` im Takt einer TimelineView; die Zeit selbst steckt
/// in der Wanduhr-Rechnung des FlowLauf, nicht im Takt.
struct FlowLaufView: View {
    let flow: Flow
    let store: FlowStore
    let uebungen: FlowUebungen
    let videos: UebungsVideoVorrat

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
    /// Lokale Videodatei je Uebungs-ID, sobald sie da ist; fehlt sie, bleibt der Ring.
    @State private var videoURLs: [String: URL] = [:]

    init(flow: Flow, store: FlowStore, uebungen: FlowUebungen, videos: UebungsVideoVorrat) {
        self.flow = flow
        self.store = store
        self.uebungen = uebungen
        self.videos = videos
        _lauf = State(initialValue: FlowLauf(flow: flow))
    }

    /// Nur die Phase, ohne Restsekunden: ihr Wechsel loest Haptik und Abschluss aus.
    private enum Phase: Equatable { case countdown, arbeit(Int), pause(Int), fertig }

    private static func phase(_ z: FlowZustand) -> Phase {
        switch z {
        case .countdown: .countdown
        case .arbeit(let s, _): .arbeit(s)
        case .pause(let n, _): .pause(n)
        case .fertig: .fertig
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            let zustand = lauf.zustand
            let phase = Self.phase(zustand)
            VStack(spacing: DesignSystem.Spacing.s16) {
                inhalt(zustand)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                knoepfe(fertig: phase == .fertig)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, DesignSystem.Spacing.s16)
            .sensoryFeedback(.impact(weight: .medium), trigger: phase)
            .onChange(of: phase) { _, neu in
                if neu == .fertig { abschliessen(lauf.abgeschlossenerRun()) }
            }
        }
        .background(DesignSystem.Color.bg)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            lauf.starten()
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .task { await videosLaden() }
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

    @ViewBuilder
    private func inhalt(_ zustand: FlowZustand) -> some View {
        switch zustand {
        case .countdown(let rest):
            if let first = flow.schritte.first, let url = videoURL(first) {
                videoSchritt(first, url: url, ueberschrift: "GLEICH GEHT'S LOS", zeile: "Als Nächstes", restS: rest,
                             ring: FlowRing(rest: Double(rest) / Double(FlowAblauf.countdownS), beschriftung: "START IN",
                                            ziffer: "\(rest)", kante: 160))
            } else {
            VStack(spacing: DesignSystem.Spacing.s24) {
                ueberschrift("GLEICH GEHT'S LOS")
                FlowRing(rest: Double(rest) / Double(FlowAblauf.countdownS), beschriftung: "START IN",
                         ziffer: "\(rest)", kante: 240)
                Text(flow.schritte.first?.name ?? flow.titel)
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            }
        case .arbeit(let index, let rest):
            let schritt = flow.schritte[min(index, flow.schritte.count - 1)]
            if let url = videoURL(schritt) {
                VStack(spacing: DesignSystem.Spacing.s16) {
                    videoSchritt(schritt, url: url, ueberschrift: "SCHRITT \(index + 1) VON \(flow.schritte.count)",
                                 zeile: nil, restS: rest, mitBlickzeile: false,
                                 ring: FlowRing(rest: Double(rest) / Double(max(1, schritt.workS)), beschriftung: "ARBEIT",
                                                ziffer: "\(rest)", kante: 160))
                    if index + 1 < flow.schritte.count {
                        Text("Als Nächstes: \(flow.schritte[index + 1].name)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DesignSystem.Color.textMuted)
                            .multilineTextAlignment(.center)
                    }
                }
            } else {
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
                FlowRing(rest: Double(rest) / Double(max(1, schritt.workS)), beschriftung: "ARBEIT",
                         ziffer: "\(rest)", kante: 220)
                if index + 1 < flow.schritte.count {
                    Text("Als Nächstes: \(flow.schritte[index + 1].name)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .multilineTextAlignment(.center)
                }
            }
            }
        case .pause(let naechster, let rest):
            // FlowAblauf erzeugt nach dem letzten Schritt nie eine Pause; die
            // Klammer haelt den Zugriff trotzdem im Bereich.
            let schritt = flow.schritte[min(naechster, flow.schritte.count - 1)]
            if let url = videoURL(schritt) {
                videoSchritt(schritt, url: url, ueberschrift: "PAUSE", zeile: "Als Nächstes", restS: rest,
                             ring: FlowRing(rest: Double(rest) / Double(max(1, flow.schritte[max(0, min(naechster, flow.schritte.count) - 1)].restS)),
                                            beschriftung: "PAUSE", ziffer: "\(rest)", kante: 160))
            } else {
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
                FlowRing(rest: Double(rest) / Double(max(1, flow.schritte[max(0, min(naechster, flow.schritte.count) - 1)].restS)),
                         beschriftung: "PAUSE", ziffer: "\(rest)", kante: 160)
            }
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

    /// Schritt mit Video und der Restzeit oben rechts. Nur aufrufen, wenn die Datei da ist.
    private func videoSchritt(_ schritt: FlowSchritt, url: URL, ueberschrift: String, zeile: String?, restS: Int,
                              mitBlickzeile: Bool = true, ring: FlowRing) -> some View {
        FlowVideoSchritt(
            ueberschrift: ueberschrift, zeile: zeile, name: schritt.name, beschreibung: schritt.beschreibung,
            blickzeile: mitBlickzeile
                ? FlowAnzeige.pausenzeile(ansicht: uebungen.ansicht(schritt, mitKamera: Self.mitKamera)) : nil,
            videoURL: url, ringErsatz: ring)
            .overlay(alignment: .topTrailing) { FlowZeitPille(restS: restS) }
    }

    /// Die Videodatei des Schritts, wenn er ein Video zeigt und es geladen ist; sonst nil (Ring wie bisher).
    private func videoURL(_ schritt: FlowSchritt) -> URL? {
        guard let id = schritt.exerciseId,
              uebungen.ansicht(schritt, mitKamera: Self.mitKamera) != .ring else { return nil }
        return videoURLs[id]
    }

    /// Holt die Videos der Reihe nach, der erste Schritt zuerst; die naechsten
    /// liegen bereit, bevor ihre Pause beginnt. Ein Fehlschlag laesst den Ring stehen.
    private func videosLaden() async {
        for schritt in flow.schritte {
            guard let id = schritt.exerciseId, videoURLs[id] == nil,
                  uebungen.ansicht(schritt, mitKamera: Self.mitKamera) != .ring else { continue }
            if let url = await videos.datei(exerciseId: id) { videoURLs[id] = url }
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
