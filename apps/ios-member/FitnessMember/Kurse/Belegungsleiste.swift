import Foundation

/// Die Belegung als ein Segment je Platz statt als Fuellstand.
///
/// Der Unterschied ist nicht kosmetisch: ein Fuellbalken behauptet ein
/// Verhaeltnis ("drei Viertel voll"), abzaehlbare Segmente behaupten
/// Plaetze ("noch vier frei"). Das zweite ist das, was das Mitglied
/// wissen will, und es ist die Aussage, die die Zahl daneben ohnehin
/// schon macht -- die Leiste macht sie nur ohne Lesen erfassbar.
///
/// Die Zahl bleibt deshalb stehen, an jeder Stelle. Sie ist exakt, sie
/// ist das, was VoiceOver vorliest, und sie traegt weiter, wo diese
/// Ableitung die Leiste abschaltet.
///
/// Reine Werte, keine Views -- `KurseWochenView` und `KursDetailView`
/// zeichnen daraus, und `BelegungsleisteTests` prueft die Regeln ohne UI.
enum Belegungsleiste {
    /// Ab hier traegt die Leiste nichts mehr: bei mehr als 40 Segmenten
    /// auf 132 pt bleibt je Segment weniger als ein Haar uebrig, und
    /// vierzig Striche zaehlt ohnehin niemand mehr ab. Dann bleibt die
    /// Zahl allein -- sie war vorher schon die genauere Aussage.
    static let hoechsteAnzeigbareKapazitaet = 40

    /// `false` heisst: nur die Zahl zeigen. Auch bei `kapazitaet <= 0` --
    /// das ist ein Datenfehler, und eine Leiste aus null Segmenten waere
    /// ein durchgehender Strich in Linienfarbe, den niemand als "keine
    /// Plaetze" liest.
    static func zeigtLeiste(kapazitaet: Int) -> Bool {
        kapazitaet > 0 && kapazitaet <= hoechsteAnzeigbareKapazitaet
    }

    /// Der Spalt zwischen zwei Segmenten. Faellt bei grossen Kursen von
    /// 2 auf 1 pt: bei fester Gesamtbreite waere der Spalt sonst irgendwann
    /// breiter als das Segment daneben, und die Leiste laese sich als
    /// gestrichelte Linie statt als Reihe von Plaetzen.
    static func segmentAbstand(kapazitaet: Int) -> CGFloat {
        kapazitaet <= 24 ? 2 : 1
    }

    /// Wie viele Segmente eingefaerbt werden.
    ///
    /// Beidseitig geklemmt, weil `bookedCount` und `capacity` vom Server
    /// unabhaengig voneinander gezaehlt werden: rueckt jemand nach,
    /// waehrend das Studio die Kursgroesse verkleinert, steht dort
    /// kurzzeitig "19 von 16". Die Zahl daneben sagt dann die Wahrheit,
    /// die Leiste faerbt hoechstens, was sie an Segmenten hat.
    static func belegteSegmente(belegt: Int, kapazitaet: Int) -> Int {
        min(max(belegt, 0), max(kapazitaet, 0))
    }
}
