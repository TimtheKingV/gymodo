#if DEBUG
import Foundation

/// Ein Sitzungsordner auf der Platte. Actor, weil Bilder und Audio nicht auf
/// dem Main Thread geschrieben werden sollen und zwei schnelle Eintraege
/// sonst dieselbe Nummer bekaemen.
actor TestnotizAblage {
    nonisolated let ordner: URL
    private(set) var sitzung: TestnotizSitzung
    private let zeitzone: TimeZone

    /// Legt `wurzel/<yyyy-MM-dd-HHmm>` an. Existiert der Name schon (zwei
    /// Sitzungen in derselben Minute), bekommt der neue ein "-2", "-3" ...
    init(wurzel: URL, kopf: TestnotizSitzung.Kopf, zeitzone: TimeZone = .current) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: wurzel, withIntermediateDirectories: true)
        let basis = Zeitformat.ordnername(kopf.startedAt, zeitzone: zeitzone)
        var name = basis
        var zaehler = 2
        while fm.fileExists(atPath: wurzel.appendingPathComponent(name).path) {
            name = "\(basis)-\(zaehler)"
            zaehler += 1
        }
        let ordner = wurzel.appendingPathComponent(name)
        try fm.createDirectory(at: ordner, withIntermediateDirectories: false)

        var kopf = kopf
        kopf.id = name
        let sitzung = TestnotizSitzung(session: kopf, entries: [])
        try Self.sitzungSchreiben(sitzung, nach: ordner, zeitzone: zeitzone)
        self.ordner = ordner
        self.sitzung = sitzung
        self.zeitzone = zeitzone
    }

    var anzahl: Int { sitzung.entries.count }

    /// Vergibt Nummer und Dateinamen, schreibt die Dateien und danach
    /// sitzung.json und sitzung.md neu.
    func schreiben(_ eintrag: TestnotizEintrag, voll: Data, ausschnitt: Data?) throws -> TestnotizEintrag {
        var e = eintrag
        e.index = sitzung.entries.count + 1
        let praefix = String(format: "%02d", e.index)

        e.screenshot = "\(praefix)-voll.png"
        try voll.write(to: ordner.appendingPathComponent(e.screenshot))

        if let ausschnitt {
            let name = "\(praefix)-ausschnitt.png"
            try ausschnitt.write(to: ordner.appendingPathComponent(name))
            e.crop = name
        } else {
            e.crop = nil
        }
        // Sprachnotizen entfielen wieder -- audio/transcript bleiben Teil des
        // Formatvertrags (docs/superpowers/specs/2026-09-14-testnotiz-format.md),
        // stehen fuer iOS aber immer null.
        e.audio = nil

        sitzung.entries.append(e)
        try Self.sitzungSchreiben(sitzung, nach: ordner, zeitzone: zeitzone)
        return e
    }

    /// Zip ohne Fremdbibliothek: NSFileCoordinator packt einen Ordner beim
    /// Lesen mit .forUploading.
    func zipFuerTeilen() throws -> URL {
        let fm = FileManager.default
        let ziel = fm.temporaryDirectory.appendingPathComponent("\(ordner.lastPathComponent).zip")
        try? fm.removeItem(at: ziel)
        var koordinationsfehler: NSError?
        var kopierfehler: Error?
        NSFileCoordinator().coordinate(readingItemAt: ordner, options: .forUploading, error: &koordinationsfehler) { zip in
            do { try fm.copyItem(at: zip, to: ziel) } catch { kopierfehler = error }
        }
        if let koordinationsfehler { throw koordinationsfehler }
        if let kopierfehler { throw kopierfehler }
        return ziel
    }

    private static func sitzungSchreiben(_ sitzung: TestnotizSitzung, nach ordner: URL, zeitzone: TimeZone) throws {
        let json = try JSONEncoder.testnotiz(zeitzone: zeitzone).encode(sitzung)
        try json.write(to: ordner.appendingPathComponent("sitzung.json"), options: .atomic)
        let md = TestnotizMarkdown.rendern(sitzung, zeitzone: zeitzone)
        try Data(md.utf8).write(to: ordner.appendingPathComponent("sitzung.md"), options: .atomic)
    }
}
#endif
