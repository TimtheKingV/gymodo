import Foundation

/// Die Werte eines Cardio-Satzes (Testnotiz 14.10., 18:45 #7). Reihenfolge
/// und Schluessel wie CARDIO_WERTE in packages/domain/src/cardio.ts.
enum CardioWert: String, CaseIterable, Codable, Hashable, Sendable {
    case zeit, strecke, stufe, kmh, steigung, watt, frequenz, kcal

    var name: String {
        switch self {
        case .zeit: "Zeit"
        case .strecke: "Strecke"
        case .stufe: "Stufe"
        case .kmh: "Tempo"
        case .steigung: "Steigung"
        case .watt: "Watt"
        case .frequenz: "Frequenz"
        case .kcal: "Kalorien"
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
