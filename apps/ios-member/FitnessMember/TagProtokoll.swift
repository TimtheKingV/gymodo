import OSLog

/// Der eine Ort, an dem der Tag-Weg protokolliert wird.
///
/// Beim Geraetetest landete ein von aussen gescannter Tag auf dem Home-Tab
/// statt am Geraet, und es gab keine Moeglichkeit zu sehen, wo er
/// verschwindet: der Weg URL -> Token -> Tab -> Geraet hatte drei Stellen,
/// die still aufgaben. Sie sind geschlossen; diese Zeilen machen den Weg
/// nachpruefbar, falls doch wieder etwas fehlt.
///
/// Die URL steht mit `privacy: .public` im Protokoll. Sie ist kein Geheimnis
/// -- derselbe Text steht sichtbar als QR-Code auf dem Aufkleber am Geraet,
/// und der Token ist laut TagLink ausdruecklich ein oeffentlicher Locator,
/// aus dem keine Berechtigung folgt.
enum TagProtokoll {
    static let log = Logger(subsystem: "de.gymtaro.member", category: "tag")
}
