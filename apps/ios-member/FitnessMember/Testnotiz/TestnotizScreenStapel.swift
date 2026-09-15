#if DEBUG
import Foundation

/// Ein Screen, der gerade sichtbar ist.
struct ScreenEintrag: Equatable, Sendable {
    let token: UUID
    /// Repo-relativ, z.B. apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift
    let datei: String
    var kontext: [String: String]

    init(token: UUID = UUID(), datei: String, kontext: [String: String] = [:]) {
        self.token = token
        self.datei = datei
        self.kontext = kontext
    }

    var name: String {
        ((datei as NSString).lastPathComponent as NSString).deletingPathExtension
    }
}

/// Die sichtbaren Ebenen von unten nach oben: der Screen, darueber Sheets
/// und Cover. Ein Push ersetzt die Wurzel (die ueberdeckte meldet
/// onDisappear), er stapelt nicht.
///
/// Gezaehlt wird je Token, weil ein Modifier an einer Group auf jedes Kind
/// verteilt wird: beim Wechsel erscheint das neue Kind VOR dem Verschwinden
/// des alten, und ohne Zaehler naehme das Verschwinden den Eintrag mit.
struct TestnotizScreenStapel {
    private(set) var eintraege: [ScreenEintrag] = []
    private var zaehler: [UUID: Int] = [:]

    var aktueller: ScreenEintrag? { eintraege.last }
    var pfad: [String] { eintraege.map(\.datei) }

    mutating func erschienen(_ eintrag: ScreenEintrag) {
        zaehler[eintrag.token, default: 0] += 1
        eintraege.removeAll { $0.token == eintrag.token }
        eintraege.append(eintrag)
    }

    mutating func verschwunden(token: UUID) {
        guard let stand = zaehler[token] else { return }
        if stand > 1 {
            zaehler[token] = stand - 1
        } else {
            zaehler[token] = nil
            eintraege.removeAll { $0.token == token }
        }
    }

    mutating func kontextAktualisieren(token: UUID, kontext: [String: String]) {
        guard let i = eintraege.firstIndex(where: { $0.token == token }) else { return }
        eintraege[i].kontext = kontext
    }
}

/// #fileID liefert nur "Modul/Datei.swift" -- ohne Verzeichnis kann Claude
/// Code die Datei nicht oeffnen. #filePath liefert den absoluten Pfad auf
/// dem Build-Mac; ab "apps/ios-member/" ist er repo-relativ.
enum Quellpfad {
    static func relativ(_ pfad: String) -> String {
        if let treffer = pfad.range(of: "/apps/ios-member/") {
            return String(pfad[pfad.index(after: treffer.lowerBound)...])
        }
        return (pfad as NSString).lastPathComponent
    }
}
#endif
