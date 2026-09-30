import Foundation

/// Zahlen so, wie designsystem.md SS3 sie festlegt.
///
/// Kilogramm tragen **immer** eine Nachkommastelle: ein Wechsel von 80 auf
/// 82,5 wirkte sonst wie ein Formatfehler statt wie eine Steigerung. Das
/// gilt fuer das Koerpergewicht (gewicht...) wie fuer die Trainingsbelastung
/// in kg; wie viele Stellen die anderen Einheiten tragen, sagt
/// LoadUnit.nachkommastellen (Belastung.swift).
///
/// Das Gebietsschema ist fest auf Deutsch gesetzt, nicht `.current` -- das
/// Dezimalkomma ist hier eine Designentscheidung, kein Systemdetail.
enum Zahlformat {
    private static let gebietsschema = Locale(identifier: "de_DE")

    private static let gewichtFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = gebietsschema
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    /// `en_US_POSIX`, nicht `gebietsschema` (de_DE): bei einem fest
    /// vorgegebenen `dateFormat` ist das die kanonische Wahl -- ein
    /// regionsgebundenes Gebietsschema kann ein "HH"-Muster unter der
    /// Nutzereinstellung "24-Stunden-Zeit aus" umbiegen, `en_US_POSIX` nie.
    private static let uhrzeitFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// Fuer den "Stand: ..."-Satz: geraetelokal und in de_DE, weil er
    /// sagt, wann DIESES Geraet die Zahlen zuletzt geholt hat -- ein
    /// Abrufzeitpunkt gehoert dem Geraet, anders als ein Kurstermin, der
    /// dem Studio gehoert (KursZeit).
    private static let standFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = gebietsschema
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func gewicht(_ kg: Double) -> String {
        gewichtFormatter.string(from: NSNumber(value: kg)) ?? "0,0"
    }

    /// "18:04" -- die Studio-Zeitzone spielt hier keine Rolle, weil die
    /// Einheit auf diesem Geraet lief.
    static func uhrzeit(_ zeitpunkt: Date) -> String {
        uhrzeitFormatter.string(from: zeitpunkt)
    }

    /// "8. Sept. 2026, 17:12" -- der Zeitpunkt eines Abrufs, wie ihn alle
    /// drei Kurse-Screens im "Stand: ..."-Satz zeigen. Eine Stelle statt
    /// drei Formatierern: derselbe Zustand darf nicht je nach Screen
    /// anders aussehen.
    static func stand(_ zeitpunkt: Date) -> String {
        standFormatter.string(from: zeitpunkt)
    }

    static func gewichtMitEinheit(_ kg: Double) -> String {
        "\(gewicht(kg)) kg"
    }

    /// UTC statt `gebietsschema`s Geraetezeitzone: der Aufrufer speist hier
    /// immer einen aus einem reinen Ortsdatum ("yyyy-MM-dd", Messwert.
    /// measuredOn) gebauten Zeitpunkt ein, und der darf beim Formatieren
    /// nicht noch einmal durch eine Zeitzone wandern (Aufgabe 8, dieselbe
    /// Festlegung wie bei HomeSerie.tagesFormatter).
    private static let tagMonatFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = gebietsschema
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "d. MMMM"
        return formatter
    }()

    private static let tagMonatKurzFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = gebietsschema
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "d. MMM"
        return formatter
    }()

    /// "3. November" -- Tag und Monat ohne Wochentag und ohne Jahr, fuer
    /// die Zeile "Zielgewicht erreicht ... am 3. November": der Moment
    /// liegt hoechstens ein paar Wochen zurueck, ein Jahr waere dort
    /// Rauschen (dieselbe Begruendung wie bei `wochentagDatum`).
    static func tagMonat(_ zeitpunkt: Date) -> String {
        tagMonatFormatter.string(from: zeitpunkt)
    }

    /// "1. Sept." -- dieselbe Angabe verkuerzt, fuer die kleine, blasse
    /// "seit ..."-Zeile unter der Gewichtsdifferenz: der ausgeschriebene
    /// Monat waere dort breiter als der Wert, den er begleitet.
    static func tagMonatKurz(_ zeitpunkt: Date) -> String {
        tagMonatKurzFormatter.string(from: zeitpunkt)
    }

    /// "Donnerstag, 27. August" -- die Zeile ueber einer Einheit im
    /// Verlauf. Ohne Jahr: der Verlauf reicht 50 Einheiten zurueck, und
    /// eine Jahreszahl an jeder Zeile waere Rauschen.
    static func wochentagDatum(_ zeitpunkt: Date) -> String {
        let formatierer = DateFormatter()
        formatierer.locale = gebietsschema
        formatierer.setLocalizedDateFormatFromTemplate("EEEEddMMMM")
        return formatierer.string(from: zeitpunkt)
    }

    /// "Do, 27. August" -- dieselbe Angabe als Titel des Session-Details,
    /// wo daneben noch der Zeitraum steht.
    static func kurzerWochentagDatum(_ zeitpunkt: Date) -> String {
        let formatierer = DateFormatter()
        formatierer.locale = gebietsschema
        formatierer.setLocalizedDateFormatFromTemplate("EEEddMMMM")
        return formatierer.string(from: zeitpunkt)
    }

    /// Eine einzige Zeichenkette -- sonst liest VoiceOver "achtzig, Komma,
    /// null, k, g" als vier Elemente (designsystem.md SS12).
    static func gewichtGesprochen(_ kg: Double) -> String {
        "\(gewicht(kg)) Kilogramm"
    }

    static func wiederholungenGesprochen(_ reps: Int) -> String {
        reps == 1 ? "1 Wiederholung" : "\(reps) Wiederholungen"
    }

    // MARK: - Trainingsbelastung und Umfang (Spiegel von belastung.ts)

    /// Ohne Tausenderpunkt wie `gewichtFormatter`: eine Belastung ueber
    /// 999 gibt es an keinem Geraet, und das Rad soll nie umbrechen.
    private static let ganzzahlFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = gebietsschema
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    /// Mit Tausenderpunkt: "2000" liest sich auf einem Rad als Jahreszahl,
    /// "2.000" als Strecke.
    private static let gruppiertFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = gebietsschema
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    /// Hoechstens eine Nachkommastelle, keine erzwungene: "2 Kilometer",
    /// aber "2,5 Kilometer" -- nur fuer die gesprochene Strecke.
    private static let kilometerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = gebietsschema
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    private static func ganzzahl(_ wert: Double) -> String {
        ganzzahlFormatter.string(from: NSNumber(value: wert)) ?? "0"
    }

    private static func gruppiert(_ wert: Int) -> String {
        gruppiertFormatter.string(from: NSNumber(value: wert)) ?? "0"
    }

    /// "80,0", "120", "8,5" -- die nackte Zahl fuer das Rad; die Einheit
    /// steht dort als eigenes Wort daneben (LoadUnit.kurz).
    static func belastung(_ wert: Double, _ einheit: LoadUnit) -> String {
        einheit.nachkommastellen == 0 ? ganzzahl(wert) : gewicht(wert)
    }

    /// "80,0 kg", "120 W", "Level 8", "8,5 km/h", "6,0 %", "85 U/min" --
    /// wie formatLoad in belastung.ts.
    static func belastungMitEinheit(_ wert: Double, _ einheit: LoadUnit) -> String {
        let zahl = belastung(wert, einheit)
        // "Level" steht als einzige Einheit vor der Zahl: so steht es auf
        // der Anzeige des Geraets.
        return einheit == .level ? "\(einheit.kurz) \(zahl)" : "\(zahl) \(einheit.kurz)"
    }

    /// "+2,5 kg", "−10 W", "+1 Level". Das Vorzeichen steht immer, auch
    /// bei null: der Abschluss zeigt eine Rechnung, keine Empfehlung
    /// (formatLoadDelta). Das Minus ist U+2212 wie an jeder anderen
    /// Differenz der App, nicht das Bindestrich-Minus aus belastung.ts.
    static func belastungDelta(_ delta: Double, _ einheit: LoadUnit) -> String {
        let vorzeichen = delta < 0 ? "−" : "+"
        // "Level 8" ist eine Stufe, "+1 Level" eine Aenderung um eine
        // Stufe -- hier steht das Wort deshalb hinter der Zahl.
        return "\(vorzeichen)\(belastung(abs(delta), einheit)) \(einheit.kurz)"
    }

    /// Eine einzige Zeichenkette mit ausgeschriebener Einheit, aus
    /// demselben Grund wie gewichtGesprochen: "km/h" liest VoiceOver sonst
    /// als "k, m, Schraegstrich, h".
    static func belastungGesprochen(_ wert: Double, _ einheit: LoadUnit) -> String {
        let zahl = belastung(wert, einheit)
        return switch einheit {
        case .kg: "\(zahl) Kilogramm"
        case .watt: "\(zahl) Watt"
        case .level: "Level \(zahl)"
        case .kmh: "\(zahl) Kilometer pro Stunde"
        case .pct: "\(zahl) Prozent"
        case .rpm: "\(zahl) Umdrehungen pro Minute"
        }
    }

    /// "12", "20:00", "2.000" -- die Anzeige auf dem Umfangsrad. Der
    /// gespeicherte Wert bleibt die ganze Zahl (Sekunden, Meter).
    static func umfang(_ wert: Int, _ art: VolumeKind) -> String {
        switch art {
        case .reps: gruppiert(wert)
        // Minuten laufen ueber 59 hinaus ("90:00") statt auf Stunden zu
        // kippen wie verstrichen(seit:bis:): das Rad endet bei 90 Minuten,
        // und die Geraeteanzeige, von der das Mitglied abliest, zaehlt
        // ebenfalls in Minuten.
        case .seconds: String(format: "%d:%02d", wert / 60, wert % 60)
        case .meters: gruppiert(wert)
        }
    }

    /// "12 Wdh.", "20:00 min", "2.000 m" -- wie formatVolume.
    static func umfangMitEinheit(_ wert: Int, _ art: VolumeKind) -> String {
        "\(umfang(wert, art)) \(art.kurz)"
    }

    /// "12 Wiederholungen", "20 Minuten", "2 Kilometer" -- "20:00" liest
    /// VoiceOver sonst als Uhrzeit (designsystem.md SS12).
    static func umfangGesprochen(_ wert: Int, _ art: VolumeKind) -> String {
        switch art {
        case .reps:
            return wiederholungenGesprochen(wert)
        case .seconds:
            let minuten = wert / 60
            let sekunden = wert % 60
            let minutenteil = minuten == 1 ? "1 Minute" : "\(minuten) Minuten"
            let sekundenteil = sekunden == 1 ? "1 Sekunde" : "\(sekunden) Sekunden"
            if minuten == 0 { return sekundenteil }
            return sekunden == 0 ? minutenteil : "\(minutenteil) \(sekundenteil)"
        case .meters:
            guard wert >= 1000 else { return wert == 1 ? "1 Meter" : "\(wert) Meter" }
            let kilometer = kilometerFormatter.string(from: NSNumber(value: Double(wert) / 1000)) ?? "0"
            return "\(kilometer) Kilometer"
        }
    }

    /// "8 – 12", "15 – 20 min", "2.000 – 5.000 m" -- der Korridor der
    /// Uebung. Minuten ohne Sekunden: ein Korridor ist eine Vorgabe, keine
    /// Stoppuhr (formatVolumeRange). Wiederholungen ohne Wort, wie der
    /// Geraete-Screen sie bisher nannte ("Ziel 8 – 12").
    static func korridor(_ min: Int, _ max: Int, _ art: VolumeKind) -> String {
        switch art {
        case .reps:
            "\(gruppiert(min)) – \(gruppiert(max))"
        case .seconds:
            "\(gruppiert(Int((Double(min) / 60).rounded()))) – \(gruppiert(Int((Double(max) / 60).rounded()))) \(art.kurz)"
        case .meters:
            "\(gruppiert(min)) – \(gruppiert(max)) \(art.kurz)"
        }
    }

    /// "23:41", ab einer Stunde "1:20:14" -- sonst kippt die Lesart: "80:14"
    /// liest sich nicht mehr eindeutig als Minuten:Sekunden, und eine
    /// Trainingseinheit darf bis zu vier Stunden laufen
    /// (WorkoutSessionStore.sessionPause).
    static func verstrichen(seit start: Date, bis jetzt: Date) -> String {
        let sekunden = max(0, Int(jetzt.timeIntervalSince(start)))
        let stunden = sekunden / 3600
        let minuten = (sekunden % 3600) / 60
        let rest = sekunden % 60
        guard stunden > 0 else { return String(format: "%02d:%02d", minuten, rest) }
        return String(format: "%d:%02d:%02d", stunden, minuten, rest)
    }

    /// "23 Minuten trainiert" / "1 Stunde 20 Minuten trainiert" -- die
    /// gesprochene Gegenstelle zu verstrichen(seit:bis:): sonst liest
    /// VoiceOver "23:41" mit hoher Wahrscheinlichkeit als Uhrzeit
    /// (designsystem.md SS12, wie gewichtGesprochen).
    static func verstrichenGesprochen(seit start: Date, bis jetzt: Date) -> String {
        let minuten = max(0, Int(jetzt.timeIntervalSince(start) / 60))
        let stunden = minuten / 60
        let restminuten = minuten % 60
        guard stunden > 0 else {
            return minuten == 1 ? "1 Minute trainiert" : "\(minuten) Minuten trainiert"
        }
        let stundenteil = stunden == 1 ? "1 Stunde" : "\(stunden) Stunden"
        let minutenteil = restminuten == 1 ? "1 Minute" : "\(restminuten) Minuten"
        return "\(stundenteil) \(minutenteil) trainiert"
    }
}
