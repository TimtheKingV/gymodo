import Foundation

/// Die reinen Ableitungen des Blocks "Deine Ziele" auf Home -- getrennt
/// vom View, damit sie ohne SwiftUI pruefbar bleiben (wie
/// `HomeSerie`/`HomeZeilen`).
///
/// **Kein BMI, kein Trend, keine Empfehlung.** Alles hier ist entweder ein
/// eingetragener Wert oder eine Differenz zwischen zwei eingetragenen
/// Werten -- nie eine Interpretation, welche Richtung "gesund" waere
/// (Spec Abschnitt 6, nicht-verhandelbare Regel 3).
enum HomeZiele {
    /// Die drei Kartenzustaende (Brief Entscheidung 1). Die Gewichtskarte
    /// erscheint erst mit mindestens einem Messwert -- ein gesetztes Ziel
    /// allein zeigt keine Karte mit Nullen (designsystem.md SS5).
    enum Zustand: Equatable {
        case nachholen
        /// Ein Ziel steht, aber noch kein Gewicht -- eine schmale Zeile
        /// statt einer Karte voller Nullen.
        case nurEintragen
        case karte(Gewichtskarte)
    }

    struct Gewichtskarte: Equatable {
        let wert: Double
        let datumText: String
        /// Seit dem ERSTEN je eingetragenen Messwert -- unabhaengig vom
        /// 12-Punkte-Fenster der Kurve, die nur die juengste Zeitspanne
        /// zeigt.
        let differenzText: String
        let seitText: String
        /// nil ohne aktives Zielgewicht.
        let abstandText: String?
        let zielText: String?
        let zielwert: Double?
        /// nil, solange kein Ziel erreicht wurde
        /// (`VerlaufStore.erreichtesZielgewicht`, Brief Entscheidung 2).
        let erreichtText: String?
        let kurve: [Double]
    }

    /// Der Zustand aus Bootstrap-Zielen, Messwerten und dem gemerkten
    /// "erreicht"-Stand. `zeitzone` statt eines `Calendar` (Ruling R26):
    /// der Messtag ist ein Ortstag des Mitglieds, und "heute" muss darum
    /// in der Geraetezeitzone gebaut werden, nicht ueber `Calendar.
    /// startOfDay` auf einen UTC-verankerten Zeitpunkt (siehe
    /// `HomeZeilen.tageHerVonTag`) -- Vorgabe `.current` fuer Aufrufer,
    /// Tests pinnen sie.
    static func zustand(
        member: BootstrapResponse.Member,
        messwerte: [Messwert],
        erreichtesZielgewicht: VerlaufStore.ErreichtesZielgewicht?,
        jetzt: Date,
        zeitzone: TimeZone = .current
    ) -> Zustand {
        guard let letzter = messwerte.last else {
            let hatZiel = member.goals.weeklyDays != nil || member.goals.targetWeight != nil
            return hatZiel ? .nurEintragen : .nachholen
        }

        let erster = messwerte.first ?? letzter
        let ziel = member.goals.targetWeight?.targetValue

        return .karte(Gewichtskarte(
            wert: letzter.weightKg,
            datumText: datumText(letzter.measuredOn, jetzt: jetzt, zeitzone: zeitzone),
            differenzText: differenzText(letzter.weightKg - erster.weightKg),
            seitText: "seit \(kurzesDatum(erster.measuredOn))",
            abstandText: abstandText(aktuell: letzter.weightKg, ziel: ziel),
            zielText: ziel.map { "bis \(Zahlformat.gewicht($0))" },
            zielwert: ziel,
            erreichtText: erreichtText(erreichtesZielgewicht),
            kurve: kurve(messwerte)))
    }

    /// Die letzten 12 Punkte fuer die Mini-Kurve -- weniger, wenn weniger
    /// da sind. Kein gleitender Durchschnitt, keine Glaettung: die Kurve
    /// zeigt eingetragene Punkte, keine Rechnung darueber (Spec 4.3).
    static func kurve(_ messwerte: [Messwert]) -> [Double] {
        messwerte.suffix(12).map(\.weightKg)
    }

    /// "−2,0 kg" / "+1,5 kg" / "±0,0 kg" -- U+2212 statt Bindestrich, weil
    /// ein ASCII-Minus sich lesend mit einem Trennstrich verwechseln
    /// laesst. Immer mit einer Nachkommastelle ueber `Zahlformat.gewicht`
    /// (designsystem.md SS3), auch bei null: "±0" allein wirkte neben
    /// "82,5 kg" wie ein Formatfehler statt wie "keine Veraenderung".
    static func differenzText(_ diffKg: Double) -> String {
        let gerundet = (diffKg * 10).rounded() / 10
        guard gerundet != 0 else { return "±\(Zahlformat.gewicht(0)) kg" }
        let vorzeichen = gerundet > 0 ? "+" : "\u{2212}"
        return "\(vorzeichen)\(Zahlformat.gewicht(abs(gerundet))) kg"
    }

    /// "noch 4,5 kg" -- der Abstand zum Zielgewicht, ohne Richtung: ob das
    /// Mitglied ab- oder zunehmen will, sagt sein Trainingsziel (die
    /// Eyebrow "Gewicht · Abnehmen"), nicht diese Zahl. Eine Rechnung,
    /// keine Bewertung (Spec Abschnitt 6).
    static func abstandText(aktuell: Double, ziel: Double?) -> String? {
        guard let ziel else { return nil }
        return "noch \(Zahlformat.gewicht(abs(aktuell - ziel))) kg"
    }

    /// "heute" / "gestern" / "vor 3 Tagen" -- ueber ein Ortsdatum
    /// (`Messwert.measuredOn`), nicht ueber einen Zeitstempel wie
    /// `HomeSerie.fussnote`. `HomeZeilen.tageHer` erwartet ein volles
    /// ISO8601-Datum mit Uhrzeit und scheitert an einem reinen Tag,
    /// deshalb der eigene Weg ueber `tageHerVonTag` -- der rechnet den
    /// Messtag gegen den ORTSTAG des Geraets in `zeitzone`, nicht gegen
    /// UTC (R26).
    static func datumText(_ measuredOn: String, jetzt: Date, zeitzone: TimeZone) -> String {
        guard let tage = HomeZeilen.tageHerVonTag(measuredOn, jetzt: jetzt, zeitzone: zeitzone)
        else { return "" }
        return HomeZeilen.tageHerText(tage)
    }

    /// "Zielgewicht erreicht · 78,0 kg am 3. November" -- siehe
    /// `VerlaufStore.ErreichtesZielgewicht` (Brief Entscheidung 2): der
    /// Wert lebt nur im Speicher, ein Neustart laesst diese Zeile wieder
    /// verschwinden. Das ist der bewusste Preis dafuer, keinen eigenen
    /// Endpoint "zuletzt erreichte Ziele" zu bauen, statt ihn ungefragt zu
    /// erfinden.
    static func erreichtText(_ erreicht: VerlaufStore.ErreichtesZielgewicht?) -> String? {
        guard let erreicht, let tag = tagFormatter.date(from: erreicht.measuredOn) else { return nil }
        return "Zielgewicht erreicht · \(Zahlformat.gewichtMitEinheit(erreicht.weightKg)) am \(Zahlformat.tagMonat(tag))"
    }

    // MARK: - Innereien

    /// "seit 1. Sept." -- unlesbar faellt auf den rohen Tag zurueck, wie
    /// `HomeSerie.tagestitel` bei einem kaputten Datum: lieber ein
    /// unschoener String als ein leerer.
    private static func kurzesDatum(_ tagId: String) -> String {
        guard let tag = tagFormatter.date(from: tagId) else { return tagId }
        return Zahlformat.tagMonatKurz(tag)
    }

    /// en_US_POSIX/UTC, wie `HomeSerie.datumsFormatter` -- ein Ortsdatum
    /// hat keine Zeitzone, der Formatierer darf trotzdem keine raten.
    private static let tagFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
