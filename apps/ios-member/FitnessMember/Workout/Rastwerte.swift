import Foundation

/// Die Wertelisten der beiden Raeder.
///
/// designsystem.md SS7: "Die Rastung kommt aus dem Geraet, nicht aus dem
/// Entwurf." Dieselbe Daumenstrecke deckt an einer Beinpresse mit
/// 2,5-kg-Platten eine andere Spanne ab als an einem Beinbeuger mit
/// 5-kg-Platten. Weil die Liste aus dem Modell entsteht, ist ein Wert, den
/// das Geraet gar nicht kann, strukturell unmoeglich.
enum Rastwerte {
    /// Obergrenze fuer Geraete ohne max_weight_kg. Der Server rechnet dort
    /// mit 9999 -- als Radlaenge waere das absurd, und ein Anschlag, den
    /// niemand dokumentiert hat, braucht auch kein Anschlagsfeedback.
    static let maxRastenOhneObergrenze = 200

    /// Wiederholungen rasten immer auf 1. Die Datenbank liesse 1000 zu; ein
    /// Rad ist kein Formularfeld, und 1-40 deckt jedes reale Kraft- und
    /// Ausdauerschema ab.
    static let wiederholungen: [Int] = Array(1...40)

    static func gewichte(min: Double, max: Double?, schritt: Double) -> [Double] {
        guard schritt > 0 else { return [min] }
        let obergrenze = max ?? (min + Double(maxRastenOhneObergrenze) * schritt)
        guard obergrenze > min else { return [min] }

        // Epsilon vor dem Abrunden: (0,3 - 0) / 0,1 wird in Gleitkomma zu
        // 2.9999999999999996 statt 3 -- ohne Toleranz wuerde das Rad einen
        // Wert verschlucken, den das Geraet tatsaechlich kann.
        let rasten = Int(((obergrenze - min) / schritt + 1e-9).rounded(.down))
        return (0...rasten).map { min + Double($0) * schritt }
    }

    /// Rastet einen beliebigen Wert -- etwa einen Serververschlag -- auf die
    /// Liste. Ohne das koennte ein Vorschlag neben der Rasterung liegen und
    /// das Rad haette keinen Startpunkt.
    static func naechster(zu wert: Double, in werte: [Double]) -> Double {
        guard let erster = werte.first else { return wert }
        return werte.min { abs($0 - wert) < abs($1 - wert) } ?? erster
    }

    /// EIN Ort fuer "die Auswahl klebt am Rand der Rastenliste" -- vorher
    /// eigenstaendig sowohl in RastRad als auch in WertZeile nachgebaut
    /// (Review-Fund Schlusswelle: zwei Kopien sind die Invariante, die als
    /// naechstes auseinanderlaeuft).
    static func amAnschlag(_ wert: Double, in werte: [Double]) -> Bool {
        wert == werte.first || wert == werte.last
    }

    /// Wortlaut, den Gewichtsrad (GeraetModel.anschlagText) und die
    /// Kalibrierung (Stepper44.grenzhinweis) teilen -- dieselbe Grenze
    /// verdient denselben Satz, gleich welches Steuerelement sie meldet.
    static let maximumErreicht = "Maximum des Geräts erreicht"
}
