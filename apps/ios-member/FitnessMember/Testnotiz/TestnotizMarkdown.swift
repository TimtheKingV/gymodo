#if DEBUG
import Foundation

/// sitzung.md -- die Datei, die Claude Code liest. Eine reine Funktion ueber
/// die Werte: kein Date(), kein Dateisystem.
enum TestnotizMarkdown {
    static func rendern(_ sitzung: TestnotizSitzung, zeitzone: TimeZone) -> String {
        var teile: [String] = [kopf(sitzung, zeitzone: zeitzone)]
        for eintrag in sitzung.entries {
            teile.append(abschnitt(eintrag, zeitzone: zeitzone))
        }
        return teile.joined(separator: "\n\n") + "\n"
    }

    static func kopf(_ sitzung: TestnotizSitzung, zeitzone: TimeZone) -> String {
        let s = sitzung.session
        return "# Testsitzung \(Zeitformat.datumUhrzeit(s.startedAt, zeitzone: zeitzone)) — gymodo Member \(s.app.version) (\(s.app.build)), \(s.device.model), \(s.device.os)"
    }

    static func artName(_ art: TestnotizEintrag.Art) -> String {
        switch art {
        case .crop: "Ausschnitt"
        case .element: "Element"
        case .note: "Notiz"
        }
    }

    static func abschnitt(_ e: TestnotizEintrag, zeitzone: TimeZone) -> String {
        var zeilen: [String] = []
        let screenName = e.screen?.name ?? "unbekannter Screen"
        zeilen.append("## \(e.index) · \(Zeitformat.uhrzeit(e.createdAt, zeitzone: zeitzone)) · \(artName(e.kind)) · \(screenName)")

        if let screen = e.screen {
            let kontext = screen.context.keys.sorted().map { "\($0) \(screen.context[$0]!)" }.joined(separator: ", ")
            zeilen.append("**Screen:** `\(screen.file)`" + (kontext.isEmpty ? "" : " (\(kontext))"))
            if screen.stack.count > 1 {
                let namen = screen.stack.map { (($0 as NSString).lastPathComponent as NSString).deletingPathExtension }
                zeilen.append("**Ebenen:** " + namen.joined(separator: " → "))
            }
        } else {
            zeilen.append("**Screen:** unbekannt — kein Screen hat sich gemeldet")
        }

        if let element = e.element {
            zeilen.append("**Element:** " + elementZeile(element))
        }

        if let notiz = e.note, !notiz.isEmpty {
            zeilen.append("**Notiz:** \(notiz)")
        }
        if let audio = e.audio {
            if let transkript = e.transcript {
                zeilen.append("**Gesprochen:** \(transkript) ([Audio](\(audio)))")
            } else {
                zeilen.append("**Gesprochen:** Transkript fehlt, Audio liegt bei: [\(audio)](\(audio))")
            }
        }

        var bilder: [String] = []
        if let crop = e.crop { bilder.append("![Ausschnitt](\(crop))") }
        bilder.append("![Vollbild](\(e.screenshot))")
        zeilen.append(bilder.joined(separator: "\n"))

        if !e.log.isEmpty {
            let anzahl = e.log.count == 1 ? "1 Zeile" : "\(e.log.count) Zeilen"
            let protokoll = e.log.map {
                "\(Zeitformat.uhrzeit($0.at, zeitzone: zeitzone, sekunden: true)) \($0.level) \($0.category) — \($0.message)"
            }.joined(separator: "\n")
            zeilen.append("<details><summary>Protokoll (letzte 5 min, \(anzahl))</summary>\n\n\(protokoll)\n\n</details>")
        }

        return zeilen.joined(separator: "\n\n")
    }

    static func elementZeile(_ e: TestnotizEintrag.Element) -> String {
        var teile: [String] = []
        if let kennung = e.identifier { teile.append("`\(kennung)`") }
        var beschreibung: [String] = []
        if let label = e.label {
            let openingQuote = "\u{201E}"
            let closingQuote = "\u{201C}"
            beschreibung.append(openingQuote + label + closingQuote)
        }
        beschreibung.append(e.type)
        if let file = e.file, let line = e.line { beschreibung.append("`\(file):\(line)`") }
        teile.append(beschreibung.joined(separator: ", "))
        return teile.joined(separator: " — ")
    }
}
#endif
