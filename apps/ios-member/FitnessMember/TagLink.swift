import Foundation

/// Validierung eingehender Universal Links.
///
/// Der Tag-Token ist ein oeffentlicher Locator. Aus einem gueltigen Link
/// folgt ausdruecklich keine Berechtigung — die Autorisierung findet
/// ausschliesslich serverseitig statt.
enum TagLink {
    static let host = "gymodo-web.vercel.app"

    private static let tokenLength = 22

    static func token(from url: URL) -> String? {
        guard url.scheme == "https", url.host() == host else { return nil }

        let segments = url.pathComponents.filter { $0 != "/" }
        guard segments.count == 2, segments[0] == "t" else { return nil }

        let token = segments[1]
        guard token.count == tokenLength,
              token.allSatisfy(isAllowedTokenCharacter)
        else { return nil }

        return token
    }

    /// Der gemeinsame Einstiegspunkt fuer alles, was ein Scanner liefert.
    ///
    /// Ein QR-Code traegt den vollstaendigen Universal Link
    /// (https://<host>/t/<token>), NFC ueber `onOpenURL` liefert dieselbe
    /// Form bereits als `URL`. Faellt der Scan doch mal als reiner Token an,
    /// geht er unveraendert durch -- der Server lehnt Unsinn ohnehin mit
    /// derselben Meldung ab. EIN Ort fuer diese Extraktion, damit ein
    /// dritter Aufrufer sie nicht erneut (und womoeglich falsch) nachbaut.
    static func token(fromScan scanned: String) -> String {
        URL(string: scanned).flatMap(token(from:)) ?? scanned
    }

    private static func isAllowedTokenCharacter(_ character: Character) -> Bool {
        character.isASCII
            && (character.isLetter || character.isNumber
                || character == "-" || character == "_")
    }
}
