import Foundation
import Sensorik

/// Zaehlt Wiederholungen in einer festen Arbeitsphase eines Flows als reine Zustandsmaschine.
/// Hier bestimmt die Flow-Uhr: Die Zaehlung beginnt mit `start`, die Soll-Welle ist eine reine Zeitvorgabe ab `start`,
/// und der Verlust der Person haelt nichts an, er setzt nur `erkannt` auf false und stoppt die Zaehlung,
/// bis die Person wieder sicher im Bild ist. Die Zeit kommt nur ueber `bild`, `start`, `anhalten`, `fortsetzen`.
public struct FlowZaehler: Sendable {
    /// So lange darf die Erkennung nach `start` ausbleiben, bevor `erkannt` false wird.
    public static let nichtErkanntNach: TimeInterval = 3
    static let spurDauer: TimeInterval = 6

    public let welle: Sollwelle
    public let tempo: Uebungstempo
    public let vorgabe: Kameravorgabe
    public private(set) var spur: [KameraSatzAblauf.Spurpunkt] = []

    private var pruefung: Erkennungspruefung
    private var koerperlage: Koerperlage
    /// Flow-Zeit: Uhrzeit abzueglich der angehaltenen Zeit.
    private var startZeit: TimeInterval?
    private var letzteZeit: TimeInterval?
    private var pausenSumme: TimeInterval = 0
    private var angehaltenSeit: TimeInterval?
    /// Seit `start` einmal sicher erkannt (Aufstellen bestanden).
    private var hatErkannt = false
    /// Laenger als `Erkennungspruefung.verlorenNach` ohne Pflichtgelenke, bis die Person wieder bestanden hat.
    private var verlust = false
    /// Die Startposition muss neu gesetzt werden (vor der ersten Erkennung, nach Verlust, nach dem Anhalten).
    private var losNoetig = true
    private var seiteFestgehalten = false

    public init(vorgabe: Kameravorgabe, tempo: Uebungstempo) {
        self.vorgabe = vorgabe
        self.tempo = tempo
        self.welle = Sollwelle(vorgabe: tempo.vorgabe)
        self.pruefung = Erkennungspruefung(vorgabe: vorgabe)
        self.koerperlage = Koerperlage(vorgabe: vorgabe, gemerkterHub: nil)
    }

    // MARK: Abfragen

    /// Nimmt nie ab: `Koerperlage` behaelt gezaehlte Wiederholungen ueber `unterbrechen()` und `los(t:)`.
    public var wiederholungen: Int { koerperlage.wiederholungen.count }

    /// false: Hinweis "Kamera sieht dich gerade nicht". Vor `start` und bis 3 s nach `start` gilt die Person als erkannt.
    public var erkannt: Bool {
        guard let start = startZeit, let jetzt = letzteZeit else { return true }
        if verlust { return false }
        if !hatErkannt { return jetzt - start <= Self.nichtErkanntNach }
        return true
    }

    /// Sekunden seit `start` auf der Flow-Uhr (ohne angehaltene Zeit); vor `start` 0.
    public var sollzeit: TimeInterval {
        guard let start = startZeit else { return 0 }
        return max(0, (letzteZeit ?? start) - start)
    }

    // MARK: Eingaben

    /// Beginn der Arbeitsphase; vorherige Bilder duerfen schon ueber `bild` gekommen sein.
    public mutating func start(t: TimeInterval) {
        guard startZeit == nil else { return }
        let jetzt = t - pausenSumme
        startZeit = jetzt
        letzteZeit = max(letzteZeit ?? jetzt, jetzt)
        if pruefung.bestanden { erkennungSteht(jetzt) }
    }

    public mutating func bild(t: TimeInterval, skelett: Skelett?) {
        guard angehaltenSeit == nil else { return }
        let jetzt = t - pausenSumme
        letzteZeit = jetzt
        pruefung.eingabe(t: jetzt, skelett: skelett)
        let lage = koerperlage.verarbeite(t: jetzt, skelett: skelett)
        guard let start = startZeit else { return }
        if hatErkannt, !verlust, pruefung.verloren {
            verlust = true
            losNoetig = true
        }
        if losNoetig, pruefung.bestanden { erkennungSteht(jetzt) }
        guard !losNoetig else {
            // Ohne Zaehlung faellt eine angefangene Wiederholung in jedem Bild weg.
            koerperlage.unterbrechen()
            return
        }
        let s = jetzt - start
        spur.append(KameraSatzAblauf.Spurpunkt(sollzeit: s, lage: lage.lage, sicher: lage.sicher))
        spur.removeAll { $0.sollzeit < s - Self.spurDauer }
        if !seiteFestgehalten, let seite = koerperlage.fuehrendeSeite {
            pruefung.seiteFesthalten(seite)
            seiteFestgehalten = true
        }
    }

    /// Anhalten und Fortsetzen der Flow-Uhr; angehaltene Zeit zaehlt nicht in Welle und Zaehlung.
    public mutating func anhalten(t: TimeInterval) {
        guard angehaltenSeit == nil else { return }
        angehaltenSeit = t
        koerperlage.unterbrechen()
        losNoetig = true
    }

    public mutating func fortsetzen(t: TimeInterval) {
        guard let seit = angehaltenSeit else { return }
        pausenSumme += max(0, t - seit)
        angehaltenSeit = nil
        // Die Zwischenzeit hat kein Bild geliefert: die Erkennung beginnt von vorn, ohne dass das ein Verlust waere.
        pruefung.zuruecksetzen()
        verlust = false
        losNoetig = true
    }

    private mutating func erkennungSteht(_ jetzt: TimeInterval) {
        koerperlage.los(t: jetzt)
        hatErkannt = true
        verlust = false
        losNoetig = false
    }
}
