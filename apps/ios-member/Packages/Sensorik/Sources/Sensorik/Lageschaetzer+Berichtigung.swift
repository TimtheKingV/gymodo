import Foundation

/// Berichtigungen der aufsummierten Geschwindigkeit und des Wegs: grobe Fehler
/// an Stillpunkten, nachgetragener Gleichanteil, Versatz zwischen gleichartigen
/// Umkehrpunkten. Ausgelagert, damit `Lageschaetzer.swift` lesbar bleibt; die
/// Zustaende, die sie aendern, sind deshalb modulweit statt privat.
extension Lageschaetzer {
    /// Solange die Lage nicht traegt, ist ein gepaartes Extrem der Beschleunigung
    /// ein Messwert mit stehender Last: Liegt die Geschwindigkeit dort grob daneben,
    /// wird sie null gesetzt.
    /// Aufsummiert steht ein Messwert fuer die Mitte des folgenden Schritts; am
    /// stillen Zeitpunkt selbst ist das die halbe Beschleunigung mal Schritt, nicht null.
    /// Das faengt eine Bewegung auf, die wie Ruhe begann (langsam, die
    /// Schraeglage hebt die Anfangsbeschleunigung auf) und deren Geschwindigkeit
    /// deshalb weggeleckt wurde. Spaeter nicht mehr: Am Extrem steht die Last nur
    /// ungefaehr still, das gaebe jede Wiederholung einen kleinen Fehler.
    mutating func stillsetzen(_ punkt: Gleichanteil.Stillpunkt) {
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
    mutating func gleichanteilNachtragen(_ d: Double) {
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

    /// Gleichartige Umkehrpunkte liegen (fast) auf derselben Hoehe: Ueber eine
    /// Wiederholung ist die mittlere Geschwindigkeit null. Was davon abweicht, ist
    /// ein fester Versatz der Geschwindigkeit (ein falsch nachgetragener
    /// Gleichanteil, ein grob gesetzter Stillstand); er wird ab dem Extrem
    /// abgezogen. Sonst laeuft der Weg je Halbwelle um Versatz mal Dauer weg, und
    /// ein Versatz ueber der Spitzengeschwindigkeit verschluckt die Umkehrpunkte.
    mutating func versatzBerichtigen(von vorher: Extrem, bis extrem: inout Extrem) {
        let dauer = Double(extrem.schritt - vorher.schritt) * dt
        guard dauer >= Self.kleinsteWiederholung, dauer <= Self.groessteWiederholung else { return }
        let versatz = (extrem.weg - vorher.weg) / dauer
        // Seit dem letzten Anker gehoert der Versatz zum Weg; davor zaehlt der Weg nicht mehr.
        let seitAnker = Double(extrem.schritt - ankerSchritt) * dt
        extrem.weg -= versatz * seitAnker
        weg -= versatz * Double(schritt - ankerSchritt) * dt
        geschwindigkeit -= versatz
    }
}
