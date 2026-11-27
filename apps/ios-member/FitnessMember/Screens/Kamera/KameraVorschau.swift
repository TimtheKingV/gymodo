#if DEBUG
import Koerperbild

/// Feste Daten fuer die Vorschauen: ein stehender Koerper, keine Kamera noetig.
enum KameraVorschau {
    static func skelett() -> Skelett {
        let orte: [Gelenk: (Double, Double)] = [
            .nase: (0.5, 0.20), .hals: (0.5, 0.27),
            .schulterL: (0.38, 0.30), .schulterR: (0.62, 0.30),
            .ellbogenL: (0.34, 0.42), .ellbogenR: (0.66, 0.42),
            .handL: (0.36, 0.52), .handR: (0.64, 0.52),
            .hueftL: (0.43, 0.52), .hueftR: (0.57, 0.52),
            .knieL: (0.42, 0.68), .knieR: (0.58, 0.68),
            .fussL: (0.41, 0.84), .fussR: (0.59, 0.84),
        ]
        return Skelett(punkte: orte.mapValues { Punkt(x: $0.0, y: $0.1, sicherheit: 1) }, seitenverhaeltnis: 0.75)
    }
}
#endif
