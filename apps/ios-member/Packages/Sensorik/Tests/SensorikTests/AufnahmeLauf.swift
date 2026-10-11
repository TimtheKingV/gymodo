import Foundation
@testable import Sensorik

struct AufnahmeErgebnis {
    let ordner: String
    let startedAt: Date
    let art: Befestigungsart
    let repsWahr: Int
    let fuerZaehler: Bool
    let gezaehlt: Int
    let unsicher: UnsicherGrund?
    let ereignisse: [ZaehlerEreignis]
}

enum AufnahmeLauf {
    /// Spielt eine Aufnahme so durch den Zaehler, wie die App es live tut:
    /// Messwerte der Reihe nach, Luecken-Zeilen als expliziter Abriss, ein
    /// Ratenwechsel baut den Zaehler nicht neu (die Rate gilt fuer den Filter,
    /// ein Wechsel mitten im Satz kommt nur in der Diagnose vor).
    static func zaehlen(ordner: URL, art: Befestigungsart) throws -> [ZaehlerEreignis] {
        let (datei, eintraege) = try SensorAufnahmeLeser.lesen(ordner: ordner)
        var zaehler = Zaehler(profil: .fuer(art), rateHz: Double(datei.sensor.rateSollHz))
        var ereignisse: [ZaehlerEreignis] = []
        for eintrag in eintraege {
            switch eintrag {
            case .messwert(let m): ereignisse += zaehler.verarbeite(m)
            case .luecke(let von, let bis): ereignisse += zaehler.luecke(von: von, bis: bis)
            case .rate: break
            }
        }
        ereignisse += zaehler.abschliessen()
        return ereignisse
    }

    /// Alle Ordner mit Korrektur-Eintrag, Art und Wahrheit. Ordner ohne
    /// Eintrag, ohne messwerte.csv und lose Dateien (ratentest-*.json) werden
    /// uebersprungen statt zu werfen: neue Aufnahmen liegen oft schon da,
    /// bevor ihre Korrektur geschrieben ist.
    static func ueberAlle() throws -> [AufnahmeErgebnis] {
        let k = try Korrekturen.laden()
        let fm = FileManager.default
        var ergebnisse: [AufnahmeErgebnis] = []
        for (name, eintrag) in k.aufnahmen.sorted(by: { $0.key < $1.key }) {
            guard let art = eintrag.befestigungsart, let wahr = eintrag.repsWahr else { continue }
            let ordner = Pfade.aufnahmen.appendingPathComponent(name)
            guard fm.fileExists(atPath: ordner.appendingPathComponent("messwerte.csv").path) else { continue }
            let (datei, _) = try SensorAufnahmeLeser.lesen(ordner: ordner)
            let ereignisse = try zaehlen(ordner: ordner, art: art)
            let gezaehlt = ereignisse.filter { if case .wiederholung = $0 { true } else { false } }.count
            let unsicher = ereignisse.lazy.compactMap { if case .unsicher(let g) = $0 { g } else { nil } }.first
            ergebnisse.append(AufnahmeErgebnis(
                ordner: name, startedAt: datei.startedAt, art: art, repsWahr: wahr,
                fuerZaehler: eintrag.fuerZaehler, gezaehlt: gezaehlt, unsicher: unsicher, ereignisse: ereignisse))
        }
        return ergebnisse
    }
}
