import Foundation

/// Die eine Anweisung, die beim Aufstellen vor der Kamera gezeigt wird.
/// Koordinaten sind die des ungespiegelten Bilds (0...1, Ursprung oben links);
/// die Anzeige ist gespiegelt, deshalb liegt der Koerper dort bei `1 - x`.
public enum Aufstellanweisung: Equatable, Sendable {
    case inDenRahmen, schrittZurueck, nachLinks, nachRechts, mehrLicht, passt

    static let randOben = 0.04
    static let randUnten = 0.96
    static let anzeigeGrenzeRechts = 0.7
    static let anzeigeGrenzeLinks = 0.3

    public static func aus(skelett: Skelett?, pruefung: Erkennungspruefung, vorgabe: Kameravorgabe) -> Aufstellanweisung {
        // 1. Niemand sicher zu sehen.
        guard let skelett, skelett.punkte.values.contains(where: { $0.sicherheit >= Skelett.mindestSicherheit }) else {
            return .inDenRahmen
        }
        let seite = pruefung.fuehrendeSeite
        let pflicht = vorgabe.pflichtgelenke(seite)

        // 2./3. Fehlende Pflichtgruppen: mit unsicheren Punkten heisst es Licht, ohne Punkte Abstand.
        var ohnePunkte = false
        var nurUnsicher = false
        for gruppe in pruefung.fehlendeGruppen {
            let fehlend = gruppe.gelenke(seite).intersection(pflicht).filter { skelett.sicher($0) == nil }
            if fehlend.contains(where: { skelett.punkte[$0] == nil }) {
                ohnePunkte = true
            } else {
                nurUnsicher = true
            }
        }
        if nurUnsicher { return .mehrLicht }
        if ohnePunkte { return .schrittZurueck }

        let sichere = pflicht.compactMap { skelett.sicher($0) }
        if sichere.contains(where: { $0.y < randOben || $0.y > randUnten }) { return .schrittZurueck }

        // 4. Seitliche Lage in der gespiegelten Anzeige.
        if !sichere.isEmpty {
            let anzeige = 1 - sichere.map(\.x).reduce(0, +) / Double(sichere.count)
            if anzeige > anzeigeGrenzeRechts { return .nachLinks }
            if anzeige < anzeigeGrenzeLinks { return .nachRechts }
        }

        // 5.
        return pruefung.imRahmen ? .passt : .schrittZurueck
    }
}
