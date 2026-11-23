import Foundation

/// Schaetzt live die Lage der Last im eigenen Bewegungsumfang (Tempo-Spec 6).
/// Rein: keine Uhr, keine Nebenlaeufigkeit, kein Zufall.
///
/// Die Vertikalbeschleunigung (Beschleunigung auf die Schwerkraftrichtung
/// projiziert minus deren Betrag) wird zu Geschwindigkeit und Weg
/// aufsummiert. Schrittweite ist die Sollrate, nicht die Zeitstempel-Differenz,
/// weil gebuendelte Messwerte denselben Zeitstempel tragen (Spec A 4.7).
/// An jedem Umkehrpunkt werden Nullpunkt und Hub neu gesetzt; der Unterschied
/// zur alten Schaetzung wird ueber `ueberblendDauer` eingeblendet statt zu springen.
/// Der Winkel wird nicht genutzt.
public struct Lageschaetzer: Sendable {
    private enum Halbwelle: Sendable {
        case wartet
        /// `vorzeichen` +1 aufwaerts, −1 abwaerts; `extrem` ist der weiteste Weg in dieser Richtung.
        case laeuft(vorzeichen: Double, extrem: Double, extremT: TimeInterval, stillSchritte: Int)
    }

    /// Geschwindigkeit, ab der eine Halbwelle als begonnen gilt und ab der ein
    /// Vorzeichenwechsel zaehlt (Hysterese). Gut unter den Spitzen von rund
    /// 0,25 m/s beim langsamen Ablassen.
    private static let geschwindigkeitSchwelle = 0.03
    /// So lange unter der Schwelle beendet eine Bewegung in Ruhe; ein
    /// durchlaufender Umkehrpunkt bleibt deutlich kuerzer darunter.
    private static let stillDauer = 0.3
    /// Abklingzeit der Geschwindigkeit, solange keine Halbwelle laeuft.
    /// In Bewegung wird nicht geleckt: das verzerrte den Weg.
    private static let ruheLeckDauer = 0.3
    /// So lange ruhige Messwerte, bevor die Schwerkraft nachgefuehrt wird.
    private static let ruheVorSchwerkraft = 0.5
    /// Zeitkonstante der Schwerkraft in Ruhe, wie im `Zaehler`.
    private static let schwerkraftDauer = 2.0
    private static let ruheBeschleunigungG = 0.01
    private static let ruheDrehrate = 5.0
    private static let ueberblendDauer = 0.15
    /// Hub vor dem ersten Umkehrpunkt ohne gemerkten Umfang (m). Waechst mit dem Weg.
    private static let anfangsHub = 0.3
    /// Kleinere Ausschlaege setzen den Hub nicht neu.
    private static let kleinsterHub = 0.02
    private static let erdbeschleunigung = 9.81

    private let dt: Double
    private let stillSchritte: Int
    private let ruheVorSchwerkraftSchritte: Int
    private let ueberblendSchritte: Int
    private let uebergeben: GemerkterUmfang?

    // Signalaufbereitung
    private var schwerkraft: Vektor3?
    private var ruhigeSchritte = 0
    private var geschwindigkeit = 0.0
    private var weg = 0.0

    // Umkehrpunkte und Einrasten
    private var halbwelle: Halbwelle = .wartet
    private var ankerWeg = 0.0
    private var ankerLage: Double
    private var hub: Double
    private var hubGemessen: Bool
    private var korrektur = 0.0
    private var korrekturRest = 0

    /// Auch das Ende einer Bewegung in Ruhe zaehlt als Umkehrpunkt. Waagerecht ist `oben` das ferne Ende.
    public private(set) var umkehrpunkte: [Umkehrpunkt] = []

    public init(rateHz: Double, umfang: GemerkterUmfang? = nil) {
        dt = 1 / rateHz
        stillSchritte = Int((Self.stillDauer * rateHz).rounded())
        ruheVorSchwerkraftSchritte = Int((Self.ruheVorSchwerkraft * rateHz).rounded())
        ueberblendSchritte = max(1, Int((Self.ueberblendDauer * rateHz).rounded()))
        uebergeben = umfang
        hub = umfang?.hub ?? Self.anfangsHub
        hubGemessen = umfang != nil
        ankerLage = umfang?.startetOben == true ? 1 : 0
    }

    /// Nach mindestens zwei Wiederholungen der Stand zum Merken, sonst der uebergebene.
    public var umfang: GemerkterUmfang? {
        guard umkehrpunkte.count >= 4 else { return uebergeben }
        return GemerkterUmfang(hub: hub, startetOben: umkehrpunkte.first?.oben == false, senkrecht: true)
    }

    public mutating func verarbeite(_ m: SensorMesswert) -> Lage {
        schwerkraftNachfuehren(m)
        aufsummieren(m)
        umkehrErkennen(m)
        if !hubGemessen { hub = max(hub, abs(weg - ankerWeg)) }

        var lage = lage(beiWeg: weg)
        if korrekturRest > 0 {
            lage += korrektur * Double(korrekturRest) / Double(ueberblendSchritte)
            korrekturRest -= 1
        }
        return Lage(t: m.t, lage: lage, richtung: richtung, sicher: !umkehrpunkte.isEmpty)
    }

    /// Nach einer Luecke traegt die aufsummierte Geschwindigkeit nicht mehr.
    public mutating func luecke(von: TimeInterval, bis: TimeInterval) {
        geschwindigkeit = 0
        halbwelle = .wartet
    }

    // MARK: - Aufbereitung

    private static func betrag(_ v: Vektor3) -> Double { (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot() }

    private mutating func schwerkraftNachfuehren(_ m: SensorMesswert) {
        guard let g = schwerkraft else { schwerkraft = m.beschleunigung; return }
        let ruhig = abs(Self.betrag(m.beschleunigung) - Self.betrag(g)) < Self.ruheBeschleunigungG
            && Self.betrag(m.drehrate) < Self.ruheDrehrate
        // Nur in Ruhe nachfuehren: in Bewegung waere die Beschleunigung der Last Teil der Schaetzung.
        guard ruhig, case .wartet = halbwelle else { ruhigeSchritte = 0; return }
        ruhigeSchritte += 1
        guard ruhigeSchritte >= ruheVorSchwerkraftSchritte else { return }
        let k = dt / (Self.schwerkraftDauer + dt)
        schwerkraft = Vektor3(x: g.x + k * (m.beschleunigung.x - g.x),
                              y: g.y + k * (m.beschleunigung.y - g.y),
                              z: g.z + k * (m.beschleunigung.z - g.z))
    }

    private mutating func aufsummieren(_ m: SensorMesswert) {
        guard let g = schwerkraft else { return }
        let gBetrag = Self.betrag(g)
        let entlang = (m.beschleunigung.x * g.x + m.beschleunigung.y * g.y + m.beschleunigung.z * g.z) / gBetrag
        let vertikal = (entlang - gBetrag) * Self.erdbeschleunigung
        let vorher = geschwindigkeit
        geschwindigkeit += vertikal * dt
        // Nur ruhige Messwerte lecken: am Beginn einer Bewegung, noch unter der
        // Schwelle, ginge sonst Geschwindigkeit verloren, die den ganzen Satz fehlte.
        if case .wartet = halbwelle, ruhigeSchritte > 0 { geschwindigkeit *= 1 - dt / Self.ruheLeckDauer }
        weg += (vorher + geschwindigkeit) / 2 * dt
    }

    // MARK: - Umkehrpunkte

    private mutating func umkehrErkennen(_ m: SensorMesswert) {
        let schwelle = Self.geschwindigkeitSchwelle
        switch halbwelle {
        case .wartet:
            if abs(geschwindigkeit) > schwelle {
                halbwelle = .laeuft(vorzeichen: geschwindigkeit > 0 ? 1 : -1, extrem: weg, extremT: m.t, stillSchritte: 0)
            }
        case let .laeuft(vorzeichen, extrem, extremT, still):
            var extrem = extrem, extremT = extremT
            if vorzeichen * (weg - extrem) > 0 { extrem = weg; extremT = m.t }
            if vorzeichen * geschwindigkeit < -schwelle {
                einrasten(oben: vorzeichen > 0, extrem: extrem, t: extremT)
                halbwelle = .laeuft(vorzeichen: -vorzeichen, extrem: weg, extremT: m.t, stillSchritte: 0)
            } else if abs(geschwindigkeit) < schwelle {
                if still + 1 >= stillSchritte {
                    einrasten(oben: vorzeichen > 0, extrem: extrem, t: extremT)
                    halbwelle = .wartet
                } else {
                    halbwelle = .laeuft(vorzeichen: vorzeichen, extrem: extrem, extremT: extremT, stillSchritte: still + 1)
                }
            } else {
                halbwelle = .laeuft(vorzeichen: vorzeichen, extrem: extrem, extremT: extremT, stillSchritte: 0)
            }
        }
    }

    /// Setzt Nullpunkt und Hub am Umkehrpunkt neu und blendet die Korrektur ein.
    private mutating func einrasten(oben: Bool, extrem: Double, t: TimeInterval) {
        let alt = lage(beiWeg: weg)
        let ausschlag = abs(extrem - ankerWeg)
        if ausschlag >= Self.kleinsterHub {
            hub = ausschlag
            hubGemessen = true
        }
        ankerWeg = extrem
        ankerLage = oben ? 1 : 0
        korrektur = alt - lage(beiWeg: weg)
        korrekturRest = ueberblendSchritte
        umkehrpunkte.append(Umkehrpunkt(t: t, oben: oben))
    }

    private func lage(beiWeg weg: Double) -> Double {
        ankerLage + (weg - ankerWeg) / hub
    }

    private var richtung: Wegrichtung {
        guard case let .laeuft(vorzeichen, _, _, _) = halbwelle else { return .unbekannt }
        return vorzeichen > 0 ? .hin : .rueck
    }
}
