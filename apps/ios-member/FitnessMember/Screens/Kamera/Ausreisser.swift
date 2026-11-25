import Koerperbild

/// Der Satz zu den Ausreissern im Rueckblick: nennt die Wiederholungen der ersten nicht leeren Liste
/// (Rueckweg vor Hinweg, zu schnell vor zu langsam) und uebersetzt Hin/Rueck in senken/heben.
enum Ausreisser {
    static func satz(rueckblick: Koerperbild.Rueckblick, tempo: Uebungstempo) -> String? {
        let kraftweg = tempo.phase(.kraftweg)
        let ablassen = tempo.phase(.ablassen)
        let reihenfolge: [(nummern: [Int], phase: Tempophase, zuSchnell: Bool)] = [
            (rueckblick.zuSchnellRueck, ablassen, true), (rueckblick.zuSchnellHin, kraftweg, true),
            (rueckblick.zuLangsamRueck, ablassen, false), (rueckblick.zuLangsamHin, kraftweg, false),
        ]
        guard let treffer = reihenfolge.first(where: { !$0.nummern.isEmpty }) else {
            // Alles bewertet und im Takt; sonst gibt es nichts zu sagen.
            let alleImTakt = !rueckblick.urteile.isEmpty && rueckblick.bewertet == rueckblick.urteile.count
                && rueckblick.imTakt == rueckblick.bewertet
            return alleImTakt ? "Alle Wiederholungen im Takt." : nil
        }
        let wort = treffer.phase == .senken ? "Senken" : "Heben"
        let sekunden = zahl(treffer.phase == .senken ? tempo.senken : tempo.heben)
        let vorn = "Bei Wdh. \(aufzaehlung(treffer.nummern)) warst du beim \(wort)"
        return treffer.zuSchnell
            ? "\(vorn) zu schnell. Lass dir die vollen \(sekunden) Sekunden."
            : "\(vorn) zu langsam. Zügiger, etwa \(sekunden) Sekunden."
    }

    /// "4", "4 und 7", "2, 4 und 7".
    private static func aufzaehlung(_ n: [Int]) -> String {
        guard let letzte = n.last else { return "" }
        if n.count == 1 { return "\(letzte)" }
        return n.dropLast().map(String.init).joined(separator: ", ") + " und \(letzte)"
    }

    /// Ganze Zahlen ohne Komma, sonst Dezimalkomma.
    private static func zahl(_ wert: Double) -> String {
        if let ganz = Int(exactly: wert) { return String(ganz) }
        return String(wert).replacingOccurrences(of: ".", with: ",")
    }
}
