import Foundation

/// Wo im Flow man gerade ist. `schritt`/`naechster` sind 0-basiert.
enum FlowZustand: Equatable, Sendable {
    case countdown(restS: Int)
    case arbeit(schritt: Int, restS: Int)
    case pause(naechster: Int, restS: Int)
    case fertig
}

/// Zeitmaschine: der Zustand ist eine reine Funktion der vergangenen
/// Sekunden, berechnet ueber kumulierte Grenzen (keine Tick-Zaehler).
struct FlowAblauf: Sendable {
    static let countdownS = 3

    private enum Phase { case arbeit(Int), pause(Int) }
    /// Ende jeder Phase in Sekunden seit Start (inkl. Countdown).
    private let grenzen: [(ende: Double, phase: Phase)]

    /// Gesamtdauer ohne Countdown.
    let gesamtS: Int

    init(schritte: [FlowSchritt]) {
        var t = Double(Self.countdownS)
        var liste: [(ende: Double, phase: Phase)] = []
        for (i, s) in schritte.enumerated() {
            t += Double(s.workS)
            liste.append((t, .arbeit(i)))
            if s.restS > 0 {
                t += Double(s.restS)
                liste.append((t, .pause(i + 1)))
            }
        }
        grenzen = liste
        gesamtS = schritte.reduce(0) { $0 + $1.workS + $1.restS }
    }

    func zustand(nachS vergangen: Double) -> FlowZustand {
        let t = max(0, vergangen)
        let countdown = Double(Self.countdownS)
        if t < countdown { return .countdown(restS: Int((countdown - t).rounded(.up))) }
        for g in grenzen where t < g.ende {
            let rest = Int((g.ende - t).rounded(.up))
            switch g.phase {
            case .arbeit(let i): return .arbeit(schritt: i, restS: rest)
            case .pause(let n): return .pause(naechster: n, restS: rest)
            }
        }
        return .fertig
    }
}
