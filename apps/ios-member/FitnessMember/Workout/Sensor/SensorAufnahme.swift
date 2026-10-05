#if DEBUG
import Foundation

/// Ein Aufnahme-Ordner auf der Platte (Spec 6). Kennt kein Bluetooth: bekommt
/// Messwerte und schreibt sie weg. Keine Nebenlaeufigkeit -- der Koordinator
/// ruft vom MainActor, und 100 Zeilen zu 70 Byte je Sekunde sind fuer einen
/// offenen FileHandle keine Last.
final class SensorAufnahme {
    enum Fehler: Error { case abgeschlossen }

    static let csvKopf = "t,ax,ay,az,gx,gy,gz,wx,wy,wz"

    let ordner: URL
    private(set) var datei: SensorAufnahmeDatei
    let startT: TimeInterval
    private let zeitzone: TimeZone
    private var griff: FileHandle?
    private var lueckeSeit: TimeInterval?
    private var zeilenSeitSync = 0

    init(wurzel: URL, start: Date, startT: TimeInterval, sensor: SensorAufnahmeDatei.Sensor,
         geraet: SensorAufnahmeDatei.Geraet, kontext: SensorAufnahmeDatei.Kontext,
         befestigung: String?, zeitzone: TimeZone = .current) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: wurzel, withIntermediateDirectories: true)
        let basis = Zeitformat.ordnername(start, zeitzone: zeitzone)
        var nummer = 1
        var ordner = wurzel.appendingPathComponent(String(format: "%@-%02d", basis, nummer))
        while fm.fileExists(atPath: ordner.path) {
            nummer += 1
            ordner = wurzel.appendingPathComponent(String(format: "%@-%02d", basis, nummer))
        }
        try fm.createDirectory(at: ordner, withIntermediateDirectories: false)

        let csv = ordner.appendingPathComponent("messwerte.csv")
        try Data((Self.csvKopf + "\n").utf8).write(to: csv)
        griff = try FileHandle(forWritingTo: csv)
        try griff?.seekToEnd()

        self.ordner = ordner
        self.startT = startT
        self.zeitzone = zeitzone
        datei = SensorAufnahmeDatei(
            format: SensorAufnahmeDatei.formatkennung, startedAt: start, endedAt: nil,
            sensor: sensor, geraet: geraet, kontext: kontext, label: .init(),
            befestigung: befestigung, statistik: .leer, abschluss: .laeuft)
        try kopfSchreiben()
    }

    deinit { try? griff?.close() }

    func schreiben(_ messwert: SensorMesswert) throws {
        try anhaengen(Self.zeile(messwert, startT: startT))
    }

    func lueckeBeginnt(t: TimeInterval) {
        if lueckeSeit == nil { lueckeSeit = t }
    }

    func lueckeEndet(t: TimeInterval) throws {
        guard let von = lueckeSeit else { return }
        lueckeSeit = nil
        try anhaengen("# luecke \(Self.zahl(von - startT, stellen: 6))-\(Self.zahl(t - startT, stellen: 6))")
    }

    /// Ab `t` sendet der Sensor mit `rate`. `rateSollHz` in aufnahme.json
    /// bleibt die Rate vom Start; ohne diese Zeile laege ein Wechsel mitten
    /// im Satz unsichtbar in den Daten.
    func rateGewechselt(_ rate: SensorRate, t: TimeInterval) throws {
        try anhaengen("# rate \(rate.rawValue) ab \(Self.zahl(t - startT, stellen: 6))")
    }

    func abschliessen(_ abschluss: SensorAufnahmeDatei.Abschluss, kontext: SensorAufnahmeDatei.Kontext,
                      label: SensorAufnahmeDatei.Label, akkuProzent: Int?,
                      statistik: SensorStatistik.Ergebnis, ende: Date, endeT: TimeInterval) throws {
        // Ein abgeschlossener Datensatz ist die Wahrheit fuer den spaeteren
        // Zaehler und darf durch einen zweiten Aufruf nicht ueberschrieben werden.
        guard griff != nil else { throw Fehler.abgeschlossen }
        // Eine offene Luecke reicht bis zum Ende: der Sensor kam nicht wieder.
        try lueckeEndet(t: endeT)
        try griff?.synchronize()
        try griff?.close()
        griff = nil
        datei.abschluss = abschluss
        datei.kontext = kontext
        datei.label = label
        datei.sensor.akkuProzent = akkuProzent ?? datei.sensor.akkuProzent
        datei.statistik = statistik
        datei.endedAt = ende
        try kopfSchreiben()
    }

    static func zeile(_ m: SensorMesswert, startT: TimeInterval) -> String {
        [zahl(m.t - startT, stellen: 6),
         zahl(m.beschleunigung.x, stellen: 4), zahl(m.beschleunigung.y, stellen: 4), zahl(m.beschleunigung.z, stellen: 4),
         zahl(m.drehrate.x, stellen: 2), zahl(m.drehrate.y, stellen: 2), zahl(m.drehrate.z, stellen: 2),
         zahl(m.winkel.x, stellen: 2), zahl(m.winkel.y, stellen: 2), zahl(m.winkel.z, stellen: 2)]
            .joined(separator: ",")
    }

    /// Punkt als Dezimaltrenner, egal welches Gebietsschema das Telefon hat:
    /// ein Komma in einer CSV mit Komma als Spaltentrenner zerlegt die Zeile.
    private static let posix = Locale(identifier: "en_US_POSIX")
    private static func zahl(_ wert: Double, stellen: Int) -> String {
        let text = String(format: "%.\(stellen)f", locale: posix, wert)
        // "-0.00" ist fuer einen Leser dieselbe Zahl, aber ein anderer Text.
        return text.allSatisfy({ "-0.".contains($0) }) && text.hasPrefix("-") ? String(text.dropFirst()) : text
    }

    private func anhaengen(_ zeile: String) throws {
        guard let griff else { throw Fehler.abgeschlossen }
        try griff.write(contentsOf: Data((zeile + "\n").utf8))
        zeilenSeitSync += 1
        // Einmal je Sekunde bei 50 Hz: nach einem Absturz fehlt hoechstens
        // das letzte Stueck (Spec 6.2).
        if zeilenSeitSync >= 50 {
            try griff.synchronize()
            zeilenSeitSync = 0
        }
    }

    private func kopfSchreiben() throws {
        let json = try JSONEncoder.testnotiz(zeitzone: zeitzone).encode(datei)
        try json.write(to: ordner.appendingPathComponent("aufnahme.json"), options: .atomic)
    }

    /// Beim App-Start: Ordner, die noch "laeuft" sagen, stammen aus einem
    /// Lauf, den es nicht mehr gibt. Ohne Nachtrag saehe B eine Aufnahme ohne
    /// Ende und muesste raten, ob sie vollstaendig ist.
    static func verwaisteNachtragen(wurzel: URL, zeitzone: TimeZone = .current) {
        let fm = FileManager.default
        guard let ordnerListe = try? fm.contentsOfDirectory(at: wurzel, includingPropertiesForKeys: nil) else { return }
        for ordner in ordnerListe {
            let kopf = ordner.appendingPathComponent("aufnahme.json")
            guard let daten = try? Data(contentsOf: kopf),
                  var datei = try? JSONDecoder.testnotiz().decode(SensorAufnahmeDatei.self, from: daten),
                  datei.abschluss == .laeuft
            else { continue }
            let csv = (try? String(contentsOf: ordner.appendingPathComponent("messwerte.csv"), encoding: .utf8)) ?? ""
            let letzteT = csv.split(separator: "\n")
                .last { !$0.hasPrefix("#") && !$0.hasPrefix("t,") }
                .flatMap { $0.split(separator: ",").first }
                .flatMap { Double($0) } ?? 0
            datei.abschluss = .abgebrochen
            datei.endedAt = datei.startedAt.addingTimeInterval(letzteT.rounded(.down))
            if let json = try? JSONEncoder.testnotiz(zeitzone: zeitzone).encode(datei) {
                try? json.write(to: kopf, options: .atomic)
            }
        }
    }
}
#endif
