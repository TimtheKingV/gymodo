import Foundation
import Sensorik

/// Der Ablauf eines Satzes vor der Kamera als reine Zustandsmaschine: Video, Aufstellen, Countdown, Satz.
/// Die Zeit kommt nur ueber `bild(t:skelett:)`; es gibt keine Uhr und keine Kamera in dieser Datei.
public struct KameraSatzAblauf: Sendable {
    public enum Schritt: Equatable, Sendable {
        case video, aufstellen
        /// nil: wartet auf 0,5 s Ruhe; sonst 3, 2, 1.
        case countdown(rest: Int?)
        case satz, verloren
        /// 2, 1
        case vorlauf(rest: Int)
        case keineBewegung
        case bewegungZuKlein
        case fertig(Satzende)
    }

    public enum Satzende: Equatable, Sendable {
        case beendet(Satzergebnis)
        case ohneKamera(gezaehlt: Int?)
    }

    public struct Satzergebnis: Equatable, Sendable {
        public let wiederholungen: Int
        /// nil unter 3 Wiederholungen.
        public let rueckblick: Rueckblick?
        public let hubGrad: Double?

        public init(wiederholungen: Int, rueckblick: Rueckblick?, hubGrad: Double?) {
            self.wiederholungen = wiederholungen; self.rueckblick = rueckblick; self.hubGrad = hubGrad
        }
    }

    public enum Takt: Equatable, Sendable { case imTakt, zuSchnell, zuLangsam }

    public struct Spurpunkt: Equatable, Sendable {
        public let sollzeit: TimeInterval
        public let lage: Double
        public let sicher: Bool

        public init(sollzeit: TimeInterval, lage: Double, sicher: Bool) {
            self.sollzeit = sollzeit; self.lage = lage; self.sicher = sicher
        }
    }

    static let countdownSekunden: TimeInterval = 3
    /// So lange darf eine sichere Lage neben der Bahn liegen, bevor `takt` kippt.
    static let nebenDerBahnNach: TimeInterval = 0.5
    static let spurDauer: TimeInterval = 6
    /// Vorausschau, an der die Richtung der Soll-Welle erkannt wird.
    static let richtungsschritt: TimeInterval = 0.05

    public private(set) var schritt: Schritt
    public private(set) var sollzeit: TimeInterval?
    public let welle: Sollwelle
    public private(set) var takt: Takt = .imTakt
    public private(set) var spur: [Spurpunkt] = []
    public private(set) var anweisung: Aufstellanweisung = .inDenRahmen
    public private(set) var bildrateZuNiedrig = false
    public let tempo: Uebungstempo
    public let vorgabe: Kameravorgabe

    private var pruefung: Erkennungspruefung
    private var koerperlage: Koerperlage
    private var satzrueckblick: Satzrueckblick
    private var countdownBeginn: TimeInterval?
    private var losMarke: TimeInterval?
    private var seiteFestgehalten = false
    private var nebenDerBahnSeit: TimeInterval?

    public init(vorgabe: Kameravorgabe, tempo: Uebungstempo, gemerkterHub: Double?, mitVideo: Bool) {
        self.vorgabe = vorgabe
        self.tempo = tempo
        self.welle = Sollwelle(vorgabe: tempo.vorgabe)
        self.pruefung = Erkennungspruefung(vorgabe: vorgabe)
        self.koerperlage = Koerperlage(vorgabe: vorgabe, gemerkterHub: gemerkterHub)
        self.satzrueckblick = Satzrueckblick(welle: welle, hubWarGemerkt: koerperlage.hubWarGemerkt)
        self.schritt = mitVideo ? .video : .aufstellen
    }

    public var wiederholungen: Int { koerperlage.wiederholungen.count }

    public var phase: Tempophase? {
        guard let sollzeit, let weg = welle.weg(bei: sollzeit) else { return nil }
        return tempo.phase(weg)
    }

    public var fehlendeGruppen: Set<Gelenkgruppe> { pruefung.fehlendeGruppen }

    // MARK: Eingaben

    public mutating func handyAufstellen() {
        guard schritt == .video else { return }
        schritt = .aufstellen
    }

    public mutating func bild(t: TimeInterval, skelett: Skelett?) {
        pruefung.eingabe(t: t, skelett: skelett)
        let lage = koerperlage.verarbeite(t: t, skelett: skelett)
        switch schritt {
        case .aufstellen:
            anweisung = Aufstellanweisung.aus(skelett: skelett, pruefung: pruefung, vorgabe: vorgabe)
            if pruefung.bestanden { schritt = .countdown(rest: nil) }
        case .countdown:
            countdown(t: t)
        case .satz:
            satz(t: t, lage: lage)
        default:
            break
        }
    }

    /// Aus dem Countdown zurueck zum Aufstellen; die Pruefung beginnt von vorn.
    public mutating func abbrechen() {
        guard case .countdown = schritt else { return }
        pruefung.zuruecksetzen()
        countdownBeginn = nil
        schritt = .aufstellen
    }

    public mutating func satzBeenden() {
        guard schritt == .satz else { return }
        let n = wiederholungen
        guard n >= 1 else {
            schritt = .fertig(.ohneKamera(gezaehlt: nil))
            return
        }
        let ergebnis = Satzergebnis(wiederholungen: n,
                                    rueckblick: satzrueckblick.ergebnis(wiederholungen: koerperlage.wiederholungen),
                                    hubGrad: koerperlage.hubGrad)
        schritt = .fertig(.beendet(ergebnis))
    }

    public mutating func ohneKamera() {
        if case .fertig = schritt { return }
        let n = wiederholungen
        schritt = .fertig(.ohneKamera(gezaehlt: n > 0 ? n : nil))
    }

    // MARK: Schritte

    private mutating func countdown(t: TimeInterval) {
        if pruefung.verloren {
            countdownBeginn = nil
            schritt = .aufstellen
            return
        }
        if countdownBeginn == nil {
            guard koerperlage.istRuhig else { return }
            countdownBeginn = t
        }
        let vergangen = t - (countdownBeginn ?? t)
        if vergangen >= Self.countdownSekunden {
            koerperlage.los(t: t)
            losMarke = t
            sollzeit = 0
            schritt = .satz
        } else {
            schritt = .countdown(rest: Int((Self.countdownSekunden - vergangen).rounded(.up)))
        }
    }

    private mutating func satz(t: TimeInterval, lage: Lage) {
        guard let losMarke else { return }
        let s = t - losMarke
        sollzeit = s
        satzrueckblick.erfasse(lage, sollzeit: s)
        spur.append(Spurpunkt(sollzeit: s, lage: lage.lage, sicher: lage.sicher))
        spur.removeAll { $0.sollzeit < s - Self.spurDauer }
        if !seiteFestgehalten, let seite = koerperlage.fuehrendeSeite {
            pruefung.seiteFesthalten(seite)
            seiteFestgehalten = true
        }
        takt(t: t, sollzeit: s, lage: lage)
    }

    private mutating func takt(t: TimeInterval, sollzeit s: TimeInterval, lage: Lage) {
        guard lage.sicher else {
            nebenDerBahnSeit = nil
            return
        }
        if welle.inDerBahn(lage.lage, bei: s) {
            nebenDerBahnSeit = nil
            takt = .imTakt
            return
        }
        if nebenDerBahnSeit == nil { nebenDerBahnSeit = t }
        guard t - (nebenDerBahnSeit ?? t) > Self.nebenDerBahnNach else { return }
        let soll = welle.lage(bei: s)
        let vorher = welle.lage(bei: s + Self.richtungsschritt)
        let zuSchnell: Bool
        if vorher > soll {
            zuSchnell = lage.lage > soll
        } else if vorher < soll {
            zuSchnell = lage.lage < soll
        } else {
            zuSchnell = lage.lage < soll - welle.halbeBahnbreite
        }
        takt = zuSchnell ? .zuSchnell : .zuLangsam
    }
}
