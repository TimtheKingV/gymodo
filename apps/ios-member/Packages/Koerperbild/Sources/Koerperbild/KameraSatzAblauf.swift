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
    static let vorlaufSekunden: TimeInterval = 2
    /// Ununterbrochene Ruhe, nach der ein Satz mit mindestens einer Wiederholung von selbst endet.
    static let ruheBisSatzende: TimeInterval = 8
    /// Unruhe, die laenger als das dauert, zaehlt als Bewegung seit der Los-Marke.
    static let bewegungAb: TimeInterval = 0.5
    /// Ohne Wiederholung nach so vielen Wellenperioden: keine Bewegung erkannt.
    static let perioden = 2.0
    static let bildrateFenster: TimeInterval = 3
    static let mindestBildrate = 15.0

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
    private var vorlaufBeginn: TimeInterval?
    private var ruheSeit: TimeInterval?
    private var unruheSeit: TimeInterval?
    private var bewegtSichSeitLos = false
    private var bildzeiten: [TimeInterval] = []

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
        bildrateAktualisieren(t: t)
        switch schritt {
        case .aufstellen:
            anweisung = Aufstellanweisung.aus(skelett: skelett, pruefung: pruefung, vorgabe: vorgabe)
            if pruefung.bestanden { schritt = .countdown(rest: nil) }
        case .countdown:
            countdown(t: t)
        case .satz:
            satz(t: t, lage: lage)
        case .verloren:
            if pruefung.bestanden {
                vorlaufBeginn = t
                schritt = .vorlauf(rest: Int(Self.vorlaufSekunden))
            }
        case .vorlauf:
            vorlauf(t: t)
        default:
            break
        }
        switch schritt {
        case .satz, .vorlauf: bildrateZuNiedrig = bildrateZuNiedrig(t: t)
        default: break
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
        switch schritt {
        case .satz, .verloren, .vorlauf: break
        default: return
        }
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

    /// Nach `.keineBewegung`: zurueck in den Countdown, Rueckblick und Spur beginnen neu.
    public mutating func neuStarten() {
        guard schritt == .keineBewegung else { return }
        satzrueckblick = Satzrueckblick(welle: welle, hubWarGemerkt: koerperlage.hubWarGemerkt)
        spur = []
        sollzeit = nil
        losMarke = nil
        countdownBeginn = nil
        takt = .imTakt
        ruhemessungZuruecksetzen()
        schritt = .countdown(rest: nil)
    }

    /// App im Hintergrund: der Satz pausiert (`.verloren`), ein Countdown beginnt beim Aufstellen von vorn.
    /// Die festgehaltene Seite bleibt.
    public mutating func unterbrechen() {
        switch schritt {
        case .satz, .vorlauf:
            koerperlage.unterbrechen()
            takt = .imTakt
            nebenDerBahnSeit = nil
            vorlaufBeginn = nil
            schritt = .verloren
        case .countdown:
            countdownBeginn = nil
            schritt = .aufstellen
        default:
            break
        }
        pruefung.zuruecksetzen()
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
            neueLosMarke(t)
            schritt = .satz
        } else {
            schritt = .countdown(rest: Int((Self.countdownSekunden - vergangen).rounded(.up)))
        }
    }

    private mutating func vorlauf(t: TimeInterval) {
        guard let beginn = vorlaufBeginn else { return }
        if pruefung.verloren {
            vorlaufBeginn = nil
            schritt = .verloren
            return
        }
        let vergangen = t - beginn
        if vergangen >= Self.vorlaufSekunden {
            koerperlage.los(t: t)
            neueLosMarke(t)
            schritt = .satz
        } else {
            schritt = .vorlauf(rest: Int((Self.vorlaufSekunden - vergangen).rounded(.up)))
        }
    }

    private mutating func neueLosMarke(_ t: TimeInterval) {
        losMarke = t
        sollzeit = 0
        vorlaufBeginn = nil
        nebenDerBahnSeit = nil
        ruhemessungZuruecksetzen()
    }

    private mutating func ruhemessungZuruecksetzen() {
        ruheSeit = nil
        unruheSeit = nil
        bewegtSichSeitLos = false
    }

    private mutating func satz(t: TimeInterval, lage: Lage) {
        guard let losMarke else { return }
        if pruefung.verloren {
            // Laenger als 1 s ohne Pflichtgelenke: der Satz pausiert, `sollzeit` steht.
            koerperlage.unterbrechen()
            takt = .imTakt
            nebenDerBahnSeit = nil
            schritt = .verloren
            return
        }
        let s = t - losMarke
        sollzeit = s
        satzrueckblick.erfasse(lage, sollzeit: s)
        spur.append(Spurpunkt(sollzeit: s, lage: lage.lage, sicher: lage.sicher))
        spur.removeAll { $0.sollzeit < s - Self.spurDauer }
        if !seiteFestgehalten, let seite = koerperlage.fuehrendeSeite {
            pruefung.seiteFesthalten(seite)
            seiteFestgehalten = true
        }
        taktPruefen(t: t, sollzeit: s, lage: lage)
        satzendePruefen(t: t, sollzeit: s)
    }

    private mutating func satzendePruefen(t: TimeInterval, sollzeit s: TimeInterval) {
        if koerperlage.hubZuKlein {
            schritt = .bewegungZuKlein
            return
        }
        let ruhig = koerperlage.istRuhig
        ruheSeit = ruhig ? (ruheSeit ?? t) : nil
        if ruhig {
            unruheSeit = nil
        } else {
            unruheSeit = unruheSeit ?? t
            if t - (unruheSeit ?? t) > Self.bewegungAb { bewegtSichSeitLos = true }
        }
        if wiederholungen >= 1 {
            if let seit = ruheSeit, t - seit >= Self.ruheBisSatzende { satzBeenden() }
        } else if s > Self.perioden * tempo.vorgabe.periode, !bewegtSichSeitLos {
            schritt = .keineBewegung
        }
    }

    private mutating func bildrateAktualisieren(t: TimeInterval) {
        bildzeiten.append(t)
        while bildzeiten.count > 1, bildzeiten[1] <= t - Self.bildrateFenster { bildzeiten.removeFirst() }
    }

    /// Mittlere Bildrate der letzten 3 s unter 15/s; erst wenn das Fenster voll ist.
    private func bildrateZuNiedrig(t: TimeInterval) -> Bool {
        guard let erste = bildzeiten.first, t - erste >= Self.bildrateFenster - 1e-9 else { return false }
        return Double(bildzeiten.count - 1) / (t - erste) < Self.mindestBildrate
    }

    private mutating func taktPruefen(t: TimeInterval, sollzeit s: TimeInterval, lage: Lage) {
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
