import Foundation
import Observation

/// Zustand eines laufenden Flows. Die Zeit ist Wanduhr-basiert:
/// verstrichen = jetzt - start - pausiert. Hintergrund und Sperrbildschirm
/// kosten damit nichts, und Pause/Fortsetzen verschiebt den Plan nicht.
/// Die Views lesen nur `zustand` (Takt aus der TimelineView).
@Observable
final class FlowLauf {
    let flow: Flow
    let runId: String

    private let jetzt: () -> Date
    private let ablauf: FlowAblauf
    private var start: Date?
    /// Seit wann pausiert wird; nil = laeuft.
    private var pausiertSeit: Date?
    /// Summe der abgeschlossenen Pausen in Sekunden.
    private var pausiert: TimeInterval = 0

    init(flow: Flow, jetzt: @escaping () -> Date = Date.init) {
        self.flow = flow
        self.jetzt = jetzt
        ablauf = FlowAblauf(schritte: flow.schritte)
        runId = UUID().uuidString.lowercased()
    }

    var istPausiert: Bool { pausiertSeit != nil }

    func starten() {
        guard start == nil else { return }
        start = jetzt()
    }

    func pausieren() {
        guard start != nil, pausiertSeit == nil else { return }
        pausiertSeit = jetzt()
    }

    func fortsetzen() {
        guard let seit = pausiertSeit else { return }
        pausiert += max(0, jetzt().timeIntervalSince(seit))
        pausiertSeit = nil
    }

    /// Sekunden seit Start ohne Pausen; waehrend einer Pause eingefroren.
    private func verstrichen() -> TimeInterval {
        guard let start else { return 0 }
        let bis = pausiertSeit ?? jetzt()
        return max(0, bis.timeIntervalSince(start) - pausiert)
    }

    var zustand: FlowZustand { ablauf.zustand(nachS: verstrichen()) }

    /// 1-basiert: der laufende Schritt, in der Pause der gerade beendete;
    /// nil im Countdown.
    private var letzterSchritt: Int? {
        switch zustand {
        case .countdown: nil
        case .arbeit(let schritt, _): schritt + 1
        case .pause(let naechster, _): naechster
        case .fertig: flow.schritte.count
        }
    }

    /// Bricht ab. Im Countdown gab es noch nichts zu speichern: nil.
    func abbrechen() -> FlowRunEingabe? {
        guard let start, let schritt = letzterSchritt else { return nil }
        return eingabe(start: start, ende: jetzt(), schritt: schritt, outcome: "aborted")
    }

    /// Nur im Zustand .fertig; das Ende ist der planmaessige Zeitpunkt, nicht
    /// der des Aufrufs (die App kann im Hintergrund fertig geworden sein).
    func abgeschlossenerRun() -> FlowRunEingabe? {
        guard let start, zustand == .fertig else { return nil }
        let dauer = Double(FlowAblauf.countdownS + ablauf.gesamtS) + pausiert
        return eingabe(start: start, ende: start.addingTimeInterval(dauer),
                       schritt: flow.schritte.count, outcome: "finished")
    }

    private func eingabe(start: Date, ende: Date, schritt: Int, outcome: String) -> FlowRunEingabe {
        let format = ISO8601DateFormatter()
        return FlowRunEingabe(id: runId, flowId: flow.id, startedAt: format.string(from: start),
                              endedAt: format.string(from: ende), lastStep: schritt, outcome: outcome)
    }
}
