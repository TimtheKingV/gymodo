import Foundation

/// Schaetzt live die Lage der Last im eigenen Bewegungsumfang (Tempo-Spec 6).
/// Rein: keine Uhr, keine Nebenlaeufigkeit, kein Zufall.
///
/// Die Vertikalbeschleunigung (Beschleunigung auf die Schwerkraftrichtung
/// projiziert minus deren Betrag, abzueglich des geschaetzten Gleichanteils)
/// wird zu Geschwindigkeit und Weg aufsummiert. Schrittweite ist die Sollrate,
/// nicht die Zeitstempel-Differenz, weil gebuendelte Messwerte denselben
/// Zeitstempel tragen (Spec A 4.7).
/// An jedem Umkehrpunkt werden Nullpunkt und Hub neu gesetzt (Einrasten). Jeder
/// Sprung der Schaetzung wird eingeblendet statt angezeigt. Der Winkel wird nicht genutzt.
public struct Lageschaetzer: Sendable {
    private struct Extrem: Sendable {
        var weg: Double
        var schritt: Int
        var t: TimeInterval
    }

    private enum Halbwelle: Sendable {
        /// Keine Bewegung; ab `ruheSchritte` ist das Ruhe.
        case wartet(schritte: Int)
        /// `vorzeichen` +1 aufwaerts, −1 abwaerts; `extrem` ist der weiteste Weg in dieser Richtung.
        /// `still` zaehlt Messwerte unter der Schwelle; ein Halt mitten im Weg bleibt `laeuft`.
        case laeuft(vorzeichen: Double, extrem: Extrem, still: Int)
    }

    /// Geschwindigkeit, ab der eine Halbwelle als begonnen gilt und ab der ein
    /// Vorzeichenwechsel zaehlt (Hysterese). Gut unter den Spitzen von rund
    /// 0,16 m/s bei 4 s je Weg.
    private static let geschwindigkeitSchwelle = 0.03
    /// So lange unter der Schwelle nahe der Ruhelage beendet eine Bewegung, die
    /// auf sie zulief; ein durchlaufender Umkehrpunkt bleibt kuerzer darunter.
    /// Anderswo ist Stillstand ein Halt: kein Umkehrpunkt, die Lage bleibt stehen.
    private static let stillDauer = 0.3
    /// Abstand zur Ruhelage (in Lage-Einheiten), in dem Stillstand das Ende der Bewegung ist.
    private static let ruheNaehe = 0.3
    /// So lange ohne Bewegung, bis Ruhe gilt: dann Lage = Ruhelage, `sicher = false`.
    /// Laenger als die Pause an einem langsamen unteren Umkehrpunkt.
    private static let ruheDauer = 1.0
    /// Abklingzeit der Geschwindigkeit, solange keine Halbwelle laeuft.
    /// In Bewegung wird nicht geleckt: das verzerrte den Weg.
    private static let ruheLeckDauer = 0.3
    /// So lange ruhige Messwerte, bevor die Schwerkraft nachgefuehrt wird.
    private static let ruheVorSchwerkraft = 0.5
    /// Zeitkonstante der Schwerkraft in Ruhe, wie im `Zaehler`.
    private static let schwerkraftDauer = 2.0
    private static let ruheBeschleunigungG = 0.01
    private static let ruheDrehrate = 5.0
    /// Mindestdauer des Einblendens; groessere Spruenge dauern laenger.
    private static let ueberblendDauer = 0.15
    /// Hoechstens so viel Lage je Messwert blendet das Einrasten ein. Zusammen mit
    /// rund 0,02 je Messwert eigener Bewegung beim Kraftweg bleibt der Punkt unter 0,08.
    private static let groessterBlendSchritt = 0.04
    /// Hub vor dem ersten Umkehrpunkt ohne gemerkten Umfang (m). Waechst mit dem Weg.
    private static let anfangsHub = 0.3
    /// Kleinere Ausschlaege setzen den Hub nicht neu.
    private static let kleinsterHub = 0.02
    private static let erdbeschleunigung = 9.81

    private let dt: Double
    private let stillSchritte: Int
    private let ruheSchritte: Int
    private let ruheVorSchwerkraftSchritte: Int
    private let ueberblendSchritte: Int
    private let uebergeben: GemerkterUmfang?
    private let ruhelage: Double

    // Signalaufbereitung
    private var schritt = 0
    private var schwerkraft: Vektor3?
    private var ruhigeSchritte = 0
    private var gleichanteil = Gleichanteil()
    private var geschwindigkeit = 0.0
    private var weg = 0.0
    /// Letzter Messwert, an dem die Geschwindigkeit sicher null war (Ruhe, Luecke).
    /// Ein neu geschaetzter Gleichanteil wird ab hier nachgetragen.
    private var ruhendSchritt = 0
    /// Messwert des letzten Ankers; der Weg davor zaehlt nicht mehr.
    private var ankerSchritt = 0

    // Umkehrpunkte und Einrasten
    private var halbwelle: Halbwelle = .wartet(schritte: 0)
    private var ankerWeg = 0.0
    private var ankerLage: Double
    private var hub: Double
    private var hubGemessen: Bool
    private var korrektur = 0.0
    private var korrekturSchritt = 0.0
    private var letzteAusgabe: Double
    /// Messwert der ersten Schaetzung des Gleichanteils und wie viele Umkehrpunkte
    /// mit einem Extrem danach erkannt sind. Vorher kann der Gleichanteil
    /// Umkehrpunkte vortaeuschen oder verschlucken, und ein Extrem bis zur
    /// Schaetzung liegt auf dem berichtigten, nicht auf dem wahren Weg: Solche
    /// Halbwellen setzen den Hub nicht, die Lage bleibt in 0…1 und ist nicht sicher.
    /// Ab dem zweiten Umkehrpunkt danach traegt sie.
    private var gleichanteilSchritt: Int?
    private var umkehrpunkteSeitGleichanteil = 0
    private var vertraut: Bool { umkehrpunkteSeitGleichanteil >= 2 }

    /// Auch das Ende einer Bewegung in Ruhe zaehlt als Umkehrpunkt. Waagerecht ist `oben` das ferne Ende.
    public private(set) var umkehrpunkte: [Umkehrpunkt] = []

    public init(rateHz: Double, umfang: GemerkterUmfang? = nil) {
        dt = 1 / rateHz
        stillSchritte = Int((Self.stillDauer * rateHz).rounded())
        ruheSchritte = Int((Self.ruheDauer * rateHz).rounded())
        ruheVorSchwerkraftSchritte = Int((Self.ruheVorSchwerkraft * rateHz).rounded())
        ueberblendSchritte = max(1, Int((Self.ueberblendDauer * rateHz).rounded()))
        uebergeben = umfang
        hub = umfang?.hub ?? Self.anfangsHub
        hubGemessen = umfang != nil
        ruhelage = umfang?.startetOben == true ? 1 : 0
        ankerLage = ruhelage
        letzteAusgabe = ruhelage
    }

    /// Nach mindestens zwei Wiederholungen der Stand zum Merken, sonst der uebergebene.
    public var umfang: GemerkterUmfang? {
        guard umkehrpunkte.count >= 4 else { return uebergeben }
        return GemerkterUmfang(hub: hub, startetOben: umkehrpunkte.first?.oben == false, senkrecht: true)
    }

    public mutating func verarbeite(_ m: SensorMesswert) -> Lage {
        schritt += 1
        schwerkraftNachfuehren(m)
        aufsummieren(m)
        umkehrErkennen(m)
        if !hubGemessen { hub = max(hub, abs(weg - ankerWeg)) }

        let inRuhe = imRuhezustand
        if inRuhe { ruheHalten() }
        var lage = lage(beiWeg: weg) + korrektur
        if !vertraut { lage = min(max(lage, 0), 1) }
        korrektur = korrektur > 0 ? max(0, korrektur - korrekturSchritt) : min(0, korrektur + korrekturSchritt)
        letzteAusgabe = lage
        return Lage(t: m.t, lage: lage, richtung: richtung, sicher: vertraut && !inRuhe)
    }

    /// Nach einer Luecke traegt die aufsummierte Geschwindigkeit nicht mehr.
    public mutating func luecke(von: TimeInterval, bis: TimeInterval) {
        geschwindigkeit = 0
        halbwelle = .wartet(schritte: 0)
        gleichanteil.zuruecksetzen()
        ruhendSchritt = schritt
        ankerSchritt = schritt
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
        let alterGleichanteil = gleichanteil.wert
        if gleichanteil.verarbeite(vertikal, schritt: schritt, dt: dt) {
            if gleichanteilSchritt == nil { gleichanteilSchritt = schritt }
            if gleichanteil.wert != alterGleichanteil { gleichanteilNachtragen(gleichanteil.wert - alterGleichanteil) }
        }
        let vorher = geschwindigkeit
        geschwindigkeit += (vertikal - gleichanteil.wert) * dt
        // Nur ruhige Messwerte lecken: am Beginn einer Bewegung, noch unter der
        // Schwelle, ginge sonst Geschwindigkeit verloren, die den ganzen Satz fehlte.
        if case .wartet = halbwelle, ruhigeSchritte > 0 { geschwindigkeit *= 1 - dt / Self.ruheLeckDauer }
        weg += (vorher + geschwindigkeit) / 2 * dt
    }

    /// Ein neuer Gleichanteil gilt seit dem letzten Messwert mit sicher ruhender
    /// Last: Die Geschwindigkeit wird ab dort berichtigt, Weg und Extrem ab dem
    /// letzten Anker (davor zaehlt der Weg nicht mehr). Nur ab dem letzten
    /// Umkehrpunkt zu berichtigen liesse einen festen Geschwindigkeitsfehler stehen.
    private mutating func gleichanteilNachtragen(_ d: Double) {
        let alt = lage(beiWeg: weg)
        func seitRuhe(_ s: Int) -> Double { Double(max(s, ruhendSchritt) - ruhendSchritt) * dt }
        let tau = seitRuhe(schritt), tauAnker = seitRuhe(ankerSchritt)
        geschwindigkeit -= d * tau
        weg -= d * (tau * tau - tauAnker * tauAnker) / 2
        if case .laeuft(let vorzeichen, var extrem, let still) = halbwelle {
            let tauExtrem = max(seitRuhe(extrem.schritt), tauAnker)
            extrem.weg -= d * (tauExtrem * tauExtrem - tauAnker * tauAnker) / 2
            if vorzeichen * (weg - extrem.weg) > 0 { extrem = Extrem(weg: weg, schritt: schritt, t: extrem.t) }
            halbwelle = .laeuft(vorzeichen: vorzeichen, extrem: extrem, still: still)
            if !hubGemessen { hub = max(Self.anfangsHub, abs(extrem.weg - ankerWeg)) }
        }
        einblenden(von: alt)
    }

    // MARK: - Umkehrpunkte

    private mutating func umkehrErkennen(_ m: SensorMesswert) {
        let schwelle = Self.geschwindigkeitSchwelle
        switch halbwelle {
        case let .wartet(schritte):
            if abs(geschwindigkeit) > schwelle {
                halbwelle = .laeuft(vorzeichen: geschwindigkeit > 0 ? 1 : -1,
                                    extrem: Extrem(weg: weg, schritt: schritt, t: m.t), still: 0)
            } else {
                halbwelle = .wartet(schritte: schritte + 1)
            }
        case let .laeuft(vorzeichen, extrem, still):
            var extrem = extrem
            if vorzeichen * (weg - extrem.weg) > 0 { extrem = Extrem(weg: weg, schritt: schritt, t: m.t) }
            if vorzeichen * geschwindigkeit < -schwelle {
                einrasten(oben: vorzeichen > 0, extrem: extrem)
                halbwelle = .laeuft(vorzeichen: -vorzeichen, extrem: Extrem(weg: weg, schritt: schritt, t: m.t), still: 0)
            } else if abs(geschwindigkeit) < schwelle {
                let still = still + 1
                if still >= stillSchritte, endetInRuhelage(vorzeichen: vorzeichen) {
                    einrasten(oben: vorzeichen > 0, extrem: extrem)
                    halbwelle = .wartet(schritte: still)
                } else {
                    halbwelle = .laeuft(vorzeichen: vorzeichen, extrem: extrem, still: still)
                }
            } else {
                halbwelle = .laeuft(vorzeichen: vorzeichen, extrem: extrem, still: 0)
            }
        }
    }

    /// Stillstand beendet die Bewegung nur, wenn sie auf die Ruhelage zulief und nahe bei ihr steht.
    private func endetInRuhelage(vorzeichen: Double) -> Bool {
        let aufRuhelageZu = (ruhelage > 0.5) == (vorzeichen > 0)
        return aufRuhelageZu && abs(lage(beiWeg: weg) - ruhelage) <= Self.ruheNaehe
    }

    /// Setzt Nullpunkt und Hub am Umkehrpunkt neu und blendet die Korrektur ein.
    private mutating func einrasten(oben: Bool, extrem: Extrem) {
        let alt = lage(beiWeg: weg)
        let ausschlag = abs(extrem.weg - ankerWeg)
        // Nur eine Halbwelle, die ganz nach der ersten Schaetzung des Gleichanteils liegt, misst den Hub.
        if umkehrpunkteSeitGleichanteil >= 1, ausschlag >= Self.kleinsterHub {
            hub = ausschlag
            hubGemessen = true
        }
        if let gleichanteilSchritt, extrem.schritt > gleichanteilSchritt { umkehrpunkteSeitGleichanteil += 1 }
        ankerWeg = extrem.weg
        ankerLage = oben ? 1 : 0
        ankerSchritt = extrem.schritt
        einblenden(von: alt)
        umkehrpunkte.append(Umkehrpunkt(t: extrem.t, oben: oben))
    }

    // MARK: - Ruhe und Ausgabe

    private var imRuhezustand: Bool {
        guard case let .wartet(schritte) = halbwelle else { return false }
        return schritte >= ruheSchritte
    }

    /// In Ruhe gilt die Ruhelage; beim Eintritt wird der Unterschied eingeblendet.
    private mutating func ruheHalten() {
        let alt = lage(beiWeg: weg)
        ankerWeg = weg
        ankerLage = ruhelage
        if case .wartet(ruheSchritte) = halbwelle { einblenden(von: alt) }
        ruhendSchritt = schritt
        ankerSchritt = schritt
        gleichanteil.zuruecksetzen()
    }

    /// Haelt die angezeigte Lage stetig, wenn sich die Abbildung von Weg auf Lage aendert.
    private mutating func einblenden(von alt: Double) {
        korrektur += alt - lage(beiWeg: weg)
        // Solange in 0…1 gehalten wird, von der angezeigten Lage aus einblenden.
        if !vertraut { korrektur = letzteAusgabe - lage(beiWeg: weg) }
        korrekturSchritt = min(abs(korrektur) / Double(ueberblendSchritte), Self.groessterBlendSchritt)
    }

    private func lage(beiWeg weg: Double) -> Double {
        ankerLage + (weg - ankerWeg) / hub
    }

    private var richtung: Wegrichtung {
        guard case let .laeuft(vorzeichen, _, _) = halbwelle else { return .unbekannt }
        return vorzeichen > 0 ? .hin : .rueck
    }
}
