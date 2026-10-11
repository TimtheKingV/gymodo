import Charts
import SwiftUI

/// Eine Kurve ohne Achsen fuer eine Zeile -- die Bewegung auf einen Blick,
/// die Zahl steht daneben (Testnotiz 11.10., #4).
///
/// Die Farbe kommt von aussen: in der Fortschrittszeile traegt sie den
/// Trend, eine bewusste Ausnahme von designsystem.md SS13 (eine Serie,
/// eine Farbe).
struct Minikurve: View {
    let werte: [Double]
    let farbe: Color

    var body: some View {
        Chart {
            ForEach(Array(werte.enumerated()), id: \.offset) { index, wert in
                LineMark(x: .value("Tag", index), y: .value("Last", wert))
                    .foregroundStyle(farbe)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            if let letzter = werte.last {
                PointMark(x: .value("Tag", werte.count - 1), y: .value("Last", letzter))
                    .foregroundStyle(farbe)
                    .symbolSize(24)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: bereich)
        .accessibilityHidden(true)
    }

    /// Mit Rand, damit Linie und Endpunkt nicht an der Kante abgeschnitten
    /// werden; eine flache Reihe bekommt kuenstliche Hoehe, sonst laege sie
    /// auf dem Rand statt in der Mitte.
    private var bereich: ClosedRange<Double> {
        guard let tief = werte.min(), let hoch = werte.max() else { return 0...1 }
        let rand = max((hoch - tief) * 0.15, 1)
        return (tief - rand)...(hoch + rand)
    }
}
