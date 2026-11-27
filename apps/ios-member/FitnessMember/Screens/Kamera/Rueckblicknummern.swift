/// Die Satznummern im Rueckblick. `anzeigeSatz` steht nach dem Sichern schon auf dem naechsten Satz, nach einem
/// abgelehnten Sichern noch auf diesem; der naechste Ablauf zeigt in beiden Faellen `anzeigeSatz`.
struct Rueckblicknummern: Equatable {
    /// Der Satz, auf den sich der Rueckblick bezieht.
    let kopf: Int
    /// Der Satz, den der Knopf startet.
    let knopf: Int
    let satzZiel: Int

    init(anzeigeSatz: Int, gesichert: Bool, satzZiel: Int) {
        kopf = gesichert ? max(1, anzeigeSatz - 1) : anzeigeSatz
        knopf = anzeigeSatz
        self.satzZiel = satzZiel
    }

    /// "SATZ 2 VON 3"; ein Zusatzsatz ueber dem Ziel ohne "VON".
    var kopfText: String { Satzkopf.text(satz: kopf, ziel: satzZiel) }
}

/// "SATZ 2 VON 3" fuer die Kopfzeilen; ein Zusatzsatz ueber dem Ziel ohne "VON".
enum Satzkopf {
    static func text(satz: Int, ziel: Int) -> String { satz > ziel ? "SATZ \(satz)" : "SATZ \(satz) VON \(ziel)" }
}
