import Foundation

enum WochenPhase: Equatable { case vergangen, laufend, kuenftig }

/// `kursGebucht` = gebucht, noch nicht begonnen.
enum TagMarke: Equatable, Hashable { case kraft, cardio, kurs, kursGebucht }

struct WochenKarte: Equatable, Identifiable {
    /// `einheitKey` nil = freies Training.
    enum Art: Equatable { case kraft(einheitKey: String?), cardio, kurs(CourseWeekSession) }
    enum Quelle: Equatable { case sitzung(id: String), hand(checkId: String), keine }
    let id: String
    let art: Art
    /// nil = offen.
    let erledigtAm: Date?
    let quelle: Quelle
    /// Nur die erste offene Kraft-Karte der laufenden Woche.
    let istNaechste: Bool
    /// Trainingsdauer (ohne Pausen) bzw. Cardio-Minuten bzw. Kursdauer.
    let minuten: Int?
}

struct PlanWochenStand: Equatable {
    let phase: WochenPhase
    /// Kraft erledigt, Kraft offen, Cardio erledigt, Cardio offen, Kurse.
    let karten: [WochenKarte]
    /// Je `startOfDay`, sortiert kraft > kurs > kursGebucht > cardio.
    let marken: [Date: [TagMarke]]
    let kraftErledigt: Int
    let cardioErledigt: Int
}

/// Die Woche ohne feste Tage (Spec P2 §2 #1–#3, §3, §8): was geleistet ist, steht als
/// erledigte Karte am Tag, an dem es war; was zum Wochenziel fehlt, steht als offene
/// Karte ohne Tag. Kein "verpasst", kein Uebertrag -- Montag beginnt die Woche neu.
enum PlanWochenRechnung {
    static func berechne(
        wocheStart: Date, heute: Date, kalender: Calendar, ziel: Wochenziel,
        einheiten: [String], naechsteEinheitKey: String?,
        sitzungen: [SessionSummary], erledigt: [ErledigteEinheit],
        cardioChecks: [CardioCheck], kurse: [CourseWeekSession], filter: PlanFilter
    ) -> PlanWochenStand {
        let anfang = kalender.startOfDay(for: wocheStart)
        let ende = kalender.date(byAdding: .day, value: 7, to: anfang) ?? anfang.addingTimeInterval(7 * 86_400)
        let inWoche = { (d: Date) in d >= anfang && d < ende }
        let phase: WochenPhase = heute < anfang ? .kuenftig : heute >= ende ? .vergangen : .laufend

        // Beendete Sitzungen der Woche, aelteste zuerst. Die Woche entscheidet der
        // Beginn im Studio-Kalender (So 23:30 alt, Mo 00:30 neu).
        let beendet: [(sitzung: SessionSummary, start: Date, ende: Date)] = sitzungen.compactMap { s in
            guard let ende = s.completedAt.flatMap(Zeitpunkt.parse),
                  let start = Zeitpunkt.parse(s.startedAt), inWoche(start) else { return nil }
            return (s, start, ende)
        }.sorted { $0.start < $1.start }
        let planKey = Dictionary(erledigt.map { ($0.sessionId, $0.einheitKey) }, uniquingKeysWith: { a, _ in a })

        var kraftKarten: [WochenKarte] = []
        var cardioErledigtKarten: [WochenKarte] = []
        for (s, start, ende) in beendet {
            let saetze = s.blocks.flatMap(\.sets)
            let key = planKey[s.id]
            if key != nil || saetze.contains(where: { $0.cardio == nil }) {
                let sekunden = max(0, ende.timeIntervalSince(start) - Double(s.pausedSeconds ?? 0))
                kraftKarten.append(WochenKarte(
                    id: "kraft-\(s.id)", art: .kraft(einheitKey: key), erledigtAm: start,
                    quelle: .sitzung(id: s.id), istNaechste: false, minuten: Int((sekunden / 60).rounded())))
            }
            // Summe nur innerhalb dieser einen Sitzung; hoechstens ein Haken je Sitzung.
            let cardioSekunden = saetze.reduce(0) { $0 + ($1.cardio?.zeit ?? 0) }
            if cardioSekunden > 0, cardioSekunden >= ziel.cardioMinuten * 60 {
                cardioErledigtKarten.append(WochenKarte(
                    id: "cardio-\(s.id)", art: .cardio, erledigtAm: start, quelle: .sitzung(id: s.id),
                    istNaechste: false, minuten: Int((Double(cardioSekunden) / 60).rounded())))
            }
        }
        for check in cardioChecks {
            guard let tag = ortsdatum(check.day, kalender), inWoche(tag) else { continue }
            cardioErledigtKarten.append(WochenKarte(
                id: "cardio-hand-\(check.id)", art: .cardio, erledigtAm: tag, quelle: .hand(checkId: check.id),
                istNaechste: false, minuten: check.minuten))
        }
        // Stabil nach Datum: bei gleichem Zeitpunkt bleibt die Eingangsreihenfolge.
        cardioErledigtKarten = cardioErledigtKarten.enumerated()
            .sorted { ($0.element.erledigtAm ?? .distantPast, $0.offset) < ($1.element.erledigtAm ?? .distantPast, $1.offset) }
            .map(\.element)

        let kraftErledigt = kraftKarten.count
        let cardioErledigt = cardioErledigtKarten.count

        var kraftOffen: [WochenKarte] = []
        var cardioOffen: [WochenKarte] = []
        if phase == .laufend {
            if !einheiten.isEmpty {
                let i = naechsteEinheitKey.flatMap { einheiten.firstIndex(of: $0) } ?? 0
                kraftOffen = (0..<max(0, ziel.kraft - kraftErledigt)).map { k in
                    WochenKarte(
                        id: "kraft-offen-\(k)", art: .kraft(einheitKey: einheiten[(i + k) % einheiten.count]),
                        erledigtAm: nil, quelle: .keine, istNaechste: k == 0, minuten: nil)
                }
            }
            cardioOffen = (0..<max(0, ziel.cardio - cardioErledigt)).map { k in
                WochenKarte(id: "cardio-offen-\(k)", art: .cardio, erledigtAm: nil, quelle: .keine,
                            istNaechste: false, minuten: ziel.cardioMinuten)
            }
        }

        // Kurse: nur eigene Buchungen, nicht vom Studio abgesagt; Warteliste zaehlt nicht.
        let kursKarten: [WochenKarte] = kurse.compactMap { kurs -> (WochenKarte, Date)? in
            guard kurs.ownStatus == "booked", kurs.status != "cancelled",
                  let start = Zeitpunkt.parse(kurs.startsAt), inWoche(start) else { return nil }
            let karte = WochenKarte(
                id: "kurs-\(kurs.sessionId)", art: .kurs(kurs), erledigtAm: heute >= start ? start : nil,
                quelle: .keine, istNaechste: false, minuten: kurs.durationMin)
            return (karte, start)
        }.sorted { $0.1 < $1.1 }.map(\.0)

        var karten: [WochenKarte] = phase == .kuenftig
            ? kursKarten
            : kraftKarten + kraftOffen + cardioErledigtKarten + cardioOffen + kursKarten
        karten = karten.filter { zeigt($0.art, filter) }

        var marken: [Date: Set<TagMarke>] = [:]
        for karte in karten {
            let marke: TagMarke
            let tag: Date
            switch karte.art {
            case .kraft, .cardio:
                guard let am = karte.erledigtAm else { continue }
                marke = karte.art == .cardio ? .cardio : .kraft
                tag = am
            case .kurs(let kurs):
                guard let start = Zeitpunkt.parse(kurs.startsAt) else { continue }
                marke = karte.erledigtAm == nil ? .kursGebucht : .kurs
                tag = start
            }
            marken[kalender.startOfDay(for: tag), default: []].insert(marke)
        }
        let rang: [TagMarke] = [.kraft, .kurs, .kursGebucht, .cardio]

        return PlanWochenStand(
            phase: phase, karten: karten,
            marken: marken.mapValues { m in rang.filter(m.contains) },
            kraftErledigt: kraftErledigt, cardioErledigt: cardioErledigt)
    }

    /// `.einheiten` ist der Kraft-Filter (Umbenennung folgt mit dem Plan-Tab).
    private static func zeigt(_ art: WochenKarte.Art, _ filter: PlanFilter) -> Bool {
        switch (filter, art) {
        case (.alle, _), (.einheiten, .kraft), (.cardio, .cardio), (.kurse, .kurs): true
        default: false
        }
    }

    /// "YYYY-MM-DD" als Tagesbeginn im `kalender`.
    private static func ortsdatum(_ text: String, _ kalender: Calendar) -> Date? {
        let teile = text.split(separator: "-").compactMap { Int($0) }
        guard teile.count == 3 else { return nil }
        return kalender.date(from: DateComponents(year: teile[0], month: teile[1], day: teile[2]))
            .map { kalender.startOfDay(for: $0) }
    }
}
