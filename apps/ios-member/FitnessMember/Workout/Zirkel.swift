import Foundation

// Mini-Zirkel: reiner Wertetyp ohne UI und ohne Store (Spec 21.10.).
//
// Der Zirkel kennt nur einen Zaehler: `schritt` = Anzahl erledigter Slots
// (Satz gemacht oder uebersprungen). Runde, Position und Pausenart leiten
// sich daraus ab, so gibt es keinen zweiten Stand, der auseinanderlaufen kann.

struct ZirkelUebung: Hashable, Sendable {
    let station: String
    let exerciseId: String
    /// Der Uebungsstart-Token der Uebung, falls eine Einheit schon laeuft.
    let token: String?
}

struct Zirkel: Equatable, Sendable {
    static let rundenBereich = 2...6
    static let mindestUebungen = 2

    private(set) var uebungen: [ZirkelUebung]
    var runden: Int
    /// Pause zwischen zwei Uebungen derselben Runde, in Sekunden.
    var uebungspause: Int
    /// Pause beim Wechsel in die naechste Runde, in Sekunden.
    var rundenpause: Int
    /// Anzahl erledigter Slots, uebersprungene eingeschlossen.
    private(set) var schritt: Int

    init(uebungen: [ZirkelUebung], runden: Int = 3, uebungspause: Int, rundenpause: Int, schritt: Int = 0) {
        // Teilen und Modulo laufen ueber uebungen.count: ohne zwei Uebungen
        // ist es kein Zirkel. Einzige Tuer fuer den Start mit einer Uebung
        // ist ausEinzelsatz, das gleich zwei erzeugt.
        precondition(uebungen.count >= Self.mindestUebungen, "Zirkel braucht mindestens \(Self.mindestUebungen) Uebungen")
        self.uebungen = uebungen
        self.runden = min(max(runden, Self.rundenBereich.lowerBound), Self.rundenBereich.upperBound)
        self.uebungspause = uebungspause
        self.rundenpause = rundenpause
        self.schritt = max(schritt, 0)
    }

    /// 1-basiert. Nach dem letzten Slot zaehlt sie ueber `runden` hinaus;
    /// wer sie anzeigt, prueft vorher `istFertig`.
    var runde: Int { schritt / uebungen.count + 1 }
    var position: Int { schritt % uebungen.count }

    var istFertig: Bool { schritt >= runden * uebungen.count }

    /// Die zuletzt erledigte Uebung; vor dem ersten Slot nil.
    var aktuelle: ZirkelUebung? {
        schritt > 0 ? uebungen[(schritt - 1) % uebungen.count] : nil
    }

    /// Die Uebung des naechsten Slots; nil, wenn der Zirkel fertig ist.
    var naechste: ZirkelUebung? { istFertig ? nil : uebungen[position] }

    var naechsterSchrittIstRundenwechsel: Bool {
        schritt > 0 && schritt % uebungen.count == 0 && !istFertig
    }

    var pausenSekunden: Int { naechsterSchrittIstRundenwechsel ? rundenpause : uebungspause }

    /// Erweitern ist nur offen, solange Runde 1 gerade komplett ist: danach
    /// haetten die Runden unterschiedlich viele Uebungen.
    var kannErweitern: Bool { schritt == uebungen.count }

    mutating func weiter() {
        guard !istFertig else { return }
        schritt += 1
    }

    /// Wie `weiter()`; der eigene Name macht die Aufrufer lesbar.
    mutating func ueberspringen() { weiter() }

    @discardableResult
    mutating func erweitern(um uebung: ZirkelUebung) -> Bool {
        guard kannErweitern else { return false }
        uebungen.append(uebung)
        return true
    }

    /// Aus einem Einzelsatz wird ein Zirkel: der erste Satz zaehlt schon als
    /// Slot 1 der ersten Runde.
    static func ausEinzelsatz(_ erste: ZirkelUebung, zweite: ZirkelUebung, runden: Int, uebungspause: Int, rundenpause: Int) -> Zirkel {
        Zirkel(uebungen: [erste, zweite], runden: runden, uebungspause: uebungspause, rundenpause: rundenpause, schritt: 1)
    }
}
