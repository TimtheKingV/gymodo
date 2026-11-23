import Foundation

/// Grobe Lage fuer die Zeit, in der die Schaetzung des `Lageschaetzer` nicht
/// traegt (vor dem Gleichanteil, nach verlorenem Vertrauen).
///
/// Am Geraet dauert das oft mehrere Wiederholungen: Die Schaetzungen des
/// Gleichanteils streuen mit dem Rauschen, und bis dahin laeuft die aufsummierte
/// Geschwindigkeit weg. Diese Hilfe braucht keinen geschaetzten Gleichanteil:
/// Sobald die Periode gemessen ist, wird von der Beschleunigung ihr Mittel ueber
/// die letzte Wiederholung abgezogen (ueber eine ganze Wiederholung ist die wahre Beschleunigung null,
/// das Mittel ist also der Gleichanteil, ohne die Bewegung zu verschieben).
/// Geschwindigkeit und Weg werden dann leckend aufsummiert (Zeitkonstante zwei
/// Wiederholungen; die kausale Rechnung in `tools/sensorik-sim/tempo_nachrechnung.py`
/// nimmt eine, das eilt am kuenstlichen Satz zu weit vor);
/// was bleibt, ist ein langsamer Versatz des Wegs, und den nimmt das Einrasten
/// an den Extremen des Wegs heraus. Preis: ein kleiner Vorlauf und ein
/// Einschwingen, darum nie `sicher` und immer in 0…1.
struct Hilfslage: Sendable {
    private static let anfangsHub = 0.25
    private static let anfangsPeriode = 2.5
    private static let periodeGrenzen = 1.0...8.0
    /// Ein Extrem des Wegs gilt, wenn der Weg um diesen Anteil des Hubs zurueckgeht.
    private static let hystereseAnteil = 0.25
    /// Je Halbwelle aendert sich der Hub hoechstens um diesen Faktor.
    private static let hubFaktor = 2.0
    /// Zeitkonstante des Leckens in Perioden.
    private static let leckFaktor = 2.0
    private static let blendAnteil = 0.5
    private static let blendRateStill = 1.0

    private let dt: Double
    /// Aufsummierte Beschleunigung der letzten `periodeGrenzen.upperBound`
    /// Sekunden als Ring, fuer das Mittel ueber eine Wiederholung.
    private var summen: [Double]
    private var summe = 0.0
    private var periode = Self.anfangsPeriode
    private var geschwindigkeit = 0.0
    private var weg = 0.0
    private var ankerWeg = 0.0
    private var ankerLage: Double
    private var hub = Self.anfangsHub
    private var steigt: Bool
    private var extrem = 0.0
    private var extremSchritt = 0
    private var letzterGipfel: Int?
    private var periodeGemessen = false
    private var korrektur = 0.0
    private var schritt = 0

    init(dt: Double, ruhelage: Double) {
        self.dt = dt
        summen = [Double](repeating: 0, count: Int((Self.periodeGrenzen.upperBound / dt).rounded()) + 1)
        ankerLage = ruhelage
        steigt = ruhelage < 0.5
    }

    private var roh: Double { ankerLage + (weg - ankerWeg) / hub }

    /// `vertikal` in m/s², ohne Gleichanteil. Gibt die Lage in 0…1 zurueck.
    mutating func verarbeite(_ vertikal: Double) -> Double {
        schritt += 1
        summe += vertikal
        summen[schritt % summen.count] = summe
        // Erst mit gemessener Periode: Ein Mittel ueber eine falsche Dauer verschoebe die Bewegung.
        let fenster = periodeGemessen ? min(Int((periode / dt).rounded()), schritt - 1, summen.count - 1) : 0
        let mittel = fenster > 0 ? (summe - summen[(schritt - fenster) % summen.count]) / Double(fenster) : 0
        let leck = exp(-dt / (Self.leckFaktor * periode))
        geschwindigkeit = leck * (geschwindigkeit + (vertikal - mittel) * dt)
        weg = leck * (weg + geschwindigkeit * dt)
        let vorzeichen: Double = steigt ? 1 : -1
        if vorzeichen * (weg - extrem) > 0 {
            extrem = weg
            extremSchritt = schritt
        } else if vorzeichen * (extrem - weg) > Self.hystereseAnteil * hub {
            umkehren()
        }
        let lage = roh + korrektur
        let blend = max(Self.blendRateStill * dt, Self.blendAnteil * abs(geschwindigkeit) * dt / hub)
        korrektur = korrektur > 0 ? max(0, korrektur - blend) : min(0, korrektur + blend)
        return min(max(lage, 0), 1)
    }

    /// In Ruhe gilt die Ruhelage; die naechste Bewegung geht von ihr weg.
    mutating func ruhe(ruhelage: Double) {
        ankerWeg = weg
        ankerLage = ruhelage
        steigt = ruhelage < 0.5
        extrem = weg
        extremSchritt = schritt
        korrektur = 0
    }

    private mutating func umkehren() {
        // Von der angezeigten (geklemmten) Lage aus einblenden.
        let alt = min(max(roh + korrektur, 0), 1)
        hub = min(max(abs(extrem - ankerWeg), hub / Self.hubFaktor), hub * Self.hubFaktor)
        ankerWeg = extrem
        ankerLage = steigt ? 1 : 0
        if steigt {
            if let letzterGipfel {
                let p = Double(extremSchritt - letzterGipfel) * dt
                periode = min(max(p, Self.periodeGrenzen.lowerBound), Self.periodeGrenzen.upperBound)
                periodeGemessen = true
            }
            letzterGipfel = extremSchritt
        }
        steigt.toggle()
        extrem = weg
        extremSchritt = schritt
        korrektur = alt - roh
    }
}
