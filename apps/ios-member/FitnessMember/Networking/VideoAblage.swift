import CryptoKit
import Foundation

/// Uebungsvideos als Dateien in Caches (Testnotiz 11.10., #1).
///
/// Nicht URLCache: die signierte URL traegt einen Token, der nach 15
/// Minuten ablaeuft und bei jedem Abruf ein anderer ist -- ein Cache nach
/// URL traefe nie wieder. Schluessel ist deshalb der Speicherpfad. Und
/// eine Schleife, die nach dem ersten Laden auf der Platte liegt, laeuft
/// auch im Keller ohne Empfang weiter.
///
/// Die Dateien sind klein (Katalog: ca. 30 KB je Uebung) -- kein Aufraeumen
/// noetig, Caches darf das System selbst leeren.
actor VideoAblage {
    typealias Laden = @Sendable (URL) async -> Data?

    private let ordner: URL
    private let laden: Laden
    /// Uebung -> Dateiname der zuletzt abgelegten Fassung. Liegt neben den
    /// Dateien auf der Platte: nach einem Neustart ohne Netz kennt der
    /// Vorrat keine Quellen, die Datei soll trotzdem laufen.
    private var index: [String: String]
    /// Laufende Downloads je Datei -- zwei Zeilen derselben Uebung (Liste
    /// und Blockzeile) sollen nicht zweimal laden. Gleiche Begruendung wie
    /// `laufend` im VorschauLader.
    private var laufend: [String: Task<URL?, Never>] = [:]

    init(ordner: URL = VideoAblage.standardOrdner, laden: @escaping Laden = VideoAblage.netz) {
        self.ordner = ordner
        self.laden = laden
        let gelesen = try? Data(contentsOf: ordner.appendingPathComponent("index.json"))
        self.index = gelesen.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
    }

    static var standardOrdner: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("uebungsvideos", isDirectory: true)
    }

    // Ephemeral aus demselben Grund wie im VorschauLader: eine Antwort im
    // URLCache traefe mit der naechsten Signatur nie wieder.
    static let netz: Laden = { url in
        guard let (daten, antwort) = try? await URLSession(configuration: .ephemeral).data(from: url),
              (antwort as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return daten
    }

    /// Die lokale Datei fuer die Uebung. Mit Quelle wird sie bei Bedarf
    /// geladen, ohne Quelle nur die zuletzt abgelegte gesucht.
    func datei(exerciseId: String, quelle: UebungsVideo?) async -> URL? {
        guard let quelle else {
            return index[exerciseId].map(ziel).flatMap(vorhanden)
        }
        let name = Self.dateiname(quelle.pfad)
        let datei: URL?
        if let fertig = vorhanden(ziel(name)) {
            datei = fertig
        } else if let download = laufend[name] {
            datei = await download.value
        } else {
            // Ohne await zwischen Anlegen und Eintragen: eine gleichzeitige
            // zweite Anfrage sieht den Download garantiert.
            let download = Task<URL?, Never> { [laden, ordner] in
                guard let daten = await laden(quelle.url) else { return nil }
                let ziel = ordner.appendingPathComponent(name)
                do {
                    try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
                    try daten.write(to: ziel, options: .atomic)
                    return ziel
                } catch {
                    return nil
                }
            }
            laufend[name] = download
            datei = await download.value
            laufend[name] = nil
        }
        if datei != nil, index[exerciseId] != name {
            index[exerciseId] = name
            speichereIndex()
        }
        return datei
    }

    private func ziel(_ name: String) -> URL {
        ordner.appendingPathComponent(name)
    }

    private func vorhanden(_ url: URL) -> URL? {
        FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func speichereIndex() {
        guard let daten = try? JSONEncoder().encode(index) else { return }
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        try? daten.write(to: ordner.appendingPathComponent("index.json"), options: .atomic)
    }

    /// Der Pfad enthaelt Schraegstriche und Studio-IDs -- als Dateiname
    /// taugt nur sein Hash.
    private static func dateiname(_ pfad: String) -> String {
        SHA256.hash(data: Data(pfad.utf8)).map { String(format: "%02x", $0) }.joined() + ".mp4"
    }
}
