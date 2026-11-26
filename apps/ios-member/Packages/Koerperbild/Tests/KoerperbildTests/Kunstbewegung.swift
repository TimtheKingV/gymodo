import Foundation
@testable import Koerperbild
import Sensorik

/// Kameravorgabe fuer Curls: Oberkoerper, Signal Ellbogen, beide Seiten.
let curl = Kameravorgabe(profil: .oberkoerper, signal: .ellbogen, seite: .beide)!

typealias Messwert = (t: Double, winkel: Double)

/// Skelett mit festen Schultern und Hueften; die Haende stehen so, dass der
/// vorzeichenbehaftete Ellbogenwinkel genau `ellbogenL` bzw. `ellbogenR` ist
/// (Werte ueber 180 laufen ueber die Grenze und erscheinen als negativer Winkel).
func armSkelett(ellbogenL: Double, ellbogenR: Double, sicherheitL: Double = 1, sicherheitR: Double = 1) -> Skelett {
    var punkte: [Gelenk: Punkt] = [
        .nase: Punkt(x: 0.5, y: 0.1, sicherheit: 1),
        .hals: Punkt(x: 0.5, y: 0.25, sicherheit: 1),
        .wurzel: Punkt(x: 0.5, y: 0.7, sicherheit: 1),
        .hueftL: Punkt(x: 0.45, y: 0.7, sicherheit: 1),
        .hueftR: Punkt(x: 0.55, y: 0.7, sicherheit: 1),
        .knieL: Punkt(x: 0.45, y: 0.85, sicherheit: 1),
        .knieR: Punkt(x: 0.55, y: 0.85, sicherheit: 1),
        .fussL: Punkt(x: 0.45, y: 0.97, sicherheit: 1),
        .fussR: Punkt(x: 0.55, y: 0.97, sicherheit: 1),
    ]
    func arm(schulter: Gelenk, ellbogen: Gelenk, hand: Gelenk, x: Double, winkel: Double, sicherheit: Double) {
        let laenge = 0.2
        let a = winkel * .pi / 180
        punkte[schulter] = Punkt(x: x, y: 0.3, sicherheit: sicherheit)
        punkte[ellbogen] = Punkt(x: x, y: 0.5, sicherheit: sicherheit)
        punkte[hand] = Punkt(x: x + laenge * sin(a), y: 0.5 - laenge * cos(a), sicherheit: sicherheit)
    }
    arm(schulter: .schulterL, ellbogen: .ellbogenL, hand: .handL, x: 0.35, winkel: ellbogenL, sicherheit: sicherheitL)
    arm(schulter: .schulterR, ellbogen: .ellbogenR, hand: .handR, x: 0.65, winkel: ellbogenR, sicherheit: sicherheitR)
    return Skelett(punkte: punkte, seitenverhaeltnis: 1)
}

/// Cosinus-Bewegung des Winkels von `von` nach `bis` und zurueck, mit 1 s Ruhe davor
/// und 0,5 s Ausklingen danach.
func satz(wdh: Int, hin: Double, rueck: Double, von: Double, bis: Double, rate: Double = 30) -> [Messwert] {
    var ergebnis: [Messwert] = []
    var i = 0
    func neu(_ w: Double) { ergebnis.append((Double(i) / rate, w)); i += 1 }
    for _ in 0..<Int(rate) { neu(von) }
    func weg(_ n: Int, _ a: Double, _ b: Double) {
        for k in 0..<n { neu(a + (b - a) * (1 - cos(.pi * Double(k) / Double(n))) / 2) }
    }
    for _ in 0..<wdh {
        weg(Int((hin * rate).rounded()), von, bis)
        weg(Int((rueck * rate).rounded()), bis, von)
    }
    for _ in 0..<Int(0.5 * rate) { neu(von) }
    return ergebnis
}

/// Winkel `um` mit deterministischem Zittern von `ausschlag` Grad.
func rauschen(dauer: Double, um: Double, ausschlag: Double, rate: Double = 30) -> [Messwert] {
    var zufall: UInt64 = 12345
    return (0..<Int(dauer * rate)).map { i in
        zufall = zufall &* 6364136223846793005 &+ 1442695040888963407
        let r = Double(zufall >> 11) / Double(1 << 53) * 2 - 1
        return (Double(i) / rate, um + ausschlag * r)
    }
}

/// Roher Winkel 150 -> 200 -> 150 (200 liegt hinter der +-180-Grenze), mit 1 s Ruhe davor und 0,5 s danach.
func uebersprung(wdh: Int) -> [Messwert] {
    satz(wdh: wdh, hin: 2, rueck: 2, von: 150, bis: 200)
}

private func ausMesswerten(_ m: Messwert) -> Skelett { armSkelett(ellbogenL: m.winkel, ellbogenR: m.winkel) }

/// Speist Messwerte ein. Bei `versatz == 0` wird nach der 1 s Ruhe `los` gerufen.
/// Gibt die Lagen ab dem Los zurueck.
@discardableResult
func speise(_ k: inout Koerperlage, _ werte: [Messwert], bis: Double? = nil, versatz: Double = 0,
            skelett: (Messwert) -> Skelett? = ausMesswerten) -> [Lage] {
    var lagen: [Lage] = []
    var gelost = versatz != 0
    for m in werte {
        if let bis, m.t > bis { break }
        if !gelost && m.t >= 1.0 { k.los(t: m.t + versatz); gelost = true }
        let l = k.verarbeite(t: m.t + versatz, skelett: skelett(m))
        if gelost { lagen.append(l) }
    }
    return lagen
}

func lagenUndStand(_ werte: [Messwert], gemerkterHub: Double?) -> (Koerperlage, [Lage]) {
    var k = Koerperlage(vorgabe: curl, gemerkterHub: gemerkterHub)
    let lagen = speise(&k, werte)
    return (k, lagen)
}
func lagenImLauf(_ werte: [Messwert], gemerkterHub: Double?) -> [Lage] {
    lagenUndStand(werte, gemerkterHub: gemerkterHub).1
}
func lauf(_ werte: [Messwert], gemerkterHub: Double? = nil) -> Koerperlage {
    lagenUndStand(werte, gemerkterHub: gemerkterHub).0
}
/// Wie `lauf`, aber zwischen `von` und `bis` kommt kein Skelett.
func laufMitLuecke(_ werte: [Messwert], von: Double, bis: Double) -> Koerperlage {
    var k = Koerperlage(vorgabe: curl, gemerkterHub: nil)
    speise(&k, werte) { m in (m.t >= von && m.t <= bis) ? nil : armSkelett(ellbogenL: m.winkel, ellbogenR: m.winkel) }
    return k
}
/// Eine Seite ruht bei 170 Grad, die andere macht `wdh` Wiederholungen.
func laufEinarmig(arbeitet: Koerperseite, sicherheitRuhend: Double, sicherheitArbeitend: Double, wdh: Int) -> Koerperlage {
    var k = Koerperlage(vorgabe: curl, gemerkterHub: nil)
    speise(&k, satz(wdh: wdh, hin: 2, rueck: 2, von: 170, bis: 50)) { m in
        arbeitet == .rechts
            ? armSkelett(ellbogenL: 170, ellbogenR: m.winkel, sicherheitL: sicherheitRuhend, sicherheitR: sicherheitArbeitend)
            : armSkelett(ellbogenL: m.winkel, ellbogenR: 170, sicherheitL: sicherheitArbeitend, sicherheitR: sicherheitRuhend)
    }
    return k
}
/// Wie `lauf`, aber der Winkel ist der rohe, ungefaltete Wert (kann ueber 180 laufen).
func laufRoh(vorzeichenWinkel: [Messwert]) -> Koerperlage {
    lauf(vorzeichenWinkel)
}

/// Linke Seite im Bild, Kniewinkel `winkel` (Hueft-Knie-Fuss); die Fuesse fehlen bei `ohneFuesse`.
/// Geteilt von den Tests fuer `KameraSatzAblauf` und `FlowZaehler`.
func kniebeugeSkelett(knie winkel: Double, ohneFuesse: Bool = false) -> Skelett {
    let a = winkel * .pi / 180
    var punkte: [Gelenk: Punkt] = [
        .schulterL: Punkt(x: 0.5, y: 0.2, sicherheit: 1),
        .hueftL: Punkt(x: 0.5, y: 0.5, sicherheit: 1),
        .knieL: Punkt(x: 0.5, y: 0.7, sicherheit: 1),
        .fussL: Punkt(x: 0.5 + 0.2 * sin(a), y: 0.7 - 0.2 * cos(a), sicherheit: 1),
    ]
    if ohneFuesse { punkte[.fussL] = nil }
    return Skelett(punkte: punkte, seitenverhaeltnis: 1)
}
