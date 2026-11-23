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
    /// Eine Pause unten bis 2 s gehoert zum Satz (Produktregel), mit Reserve.
    private static let ruheDauer = 2.5
    /// Abklingzeit der Geschwindigkeit, solange keine Halbwelle laeuft.
    /// In Bewegung wird nicht geleckt: das verzerrte den Weg.
    private static let ruheLeckDauer = 0.3
    /// So lange ruhige Messwerte, bevor die Schwerkraft nachgefuehrt wird.
    private static let ruheVorSchwerkraft = 0.5
    /// Zeitkonstante der Schwerkraft in Ruhe, wie im `Zaehler`.
    private static let schwerkraftDauer = 2.0
    private static let ruheBeschleunigungG = 0.01
    private static let ruheDrehrate = 5.0
    /// Eingeblendet wird im Takt der eigenen Bewegung: je Messwert hoechstens dieser
    /// Anteil des Wegs, den die Last gerade selbst zuruecklegt. So kehrt der Punkt
    /// nie um und wird hoechstens um diesen Anteil schneller, bei jedem Tempo.
    private static let blendAnteil = 0.5
    /// Im Stillstand (Lage je Sekunde): ein Rest von 0,1 ist nach 0,2 s weg.
    private static let blendRateStill = 0.5
    /// Hub vor dem ersten Umkehrpunkt ohne gemerkten Umfang (m). Waechst mit dem Weg.
    private static let anfangsHub = 0.3
    /// Ab diesem Geschwindigkeitsfehler (m/s) an einem gepaarten Extrem gilt die
    /// Schaetzung als grob falsch und wird dort null gesetzt. Am Extrem steht die
    /// Last nur bis auf etwa Beschleunigung mal Schritt still (bis 0,04 m/s bei 1 s
    /// je Weg); kleinere Fehler zu "berichtigen" setzte genau diesen Fehler ein.
    private static let groberGeschwindigkeitsfehler = 0.1
    /// Kleinere Ausschlaege setzen den Hub nicht neu.
    private static let kleinsterHub = 0.02
    /// Ausserhalb davon traegt eine sichere Lage nicht mehr.
    private static let haltbar = -0.5...1.5
    /// Anteil des Hubs, ab dem eine Halbwelle mit gemessenem Hub zaehlt.
    private static let kleinsteHalbwelle = 0.25
    /// Zwei gleichartige Umkehrpunkte gehoeren zu aufeinanderfolgenden
    /// Wiederholungen, wenn sie so weit auseinander liegen (s).
    private static let kleinsteWiederholung = 0.8
    private static let groessteWiederholung = 12.0
    private static let erdbeschleunigung = 9.81

    private let dt: Double
    private let stillSchritte: Int
    private let ruheSchritte: Int
    private let ruheVorSchwerkraftSchritte: Int
    private let uebergeben: GemerkterUmfang?
    private let ruhelage: Double

    // Signalaufbereitung
    private var schritt = 0
    private var schwerkraft: Vektor3?
    private var ruhigeSchritte = 0
    private var gleichanteil = Gleichanteil()
    private var geschwindigkeit = 0.0
    private var weg = 0.0
    /// Letzter Messwert, an dem die Geschwindigkeit sicher null war (ruhiger
    /// Messwert in Ruhe, Luecke, Umkehrpunkt bei bekanntem Gleichanteil, gepaartes
    /// Extrem bei grobem Fehler). Ein neu geschaetzter Gleichanteil
    /// wird ab hier nachgetragen; ein kleiner Fehler der Schaetzung wirkt so nur bis
    /// zum letzten verlaesslichen Umkehrpunkt zurueck, nicht ueber den ganzen Satz.
    private var ruhendSchritt = 0
    /// Messwert des letzten Ankers; der Weg davor zaehlt nicht mehr.
    private var ankerSchritt = 0

    // Umkehrpunkte und Einrasten
    private var halbwelle: Halbwelle = .wartet(schritte: 0)
    private var ankerWeg = 0.0
    private var ankerLage: Double
    private var hub: Double
    private var hubGemessen: Bool
    /// Die letzten gemessenen Ausschlaege (m), juengster zuletzt.
    private var ausschlaege: [Double] = []
    private var korrektur = 0.0
    private var letzteAusgabe: Double
    /// Messwert der ersten bestaetigten Schaetzung des Gleichanteils (oder des
    /// letzten grob berichtigten Fehlers) und wie viele Umkehrpunkte mit einem
    /// Extrem danach erkannt sind. Vorher kann der Gleichanteil
    /// Umkehrpunkte vortaeuschen oder verschlucken, und ein Extrem bis zur
    /// Schaetzung liegt auf dem berichtigten, nicht auf dem wahren Weg: Solche
    /// Halbwellen setzen den Hub nicht, die Lage bleibt in 0…1 und ist nicht sicher.
    /// Ab dem zweiten Umkehrpunkt danach traegt sie.
    private var gleichanteilSchritt: Int?
    private var umkehrpunkteSeitGleichanteil = 0
    /// Letztes oberes und unteres Extrem, fuer den Versatz der Geschwindigkeit.
    private var letztesOben: Extrem?
    private var letztesUnten: Extrem?
    private var vertraut: Bool { umkehrpunkteSeitGleichanteil >= 2 }

    /// Auch das Ende einer Bewegung in Ruhe zaehlt als Umkehrpunkt. Waagerecht ist `oben` das ferne Ende.
    public private(set) var umkehrpunkte: [Umkehrpunkt] = []

    public init(rateHz: Double, umfang: GemerkterUmfang? = nil) {
        dt = 1 / rateHz
        stillSchritte = Int((Self.stillDauer * rateHz).rounded())
        ruheSchritte = Int((Self.ruheDauer * rateHz).rounded())
        ruheVorSchwerkraftSchritte = Int((Self.ruheVorSchwerkraft * rateHz).rounded())
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
        let warVertraut = vertraut
        schwerkraftNachfuehren(m)
        aufsummieren(m)
        umkehrErkennen(m)
        if !hubGemessen { hub = max(hub, abs(weg - ankerWeg)) }

        let inRuhe = imRuhezustand
        if inRuhe { ruheHalten() }
        // Ab jetzt gilt die Lage ungehalten: von der zuletzt angezeigten aus einblenden.
        if vertraut && !warVertraut { korrektur = letzteAusgabe - lage(beiWeg: weg) }
        var lage = lage(beiWeg: weg) + korrektur
        if vertraut, !Self.haltbar.contains(lage) {
            // Weit aus dem Umfang: Die Schaetzung hat ihren Halt verloren (ein falscher
            // Gleichanteil, ein verpasster Umkehrpunkt). Zurueck auf unsicher; die Pruefung
            // auf grobe Fehler an den Extremen greift wieder, bis zwei Umkehrpunkte tragen.
            gleichanteilSchritt = schritt
            umkehrpunkteSeitGleichanteil = 0
        }
        if !vertraut { lage = min(max(lage, 0), 1) }
        let blend = max(Self.blendRateStill * dt, Self.blendAnteil * abs(geschwindigkeit) * dt / hub)
        korrektur = korrektur > 0 ? max(0, korrektur - blend) : min(0, korrektur + blend)
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

    /// Ruhig und nachgefuehrt wird gegen die um den Gleichanteil berichtigte
    /// Beschleunigung. Sonst saehe bei Schraeglage der Anfang einer langsamen
    /// Bewegung (Anfangsbeschleunigung und Gleichanteil heben sich auf) wie Ruhe
    /// aus, und die Schwerkraft schluckte die Bewegung.
    private mutating func schwerkraftNachfuehren(_ m: SensorMesswert) {
        guard let g = schwerkraft else { schwerkraft = m.beschleunigung; return }
        let gBetrag = Self.betrag(g)
        let anteil = gleichanteil.wert / Self.erdbeschleunigung / gBetrag
        let ziel = Vektor3(x: m.beschleunigung.x - anteil * g.x, y: m.beschleunigung.y - anteil * g.y,
                           z: m.beschleunigung.z - anteil * g.z)
        let ruhig = abs(Self.betrag(ziel) - gBetrag) < Self.ruheBeschleunigungG
            && Self.betrag(m.drehrate) < Self.ruheDrehrate
        // Nur in Ruhe nachfuehren: in Bewegung waere die Beschleunigung der Last Teil der Schaetzung.
        guard ruhig, case .wartet = halbwelle else { ruhigeSchritte = 0; return }
        ruhigeSchritte += 1
        guard ruhigeSchritte >= ruheVorSchwerkraftSchritte else { return }
        let k = dt / (Self.schwerkraftDauer + dt)
        schwerkraft = Vektor3(x: g.x + k * (ziel.x - g.x), y: g.y + k * (ziel.y - g.y), z: g.z + k * (ziel.z - g.z))
    }

    private mutating func aufsummieren(_ m: SensorMesswert) {
        guard let g = schwerkraft else { return }
        let gBetrag = Self.betrag(g)
        let entlang = (m.beschleunigung.x * g.x + m.beschleunigung.y * g.y + m.beschleunigung.z * g.z) / gBetrag
        let vertikal = (entlang - gBetrag) * Self.erdbeschleunigung
        let vorher = geschwindigkeit
        geschwindigkeit += (vertikal - gleichanteil.wert) * dt
        // Nur ruhige Messwerte lecken: am Beginn einer Bewegung, noch unter der
        // Schwelle, ginge sonst Geschwindigkeit verloren, die den ganzen Satz fehlte.
        if case .wartet = halbwelle, ruhigeSchritte > 0 { geschwindigkeit *= 1 - dt / Self.ruheLeckDauer }
        weg += (vorher + geschwindigkeit) / 2 * dt

        let alterGleichanteil = gleichanteil.wert
        guard let still = gleichanteil.verarbeite(vertikal, schritt: schritt, dt: dt) else { return }
        if gleichanteilSchritt == nil, gleichanteil.bestaetigt { gleichanteilSchritt = schritt }
        if gleichanteil.wert != alterGleichanteil { gleichanteilNachtragen(gleichanteil.wert - alterGleichanteil) }
        if !vertraut { stillsetzen(still) }
    }

    /// Solange die Lage nicht traegt, ist ein gepaartes Extrem der Beschleunigung
    /// ein Messwert mit stehender Last: Liegt die Geschwindigkeit dort grob daneben,
    /// wird sie null gesetzt.
    /// Aufsummiert steht ein Messwert fuer die Mitte des folgenden Schritts; am
    /// stillen Zeitpunkt selbst ist das die halbe Beschleunigung mal Schritt, nicht null.
    /// Das faengt eine Bewegung auf, die wie Ruhe begann (langsam, die
    /// Schraeglage hebt die Anfangsbeschleunigung auf) und deren Geschwindigkeit
    /// deshalb weggeleckt wurde. Spaeter nicht mehr: Am Extrem steht die Last nur
    /// ungefaehr still, das gaebe jede Wiederholung einen kleinen Fehler.
    private mutating func stillsetzen(_ punkt: Gleichanteil.Stillpunkt) {
        let seither = Double(schritt - punkt.schritt) * dt
        let amPunkt = geschwindigkeit - (gleichanteil.u - punkt.u) + gleichanteil.wert * seither
        let fehler = amPunkt - (punkt.beschleunigung - gleichanteil.wert) * dt / 2
        guard abs(fehler) > Self.groberGeschwindigkeitsfehler else { return }
        let alt = lage(beiWeg: weg)
        geschwindigkeit -= fehler
        weg -= fehler * Double(schritt - ankerSchritt) * dt
        if case .laeuft(let vorzeichen, var extrem, let still) = halbwelle {
            extrem.weg -= fehler * Double(max(0, extrem.schritt - ankerSchritt)) * dt
            if vorzeichen * (weg - extrem.weg) > 0 { extrem = Extrem(weg: weg, schritt: schritt, t: extrem.t) }
            halbwelle = .laeuft(vorzeichen: vorzeichen, extrem: extrem, still: still)
        }
        ruhendSchritt = punkt.schritt
        // Der Fehler verfaelschte auch die Extreme bis hier: neu zaehlen.
        gleichanteilSchritt = schritt
        umkehrpunkteSeitGleichanteil = 0
        einblenden(von: alt)
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
                if istUmkehr(oben: vorzeichen > 0, extrem: extrem) { einrasten(oben: vorzeichen > 0, extrem: extrem) }
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

    /// Mit gemessenem Hub ist eine Halbwelle unter `kleinsteHalbwelle` des Hubs,
    /// oder eine, die beim Anker wieder auf dessen Seite endet, nur ein Zittern
    /// der Geschwindigkeit um den Umkehrpunkt (am Geraet haeufig): Sie setzt
    /// weder Hub noch Anker. Sonst nahm ein einziges Zittern den Hub auf wenige
    /// Zentimeter, und die Lage schoss weit aus 0…1.
    private func istUmkehr(oben: Bool, extrem: Extrem) -> Bool {
        guard hubGemessen else { return true }
        return (ankerLage > 0.5) != oben && abs(extrem.weg - ankerWeg) >= Self.kleinsteHalbwelle * hub
    }

    /// Stillstand beendet die Bewegung nur, wenn sie auf die Ruhelage zulief und nahe bei ihr steht.
    private func endetInRuhelage(vorzeichen: Double) -> Bool {
        let aufRuhelageZu = (ruhelage > 0.5) == (vorzeichen > 0)
        return aufRuhelageZu && abs(lage(beiWeg: weg) - ruhelage) <= Self.ruheNaehe
    }

    /// Setzt Nullpunkt und Hub am Umkehrpunkt neu und blendet die Korrektur ein.
    private mutating func einrasten(oben: Bool, extrem: Extrem) {
        let alt = lage(beiWeg: weg)
        var extrem = extrem
        let vorher = oben ? letztesOben : letztesUnten
        if vertraut, let vorher { versatzBerichtigen(von: vorher, bis: &extrem) }
        if oben { letztesOben = extrem } else { letztesUnten = extrem }
        let ausschlag = abs(extrem.weg - ankerWeg)
        // Nur eine Halbwelle, die ganz nach der ersten Schaetzung des Gleichanteils
        // liegt, misst den Hub. Davor nimmt sie ihn hoechstens bis `anfangsHub`
        // zurueck: Ein vom Gleichanteil verkuerzter Weg macht den Hub nicht winzig.
        if umkehrpunkteSeitGleichanteil >= 1, ausschlag >= Self.kleinsterHub {
            // Median der letzten drei: Eine einzelne verzerrte Halbwelle setzt den Hub nicht.
            ausschlaege = Array((ausschlaege + [ausschlag]).suffix(3))
            let s = ausschlaege.sorted()
            hub = s.count == 2 ? (s[0] + s[1]) / 2 : s[s.count / 2]
            hubGemessen = true
        } else if !hubGemessen {
            hub = max(Self.anfangsHub, ausschlag)
        }
        if let gleichanteilSchritt, extrem.schritt > gleichanteilSchritt {
            umkehrpunkteSeitGleichanteil += 1
            // Mit bekanntem Gleichanteil kreuzt die Schaetzung am wahren Umkehrpunkt die Null.
            ruhendSchritt = extrem.schritt
        }
        ankerWeg = extrem.weg
        ankerLage = oben ? 1 : 0
        ankerSchritt = extrem.schritt
        einblenden(von: alt)
        umkehrpunkte.append(Umkehrpunkt(t: extrem.t, oben: oben))
    }

    /// Gleichartige Umkehrpunkte liegen (fast) auf derselben Hoehe: Ueber eine
    /// Wiederholung ist die mittlere Geschwindigkeit null. Was davon abweicht, ist
    /// ein fester Versatz der Geschwindigkeit (ein falsch nachgetragener
    /// Gleichanteil, ein grob gesetzter Stillstand); er wird ab dem Extrem
    /// abgezogen. Sonst laeuft der Weg je Halbwelle um Versatz mal Dauer weg, und
    /// ein Versatz ueber der Spitzengeschwindigkeit verschluckt die Umkehrpunkte.
    private mutating func versatzBerichtigen(von vorher: Extrem, bis extrem: inout Extrem) {
        let dauer = Double(extrem.schritt - vorher.schritt) * dt
        guard dauer >= Self.kleinsteWiederholung, dauer <= Self.groessteWiederholung else { return }
        let versatz = (extrem.weg - vorher.weg) / dauer
        // Seit dem letzten Anker gehoert der Versatz zum Weg; davor zaehlt der Weg nicht mehr.
        let seitAnker = Double(extrem.schritt - ankerSchritt) * dt
        extrem.weg -= versatz * seitAnker
        weg -= versatz * Double(schritt - ankerSchritt) * dt
        geschwindigkeit -= versatz
    }

    // MARK: - Ruhe und Ausgabe

    private var imRuhezustand: Bool {
        guard case let .wartet(schritte) = halbwelle else { return false }
        return schritte >= ruheSchritte
    }

    /// In Ruhe gilt die Ruhelage; der Unterschied wird eingeblendet. Nur ein ruhiger
    /// Messwert ist sicher Stillstand: In den ersten Messwerten einer Bewegung gilt
    /// nach der Geschwindigkeit noch Ruhe, als Nullpunkt der Geschwindigkeit
    /// verschoebe das einen Gleichanteil um diese Messwerte.
    private mutating func ruheHalten() {
        guard ruhigeSchritte > 0 else { return }
        let alt = lage(beiWeg: weg)
        ankerWeg = weg
        ankerLage = ruhelage
        einblenden(von: alt)
        ruhendSchritt = schritt
        ankerSchritt = schritt
        gleichanteil.zuruecksetzen()
    }

    /// Haelt die angezeigte Lage stetig, wenn sich die Abbildung von Weg auf Lage aendert.
    private mutating func einblenden(von alt: Double) {
        korrektur += alt - lage(beiWeg: weg)
        // Solange in 0…1 gehalten wird, von der angezeigten Lage aus einblenden.
        if !vertraut { korrektur = letzteAusgabe - lage(beiWeg: weg) }
    }

    private func lage(beiWeg weg: Double) -> Double {
        ankerLage + (weg - ankerWeg) / hub
    }

    private var richtung: Wegrichtung {
        guard case let .laeuft(vorzeichen, _, _) = halbwelle else { return .unbekannt }
        return vorzeichen > 0 ? .hin : .rueck
    }
}
