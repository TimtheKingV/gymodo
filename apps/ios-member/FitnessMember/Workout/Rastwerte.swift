import Foundation

/// Die Wertelisten der Raeder: Belastung, Nebenbelastung und Umfang.
///
/// designsystem.md SS7: "Die Rastung kommt aus dem Geraet, nicht aus dem
/// Entwurf." Dieselbe Daumenstrecke deckt an einer Beinpresse mit
/// 2,5-kg-Platten eine andere Spanne ab als an einem Beinbeuger mit
/// 5-kg-Platten -- und an einem Laufband mit 0,5-km/h-Stufen wieder eine
/// andere. Weil die Liste aus dem Modell entsteht, ist ein Wert, den das
/// Geraet gar nicht kann, strukturell unmoeglich.
enum Rastwerte {
    /// Obergrenze fuer Geraete ohne load_max. Der Server rechnet dort
    /// mit 9999 -- als Radlaenge waere das absurd, und ein Anschlag, den
    /// niemand dokumentiert hat, braucht auch kein Anschlagsfeedback.
    static let maxRastenOhneObergrenze = 200

    /// Die Liste des Umfangsrads je Umfangsart (Cardio-Spec Abschnitt 8.1).
    ///
    /// Die Datenbank liesse jeweils weit mehr zu; ein Rad ist kein
    /// Formularfeld. 1-40 deckt jedes reale Wiederholungsschema ab, 90
    /// Minuten in halben Minuten jede Einheit an einem Ausdauergeraet, 20 km
    /// in 100-m-Schritten jede Strecke am Rudergeraet. Sekunden- und
    /// Meterliste haben 180 und 200 Eintraege -- dieselbe Groessenordnung
    /// wie ein Belastungsrad ohne Anschlag (maxRastenOhneObergrenze).
    static func umfang(_ art: VolumeKind) -> [Int] {
        switch art {
        case .reps: Array(1...40)
        case .seconds: Array(stride(from: 30, through: 5400, by: 30))
        case .meters: Array(stride(from: 100, through: 20_000, by: 100))
        }
    }

    /// Rechnet nur mit Zahlen und dient deshalb der Belastung wie der
    /// Nebenbelastung, gleich in welcher Einheit.
    static func belastung(min: Double, max: Double?, schritt: Double) -> [Double] {
        guard schritt > 0 else { return [min] }
        let obergrenze = max ?? (min + Double(maxRastenOhneObergrenze) * schritt)
        guard obergrenze > min else { return [min] }

        // Epsilon vor dem Abrunden: (0,3 - 0) / 0,1 wird in Gleitkomma zu
        // 2.9999999999999996 statt 3 -- ohne Toleranz wuerde das Rad einen
        // Wert verschlucken, den das Geraet tatsaechlich kann.
        let rasten = Int(((obergrenze - min) / schritt + 1e-9).rounded(.down))
        return (0...rasten).map { min + Double($0) * schritt }
    }

    /// Das Rad fuers Koerpergewicht (GewichtEintragenSheet) rastet nach
    /// derselben Rechnung. Der Name bleibt dort "Gewicht": ein
    /// Koerpergewicht ist keine Trainingsbelastung.
    static func gewichte(min: Double, max: Double?, schritt: Double) -> [Double] {
        belastung(min: min, max: max, schritt: schritt)
    }

    /// Dasselbe fuer das Umfangsrad: ein letzter Satz von 1195 Sekunden
    /// rastet auf 20:00, eine Wiederholungszahl ueber 40 auf 40. RastRad
    /// verlangt, dass die Auswahl ein Element der Werteliste ist.
    static func naechster(zu wert: Int, in werte: [Int]) -> Int {
        guard let erster = werte.first else { return wert }
        return werte.min { abs($0 - wert) < abs($1 - wert) } ?? erster
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

    /// Wortlaut, den Belastungsrad (GeraetModel.anschlagText) und die
    /// Kalibrierung (Stepper44.grenzhinweis) teilen -- dieselbe Grenze
    /// verdient denselben Satz, gleich welches Steuerelement sie meldet.
    static let maximumErreicht = "Maximum des Geräts erreicht"
}
