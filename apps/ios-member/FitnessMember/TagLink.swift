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

    private static func isAllowedTokenCharacter(_ character: Character) -> Bool {
        character.isASCII
            && (character.isLetter || character.isNumber
                || character == "-" || character == "_")
    }
}
