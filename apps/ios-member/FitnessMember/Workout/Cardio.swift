import Foundation

/// Die Werte eines Cardio-Satzes (Testnotiz 14.10., 18:45 #7). Reihenfolge
/// und Schluessel wie CARDIO_WERTE in packages/domain/src/cardio.ts.
enum CardioWert: String, CaseIterable, Codable, Hashable, Sendable {
    case zeit, strecke, stufe, stufenanzahl, kmh, steigung, watt, frequenz, kcal

    var name: String {
        switch self {
        case .zeit: "Zeit"
        case .strecke: "Strecke"
        case .stufe: "Stufe"
        // Treppenstufen, nicht das Widerstandslevel (Testnotiz 18.10., #5).
        case .stufenanzahl: "Anzahl Stufen"
        case .kmh: "Tempo"
        case .steigung: "Steigung"
        case .watt: "Watt"
        case .frequenz: "Frequenz"
        case .kcal: "Kalorien"
        }
    }

    /// Die Einheit, die ueber bzw. neben der Zahl steht (Testnotiz 15.10.,
    /// #4). Zeit und Strecke haben je Feld eine eigene (siehe `ZeitFeld`,
    /// `StreckeFeld`); hier steht, was ein einzelnes Feld traegt.
    var einheit: String {
        switch self {
        case .zeit: "min"
        case .strecke: "m"
        case .stufe: "Stufe"
        case .stufenanzahl: "Stufen"
        case .kmh: "km/h"
        case .steigung: "%"
        case .watt: "W"
        case .frequenz: "/min"
        case .kcal: "kcal"
        }
    }

    /// Ganzzahlig in der Datenbank -- alle ausser km/h und Steigung.
    var ganzzahlig: Bool { self != .kmh && self != .steigung }

    /// Grenzen wie die Checks aus Migration 0054.
    var bereich: ClosedRange<Double> {
        switch self {
        case .zeit: 1...86_400
        case .strecke: 1...200_000
        case .stufe: 0...100
        case .stufenanzahl: 1...10_000
        case .kmh: 0...50
        case .steigung: -10...40
        case .watt: 0...3_000
        case .frequenz: 0...300
        case .kcal: 0...10_000
        }
    }
}

/// Was an einem Cardio-Satz gesetzt ist. Jeder Wert optional; ein Satz
/// braucht mindestens einen.
struct CardioWerte: Codable, Hashable, Sendable {
    var zeit: Int? = nil
    var strecke: Int? = nil
    var stufe: Int? = nil
    var stufenanzahl: Int? = nil
    var kmh: Double? = nil
    var steigung: Double? = nil
    var watt: Int? = nil
    var frequenz: Int? = nil
    var kcal: Int? = nil

    var istLeer: Bool { CardioWert.allCases.allSatisfy { self[$0] == nil } }

    subscript(_ wert: CardioWert) -> Double? {
        get {
            switch wert {
            case .zeit: zeit.map(Double.init)
            case .strecke: strecke.map(Double.init)
            case .stufe: stufe.map(Double.init)
            case .stufenanzahl: stufenanzahl.map(Double.init)
            case .kmh: kmh
            case .steigung: steigung
            case .watt: watt.map(Double.init)
            case .frequenz: frequenz.map(Double.init)
            case .kcal: kcal.map(Double.init)
            }
        }
        set {
            let ganz = newValue.map { Int($0.rounded()) }
            switch wert {
            case .zeit: zeit = ganz
            case .strecke: strecke = ganz
            case .stufe: stufe = ganz
            case .stufenanzahl: stufenanzahl = ganz
            case .kmh: kmh = newValue
            case .steigung: steigung = newValue
            case .watt: watt = ganz
            case .frequenz: frequenz = ganz
            case .kcal: kcal = ganz
            }
        }
    }

    /// Nur, was das Geraet anbietet -- eine Vorbelegung von einem Geraet
    /// mit anderer Liste darf keinen Wert mitbringen, den der Server ablehnt.
    func nur(_ liste: [CardioWert]) -> CardioWerte {
        var ergebnis = CardioWerte()
        for wert in liste { ergebnis[wert] = self[wert] }
        return ergebnis
    }
}

/// Eingabe und Pruefung eines Cardio-Werts (Testnotiz 14.10., 18:45 #7).
enum CardioEingabe {
    enum Fehler: Error, Equatable {
        case leer
        case keineZahl
        /// Fertiger Text: "Höchstens 50 km/h."
        case ausserhalb(String)
    }

    /// Komma oder Punkt als Dezimaltrenner; ganzzahlige Werte duerfen keinen Rest haben.
    static func zahl(_ text: String, fuer wert: CardioWert) -> Result<Double, Fehler> {
        var roh = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{2212}", with: "-")
            .replacingOccurrences(of: "\u{2013}", with: "-")
        if roh.isEmpty { return .failure(.leer) }
        // Nur Ziffern, ein Vorzeichen vorn, Punkt und Komma: "1e3", "0x10" fallen raus.
        guard roh.range(of: #"^[+-]?[0-9.,]+$"#, options: .regularExpression) != nil else {
            return .failure(.keineZahl)
        }
        // Ganze Zahl mit Tausenderpunkten: "1.000" ist 1000, nicht 1.
        if wert.ganzzahlig, roh.range(of: #"^[0-9]{1,3}(\.[0-9]{3})+$"#, options: .regularExpression) != nil {
            roh = roh.replacingOccurrences(of: ".", with: "")
        }
        guard let zahl = Double(roh.replacingOccurrences(of: ",", with: ".")), zahl.isFinite else {
            return .failure(.keineZahl)
        }
        if wert.ganzzahlig, zahl.rounded() != zahl { return .failure(.keineZahl) }
        return pruefen(zahl, wert)
    }

    /// Minuten und Sekunden 0-59; die Summe muss in den Zeitbereich passen.
    static func zeit(stunden: Int, minuten: Int, sekunden: Int) -> Result<Double, Fehler> {
        guard stunden >= 0, (0...59).contains(minuten), (0...59).contains(sekunden) else {
            return .failure(.keineZahl)
        }
        // Mehr als 24 Stunden liegen ohnehin ausserhalb; ohne diese Schranke
        // liefe `stunden * 3600` bei riesigen Eingaben ueber und brach ab
        // (Final-Review E).
        if stunden > 24 { return pruefen(CardioWert.zeit.bereich.upperBound + 1, .zeit) }
        return pruefen(Double(stunden * 3600 + minuten * 60 + sekunden), .zeit)
    }

    /// Die Felder der Zeiteingabe, in Tipp-Reihenfolge (Testnotiz 15.10., #2).
    enum ZeitFeld: CaseIterable { case stunden, minuten, sekunden
        var einheit: String {
            switch self { case .stunden: "Stunden"; case .minuten: "Minuten"; case .sekunden: "Sekunden" }
        }
        var folgender: ZeitFeld? {
            switch self { case .stunden: .minuten; case .minuten: .sekunden; case .sekunden: nil }
        }
    }

    /// Springt der Cursor nach diesem Text ins naechste Feld? Stunden nach
    /// einer Ziffer (0 bis 9 Stunden reichen am Geraet), Minuten nach zwei,
    /// Sekunden sind das letzte Feld (Testnotiz 15.10., #2).
    static func springt(von feld: ZeitFeld, text: String) -> Bool {
        guard feld.folgender != nil else { return false }
        let ziffern = text.filter(\.isNumber).count
        return ziffern >= (feld == .stunden ? 1 : 2)
    }

    /// Die zwei Felder der Streckeneingabe (Testnotiz 15.10., #3).
    enum StreckeFeld: CaseIterable { case kilometer, meter
        var einheit: String { self == .kilometer ? "km" : "m" }
    }

    /// Kilometer und Meter, Meter 0-999; die Summe muss in den Bereich passen.
    static func strecke(kilometer: Int, meter: Int) -> Result<Double, Fehler> {
        guard kilometer >= 0, (0...999).contains(meter) else { return .failure(.keineZahl) }
        // Wie bei der Zeit: ohne Schranke liefe die Multiplikation bei riesigen Eingaben ueber.
        if kilometer > 200 { return pruefen(CardioWert.strecke.bereich.upperBound + 1, .strecke) }
        return pruefen(Double(kilometer * 1000 + meter), .strecke)
    }

    static func streckeTeile(_ meter: Int) -> (km: Int, m: Int) { (meter / 1000, meter % 1000) }

    static func zeitTeile(_ sekunden: Int) -> (h: Int, m: Int, s: Int) {
        (sekunden / 3600, (sekunden % 3600) / 60, sekunden % 60)
    }

    private static func pruefen(_ zahl: Double, _ wert: CardioWert) -> Result<Double, Fehler> {
        let bereich = wert.bereich
        if zahl > bereich.upperBound {
            return .failure(.ausserhalb("Höchstens \(Zahlformat.cardioGrenze(wert, bereich.upperBound))."))
        }
        if zahl < bereich.lowerBound {
            if wert == .zeit { return .failure(.ausserhalb("Mindestens 1 Sekunde.")) }
            return .failure(.ausserhalb("Mindestens \(Zahlformat.cardioGrenze(wert, bereich.lowerBound))."))
        }
        return .success(zahl)
    }
}
