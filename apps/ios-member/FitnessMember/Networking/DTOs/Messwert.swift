import Foundation

/// Ein Punkt im Gewichtsverlauf -- ein ORTSDATUM ("yyyy-MM-dd"), kein
/// Zeitpunkt: ein Gewicht gehoert zu einem Tag, nicht zu einer Uhrzeit.
///
/// Codable statt nur Decodable: `VerlaufStore.messwerte` schreibt diesen
/// Typ als Teil von `GespeicherterVerlauf` auf Platte (Aufgabe 5).
///
/// Sendable explizit, wie `BootstrapResponse.Member` -- derselbe Grund:
/// `Member.latestWeight` referenziert diesen Typ aus einer anderen Datei,
/// und die implizite Sendable-Herleitung verpasst das bei einem
/// sauberen Build.
struct Messwert: Codable, Equatable, Sendable {
    let measuredOn: String
    let weightKg: Double
}

/// Antwort auf `GET /me/measurements`.
struct MeasurementsResponse: Decodable, Equatable, Sendable {
    /// Die Kopfzeile fuer die Gewichtskarte auf Home -- serverseitig aus
    /// `points` gerechnet, keine zweite Rechnung im Client.
    ///
    /// Codable, nicht nur Decodable: `VerlaufStore.messwertKopf` schreibt
    /// diesen Typ mit auf Platte, und `messwertEintragen`/`messwertEntfernen`
    /// bauen ihn lokal neu zusammen (siehe VerlaufStore).
    struct Summary: Codable, Equatable, Sendable {
        let first: Messwert?
        let latest: Messwert?
        /// latest - first, eine Nachkommastelle. Kein Trend, keine
        /// Glaettung -- eine Differenz (Spec Abschnitt 6).
        let changeKg: Double?
    }

    let points: [Messwert]
    let summary: Summary
}

/// Antwort auf `PUT /me/measurements`.
struct MesswertAntwort: Decodable, Equatable, Sendable {
    let measuredOn: String
    let weightKg: Double
    /// true, wenn dieser Eintrag das aktive Zielgewicht erreicht hat.
    let goalReached: Bool
}

/// Anfrage-Rumpf fuer `PUT /me/measurements`.
struct MesswertWrite: Encodable, Equatable {
    let measuredOn: String
    let weightKg: Double
}
