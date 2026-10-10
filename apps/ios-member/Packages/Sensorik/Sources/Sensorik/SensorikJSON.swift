import Foundation

/// Kodierung von aufnahme.json und ratentest-*.json. Gleiches Verhalten wie
/// JSONEncoder.testnotiz / JSONDecoder.testnotiz im App-Target (Spec A 6.3:
/// ISO 8601 mit Offset, ohne Sekundenbruchteile) -- als eigene Kopie, weil
/// das Package das Testnotiz-Modul nicht kennen darf.
public enum SensorikJSON {
    public static func encoder(zeitzone: TimeZone = .current) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let stil = Date.ISO8601FormatStyle(timeZoneSeparator: .colon, timeZone: zeitzone)
        encoder.dateEncodingStrategy = .custom { datum, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(datum.formatted(stil))
        }
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
