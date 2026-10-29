import SwiftUI

/// Wohin Home im Plan-Tab springt (Leinwand 2d): die Woche, eine Einheit oder
/// ein Tag (Cardio, gebuchter Kurs).
enum PlanSprung: Equatable {
    case woche
    case einheit(key: String)
    /// `startOfDay` des Tages im Studio-Kalender.
    case tag(Date)
}

/// Ein Feld der Woche auf Home: ISO-Wochentag (1 = Montag), was dort steht
/// (nil = nichts), das kurze Zeichen ("A", "K"; Cardio zeigt ein Symbol).
struct HomeWochenfeld: Equatable, Identifiable {
    let tag: Int
    let art: Wochenart?
    let einheitKey: String?
    let label: String
    let istHeute: Bool
    let erledigt: Bool

    var id: Int { tag }
}

/// "Als nächstes" unter der Woche.
struct HomeNaechster: Equatable {
    let titel: String
    /// "Fr"
    let tag: String
    /// "Freitag"
    let sprechTag: String
    let ziel: PlanSprung
}

/// Reine Darstellungslogik der Woche auf Home. Wie `PlanWoche` rechnet sie am
/// Plan nichts um: das Raster kommt fertig (`PlanTabZustand.anzeigeRaster`),
/// hier wird nur den sieben Tagen zugeordnet.
enum HomeWoche {
    static let kurznamen = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    static let langnamen = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]

    /// Sieben Felder Mo–So. Steht an einem Tag mehr als eins (ein gebuchter
    /// Kurs auf einem Krafttag), zeigt das Feld die Art in der Reihenfolge des
    /// Servers: Kraft vor Kurs vor Cardio. `erledigt` sind ISO-Wochentage; ein
    /// Tag ohne Termin ist nie erledigt.
    static func zeilen(raster: [Rasterplatz], erledigt: Set<Int>, heute: Date, kalender: Calendar) -> [HomeWochenfeld] {
        let heuteIso = isoWochentag(heute, kalender)
        return (1...7).map { tag in
            let platz = hauptplatz(raster, tag: tag)
            return HomeWochenfeld(
                tag: tag, art: platz?.art, einheitKey: platz?.einheitKey,
                label: platz.map(label) ?? "", istHeute: tag == heuteIso,
                erledigt: platz != nil && erledigt.contains(tag))
        }
    }

    /// Die erledigten Tage der laufenden Woche, je nach Art des Feldes:
    /// Kurs = eigene Anmeldung, deren Beginn vorbei ist (eine Teilnahme meldet
    /// der Server nicht; eine kuenftige Anmeldung ist noch nicht erledigt),
    /// Cardio = Haken (`cardio_checks`), Kraft = nie -- Einheiten haben keine
    /// Erledigt-Quelle (Ruling, wie `einheitenErledigt` im Plan-Tab).
    static func erledigteTage(
        raster: [Rasterplatz], kurse: [CourseWeekSession], cardioErledigt: Set<String>,
        heute: Date, kalender: Calendar
    ) -> Set<Int> {
        var ergebnis: Set<Int> = []
        for tag in 1...7 {
            guard let platz = hauptplatz(raster, tag: tag),
                  let datum = datum(tag: tag, woche: heute, kalender: kalender) else { continue }
            let schluessel = tagesSchluessel(datum, kalender)
            switch platz.art {
            case .kraft:
                continue
            case .kurs:
                let besucht = gebucht(kurse, schluessel: schluessel).contains {
                    (Zeitpunkt.parse($0.startsAt) ?? .distantFuture) <= heute
                }
                if besucht { ergebnis.insert(tag) }
            case .cardio:
                if cardioErledigt.contains(schluessel) { ergebnis.insert(tag) }
            }
        }
        return ergebnis
    }

    /// Gebuchte Kurse sind immer sichtbar, auch an Tagen, die im Raster keinen
    /// Kurs tragen (wie im Plan-Tab): diese Tage bekommen einen Kursplatz.
    static func mitGebuchtenKursen(
        raster: [Rasterplatz], kurse: [CourseWeekSession], heute: Date, kalender: Calendar
    ) -> [Rasterplatz] {
        var ergebnis = raster
        for tag in 1...7 where !raster.contains(where: { $0.tag == tag && $0.art == .kurs }) {
            guard let datum = datum(tag: tag, woche: heute, kalender: kalender),
                  !gebucht(kurse, schluessel: tagesSchluessel(datum, kalender)).isEmpty else { continue }
            ergebnis.append(Rasterplatz(tag: tag, art: .kurs, einheitKey: nil))
        }
        return ergebnis
    }

    /// "1 von 4 Terminen erledigt"
    static func zusammenfassung(_ felder: [HomeWochenfeld]) -> String {
        let termine = felder.filter { $0.art != nil }
        guard !termine.isEmpty else { return "Diese Woche ist nichts geplant" }
        let erledigt = termine.filter(\.erledigt).count
        return "\(erledigt) von \(termine.count) \(termine.count == 1 ? "Termin" : "Terminen") erledigt"
    }

    /// "K Kurs" -- das K ist das einzige Zeichen, das sich nicht selbst erklaert.
    static func legende(_ felder: [HomeWochenfeld]) -> String? {
        felder.contains { $0.art == .kurs } ? "K Kurs" : nil
    }

    /// "Mittwoch, heute, Einheit A"
    static func sprechtext(_ feld: HomeWochenfeld) -> String {
        var teile = [langnamen[feld.tag - 1]]
        if feld.istHeute { teile.append("heute") }
        switch feld.art {
        case .kraft: teile.append(feld.einheitKey.map(EinheitName.text) ?? "Einheit")
        case .kurs: teile.append("Kurs")
        case .cardio: teile.append("Cardio")
        case nil: teile.append("nichts geplant")
        }
        if feld.erledigt { teile.append("erledigt") }
        return teile.joined(separator: ", ")
    }

    /// Der erste Termin NACH heute, ueber diese und die naechste Woche --
    /// dieselbe Zuordnung wie der Plan-Tab (`PlanWoche.termine`), damit Home
    /// und Plan dasselbe "als naechstes" nennen.
    static func alsNaechstes(
        raster: [Rasterplatz], kurse: [CourseWeekSession], cardioErledigt: Set<String>,
        heute: Date, kalender: Calendar
    ) -> HomeNaechster? {
        guard let montag = datum(tag: 1, woche: heute, kalender: kalender) else { return nil }
        let tage = (0..<14).compactMap { kalender.date(byAdding: .day, value: $0, to: montag) }
        let termine = PlanWoche.termine(
            tage: tage, kalender: kalender, raster: raster, kurse: kurse,
            cardioErledigt: cardioErledigt, einheitenErledigt: [], filter: .alle)
        guard let naechster = PlanTabZustand.alsNaechstes(
            termine: termine, nach: kalender.startOfDay(for: heute), anzahl: 1).first else { return nil }
        let iso = isoWochentag(naechster.tag, kalender)
        let (titel, ziel): (String, PlanSprung) = switch naechster.termin {
        case .einheit(let key, _): (EinheitName.text(key), .einheit(key: key))
        case .kurs(let name, _, _): (name, .tag(naechster.tag))
        case .cardio: ("Cardio", .tag(naechster.tag))
        }
        return HomeNaechster(titel: titel, tag: kurznamen[iso - 1], sprechTag: langnamen[iso - 1], ziel: ziel)
    }

    // MARK: - Hilfen

    private static let rang: [Wochenart: Int] = [.kraft: 0, .kurs: 1, .cardio: 2]

    private static func hauptplatz(_ raster: [Rasterplatz], tag: Int) -> Rasterplatz? {
        raster.filter { $0.tag == tag }.min { (rang[$0.art] ?? 0) < (rang[$1.art] ?? 0) }
    }

    private static func label(_ platz: Rasterplatz) -> String {
        switch platz.art {
        case .kraft: EinheitKuerzel.text(platz.einheitKey ?? "")
        case .kurs: "K"
        case .cardio: ""
        }
    }

    private static func gebucht(_ kurse: [CourseWeekSession], schluessel: String) -> [CourseWeekSession] {
        kurse.filter { $0.localDay == schluessel && $0.ownStatus == "booked" && $0.status != "cancelled" }
    }

    /// Das Datum des ISO-Wochentags `tag` in der Woche von `woche`.
    private static func datum(tag: Int, woche: Date, kalender: Calendar) -> Date? {
        let start = kalender.startOfDay(for: woche)
        return kalender.date(byAdding: .day, value: tag - isoWochentag(start, kalender), to: start)
    }

    private static func isoWochentag(_ tag: Date, _ kalender: Calendar) -> Int {
        // Calendar.weekday: 1 = Sonntag ... 7 = Samstag.
        (kalender.component(.weekday, from: tag) + 5) % 7 + 1
    }

    private static func tagesSchluessel(_ tag: Date, _ kalender: Calendar) -> String {
        let c = kalender.dateComponents([.year, .month, .day], from: tag)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

// MARK: - Karten

/// "DIESE WOCHE" auf Home (Leinwand 2d): sieben Felder und der Stand. Die
/// ganze Karte fuehrt in den Plan-Tab -- die Woche selbst wird dort verwaltet.
///
/// Heute steht im Akzent als Umriss, nicht als Flaeche: Home hat seine eine
/// Akzentflaeche schon (designsystem.md SS2).
struct HomeWocheKarte: View {
    let felder: [HomeWochenfeld]
    let beiTippen: () -> Void

    var body: some View {
        let zusammenfassung = HomeWoche.zusammenfassung(felder)
        let fuss = [zusammenfassung, HomeWoche.legende(felder)].compactMap { $0 }.joined(separator: " · ")
        Button(action: beiTippen) {
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("DIESE WOCHE")
                            .font(DesignSystem.Typography.label)
                            .tracking(1.5)
                            .foregroundStyle(DesignSystem.Color.textMuted)
                        Spacer()
                        HStack(spacing: DesignSystem.Spacing.s4) {
                            Text("Zum Plan")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.accent)
                    }
                    HStack(spacing: DesignSystem.Spacing.s4) {
                        ForEach(felder) { feld in
                            spalte(feld).frame(maxWidth: .infinity)
                        }
                    }
                    Text(fuss)
                        .font(.system(size: 13))
                        .monospacedDigit()
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s16)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Diese Woche, \(zusammenfassung). " + felder.map(HomeWoche.sprechtext).joined(separator: ". "))
        .accessibilityHint("Öffnet den Plan")
        .accessibilityAddTraits(.isButton)
        .testnotizElement("home.woche", typ: "Button")
    }

    private func spalte(_ feld: HomeWochenfeld) -> some View {
        VStack(spacing: 6) {
            Text(HomeWoche.kurznamen[feld.tag - 1])
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(feld.istHeute ? DesignSystem.Color.text : DesignSystem.Color.textMuted)
            zeichen(feld)
                .frame(width: 36, height: 36)
                .background(feld.erledigt ? DesignSystem.Color.accentMuted : .clear)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
                .overlay {
                    if feld.art != nil, !feld.erledigt {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                            .strokeBorder(
                                feld.istHeute ? DesignSystem.Color.accent : DesignSystem.Color.textFaint,
                                lineWidth: feld.istHeute ? 2 : 1)
                    }
                }
        }
    }

    @ViewBuilder
    private func zeichen(_ feld: HomeWochenfeld) -> some View {
        let farbe = feld.erledigt || feld.istHeute ? DesignSystem.Color.accent : DesignSystem.Color.textMuted
        switch feld.art {
        case .cardio:
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(farbe)
        case .kraft, .kurs:
            Text(feld.label)
                .font(.system(size: 15, weight: .black))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(farbe)
        case nil:
            Color.clear
        }
    }
}

/// "ALS NÄCHSTES" unter der Woche: der naechste Termin nach heute. Fuehrt zur
/// Einheit bzw. zum Tag im Plan-Tab.
struct HomeNaechsterKarte: View {
    let naechster: HomeNaechster
    let beiTippen: () -> Void

    var body: some View {
        Button(action: beiTippen) {
            Card {
                HStack(spacing: DesignSystem.Spacing.s12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ALS NÄCHSTES")
                            .font(DesignSystem.Typography.label)
                            .tracking(1.5)
                            .foregroundStyle(DesignSystem.Color.textMuted)
                        Text(naechster.titel)
                            .font(DesignSystem.Typography.uebungsname)
                            .foregroundStyle(DesignSystem.Color.text)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(naechster.tag)
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(DesignSystem.Color.text)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s16)
                .frame(minHeight: 44)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Als nächstes: \(naechster.titel), \(naechster.sprechTag)")
        .accessibilityHint(hinweis)
        .accessibilityAddTraits(.isButton)
        .testnotizElement("home.alsNaechstes", typ: "Button")
    }

    private var hinweis: String {
        switch naechster.ziel {
        case .woche: "Öffnet den Plan"
        case .einheit: "Öffnet die Einheit im Plan"
        case .tag: "Öffnet den Tag im Plan"
        }
    }
}

#Preview {
    var kalender = Calendar(identifier: .gregorian)
    kalender.locale = Locale(identifier: "de_DE")
    let raster = [
        Rasterplatz(tag: 1, art: .kurs, einheitKey: nil),
        Rasterplatz(tag: 3, art: .kraft, einheitKey: "A"),
        Rasterplatz(tag: 5, art: .kraft, einheitKey: "B"),
        Rasterplatz(tag: 7, art: .cardio, einheitKey: nil),
    ]
    let mittwoch = kalender.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 10))!
    return VStack(spacing: 16) {
        HomeWocheKarte(
            felder: HomeWoche.zeilen(raster: raster, erledigt: [1], heute: mittwoch, kalender: kalender),
            beiTippen: {})
        HomeNaechsterKarte(
            naechster: HomeNaechster(titel: "Einheit B", tag: "Fr", sprechTag: "Freitag", ziel: .einheit(key: "B")),
            beiTippen: {})
    }
    .padding(20)
    .background(DesignSystem.Color.bg)
}
