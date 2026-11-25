import Foundation
import Koerperbild

/// Abbildung der Server-Felder `kamera` und `tempo` auf die Typen des
/// Pakets Koerperbild. Unbekannte Werte (ein neuerer Server) ergeben nil
/// statt eines Fehlers: die Uebung laeuft dann ohne Kamera.
extension BootstrapResponse.Exercise {
    /// nil bei Sekunden-/Meter-Uebungen, ohne `kamera`, bei unbekanntem
    /// Profil, Signal oder unbekannter Seite sowie bei einem Kameraprofil
    /// ohne Signal. Fehlende Seite (null bei `ohne_kamera`) gilt als `.beide`.
    var kameravorgabe: Kameravorgabe? {
        guard volumeKind == .reps, let kamera,
              tempophase(kamera.beginntMit) != nil,
              let profil = Kameraprofil(rawValue: kamera.profil) else { return nil }
        var signal: Gelenkwinkel?
        if let roh = kamera.signal {
            guard let bekannt = Gelenkwinkel(rawValue: roh) else { return nil }
            signal = bekannt
        }
        var seite = Seitenwahl.beide
        if let roh = kamera.seite {
            guard let bekannt = Seitenwahl(rawValue: roh) else { return nil }
            seite = bekannt
        }
        return Kameravorgabe(profil: profil, signal: signal, seite: seite)
    }

    /// Nil ohne `kameravorgabe`. Ohne `tempo` gilt der Standard; die Werte
    /// werden unveraendert uebergeben (Grenzen setzt die Sensorik).
    var uebungstempo: Uebungstempo? {
        guard kameravorgabe != nil, let kamera, let beginntMit = tempophase(kamera.beginntMit) else { return nil }
        guard let tempo else { return .standard(beginntMit: beginntMit) }
        return Uebungstempo(senken: tempo.senkenS, halten: tempo.haltenS, heben: tempo.hebenS, beginntMit: beginntMit)
    }

    /// Nur senken/heben: `Uebungstempo.init` bricht sonst per precondition ab.
    private func tempophase(_ roh: String) -> Tempophase? {
        guard let phase = Tempophase(rawValue: roh), phase == .senken || phase == .heben else { return nil }
        return phase
    }
}
