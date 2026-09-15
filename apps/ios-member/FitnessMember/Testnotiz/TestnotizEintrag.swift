#if DEBUG
import Foundation

/// Die Werte aus dem Format-Vertrag
/// (docs/superpowers/specs/2026-09-14-testnotiz-format.md). Die Schluessel
/// sind Englisch, weil der Ordner ein Vertrag zwischen Plattformen ist, kein
/// Oberflaechentext.
struct TestnotizSitzung: Codable, Sendable, Equatable {
    static let formatKennung = "gymodo.testnotiz/1"

    var format: String = TestnotizSitzung.formatKennung
    var platform: String = "ios"
    var session: Kopf
    var entries: [TestnotizEintrag]

    struct Kopf: Codable, Sendable, Equatable {
        var id: String
        var startedAt: Date
        var app: App
        var device: Geraet
    }

    struct App: Codable, Sendable, Equatable {
        var bundleId: String
        var version: String
        var build: String
        var configuration: String
    }

    struct Geraet: Codable, Sendable, Equatable {
        var model: String
        var os: String
        var screen: Bildschirm
    }

    struct Bildschirm: Codable, Sendable, Equatable {
        var width: Double
        var height: Double
        var scale: Double
    }
}

struct TestnotizEintrag: Codable, Sendable, Equatable, Identifiable {
    enum Art: String, Codable, Sendable {
        case crop, element, note
    }

    var id: UUID
    var index: Int
    var createdAt: Date
    var kind: Art
    var screen: Screen?
    var screenshot: String
    var crop: String?
    var cropRect: Ausschnittsrahmen?
    var element: Element?
    var note: String?
    var audio: String?
    var transcript: String?
    var runtime: Laufzeit
    var log: [Protokollzeile]

    struct Screen: Codable, Sendable, Equatable {
        var name: String
        var file: String
        var stack: [String]
        var context: [String: String]
    }

    struct Rechteck: Codable, Sendable, Equatable {
        var x: Double
        var y: Double
        var width: Double
        var height: Double
    }

    struct Ausschnittsrahmen: Codable, Sendable, Equatable {
        var points: Rechteck
        var pixels: Rechteck
    }

    struct Element: Codable, Sendable, Equatable {
        enum Quelle: String, Codable, Sendable {
            case accessibility, semantics
        }

        var source: Quelle
        var identifier: String?
        var label: String?
        var type: String
        var frame: Rechteck
        var file: String?
        var line: Int?

        // Synthetisiertes Codable laesst nil-Felder weg; der Vertrag
        // verlangt null, damit ein Leser beide Plattformen mit einem Schema
        // prueft.
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(source, forKey: .source)
            try c.encode(identifier, forKey: .identifier)
            try c.encode(label, forKey: .label)
            try c.encode(type, forKey: .type)
            try c.encode(frame, forKey: .frame)
            try c.encode(file, forKey: .file)
            try c.encode(line, forKey: .line)
        }
    }

    struct Laufzeit: Codable, Sendable, Equatable {
        var online: Bool
        var pendingWrites: Int
        var signedIn: Bool
        var studioId: String?

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(online, forKey: .online)
            try c.encode(pendingWrites, forKey: .pendingWrites)
            try c.encode(signedIn, forKey: .signedIn)
            try c.encode(studioId, forKey: .studioId)
        }
    }

    struct Protokollzeile: Codable, Sendable, Equatable {
        var at: Date
        var level: String
        var category: String
        var message: String
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(index, forKey: .index)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(kind, forKey: .kind)
        try c.encode(screen, forKey: .screen)
        try c.encode(screenshot, forKey: .screenshot)
        try c.encode(crop, forKey: .crop)
        try c.encode(cropRect, forKey: .cropRect)
        try c.encode(element, forKey: .element)
        try c.encode(note, forKey: .note)
        try c.encode(audio, forKey: .audio)
        try c.encode(transcript, forKey: .transcript)
        try c.encode(runtime, forKey: .runtime)
        try c.encode(log, forKey: .log)
    }
}

extension TestnotizEintrag.Rechteck {
    init(_ r: CGRect) {
        self.init(x: r.origin.x, y: r.origin.y, width: r.size.width, height: r.size.height)
    }
}

extension JSONEncoder {
    /// Zeitpunkte mit Offset statt "Z": wer den Ordner liest, sieht die
    /// Uhrzeit, die der Tester auf dem Telefon hatte.
    static func testnotiz(zeitzone: TimeZone = .current) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let stil = Date.ISO8601FormatStyle(timeZoneSeparator: .colon, timeZone: zeitzone)
        encoder.dateEncodingStrategy = .custom { datum, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(datum.formatted(stil))
        }
        return encoder
    }
}

extension JSONDecoder {
    static func testnotiz() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
#endif
