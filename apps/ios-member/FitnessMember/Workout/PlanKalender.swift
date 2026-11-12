import Foundation

/// Wie ein Termin des Plan-Kalenders steht.
enum TerminZustand: Equatable {
    case geplant
    case erledigt
    /// `verschobenAuf`: Tag (startOfDay), auf dem die Einheit jetzt liegt; nil bei Cardio/Kurs.
    case verpasst(verschobenAuf: Date?)
}

/// Ein Eintrag des Plan-Kalenders.
enum PlanTermin: Equatable {
    case einheit(key: String, zustand: TerminZustand)
    case kurs(titel: String, beginn: Date, angemeldet: Bool, zustand: TerminZustand)
    case cardio(arten: [String], zustand: TerminZustand)

    var zustand: TerminZustand {
        switch self {
        case .einheit(_, let z), .kurs(_, _, _, let z), .cardio(_, let z): z
        }
    }
}

/// Legt die Folge der Einheiten auf die Kraft-Slots des Wochenrasters
/// (Spec 1.3): Vergangene Slots sind erledigt oder verpasst, eine verpasste
/// Einheit rueckt auf den naechsten Kraft-Slot, alle folgenden je einen
/// weiter. Die Folge ist kein Kalender -- es gibt keine Nachholschuld, nur
/// die Zuordnung zu Tagen verschiebt sich; nie zwei Einheiten an einem Tag.
/// Cardio bleibt auf seinen Slots, Kurse verschieben sich nie.
enum PlanKalender {
    /// Schluessel ist `startOfDay` des Tages; Tage ohne Termin fehlen, nur
    /// Tage aus `tage` kommen vor. Die Folge wird trotzdem lueckenlos ab
    /// `beginn` bis zum letzten Tag gerechnet, damit eine spaetere Woche
    /// dieselben Einheiten traegt wie beim Durchblaettern.
    ///
    /// Ohne `beginn` (alter Server) gibt es keine vergangenen Slots -- lieber
    /// keine Vergangenheit als ein falsches "verpasst". `trainiertAn` und
    /// `cardioErledigt` enthalten Tage als "yyyy-MM-dd". Die Cardio-Arten
    /// stehen im Profil; hier bleibt `arten` leer, der Aufrufer reicht sie nach.
    ///
    /// `verlaufAb`: ab diesem Tag ist `trainiertAn` vollstaendig (`verlaufAb(...)`).
    /// Davor ist ein Kraft- oder Cardio-Slot ohne Erledigtes neutral -- kein
    /// Termin statt eines falschen "verpasst" (der Verlauf ist gedeckelt). nil:
    /// kein Verlauf bekannt, dann ist kein vergangener Slot verpasst. `erledigt`
    /// kommt vollstaendig vom Server und gilt immer.
    ///
    /// `cardioGeladen`: die Tage, fuer die `cardioErledigt` geladen ist
    /// (`CardioChecksStore.geladen`). Ein vergangener Cardio-Slot ohne Haken
    /// ausserhalb davon ist neutral -- ungeladen ist nicht "verpasst".
    static func termine(
        tage: [Date], kalender: Calendar, raster: [Rasterplatz], einheiten: [String],
        naechsteEinheitKey: String?, erledigt: [ErledigteEinheit], trainiertAn: Set<String>,
        beginn: Date?, verlaufAb: Date?, heute: Date, kurse: [CourseWeekSession], cardioErledigt: Set<String>,
        cardioGeladen: [ClosedRange<String>], filter: PlanFilter
    ) -> [Date: [PlanTermin]] {
        let heuteStart = kalender.startOfDay(for: heute)
        let sichtbar = Set(tage.map { kalender.startOfDay(for: $0) })
        let kraftTage = Set(raster.filter { $0.art == .kraft }.map(\.tag))
        let cardioTage = Set(raster.filter { $0.art == .cardio }.map(\.tag))
        let beginnStart = beginn.map { kalender.startOfDay(for: $0) }
        let verlaufAbStart = verlaufAb.map { kalender.startOfDay(for: $0) }
        /// Darf ein vergangener Tag "verpasst" heissen?
        func verlaufBekannt(_ tag: Date) -> Bool { verlaufAbStart.map { tag >= $0 } ?? false }

        // Erledigte Einheiten je lokalem Tag, chronologisch.
        var erledigtJeTag: [Date: [String]] = [:]
        for eintrag in erledigt
            .compactMap({ e in Zeitpunkt.parse(e.startedAt).map { (zeit: $0, key: e.einheitKey) } })
            .sorted(by: { $0.zeit < $1.zeit }) {
            erledigtJeTag[kalender.startOfDay(for: eintrag.zeit), default: []].append(eintrag.key)
        }

        let einheitTermine = einheitenAufSlots(
            sichtbar: sichtbar, kalender: kalender, kraftTage: kraftTage, einheiten: einheiten,
            naechsteEinheitKey: naechsteEinheitKey, erledigtJeTag: erledigtJeTag,
            trainiertAn: trainiertAn, beginnStart: beginnStart, heuteStart: heuteStart,
            verlaufBekannt: verlaufBekannt)

        var ergebnis: [Date: [PlanTermin]] = [:]
        for start in sichtbar {
            let vergangen = start < heuteStart
            // Vor dem Plan (und ohne bekannten Beginn) gibt es keine vergangenen Slots.
            let hatSlots = !vergangen || beginnStart.map { start >= $0 } ?? false
            let schluessel = PlanWoche.tagesSchluessel(start, kalender)
            let iso = PlanWoche.isoWochentag(start, kalender)
            var liste: [PlanTermin] = []

            let kursTermine: [PlanTermin] = kurse
                .filter { $0.localDay == schluessel && $0.status != "cancelled" }
                .sorted { $0.startsAt < $1.startsAt }
                .map { k in
                    let beginnKurs = Zeitpunkt.parse(k.startsAt) ?? start
                    let angemeldet = k.ownStatus == "booked"
                    // Der Server meldet keine Teilnahme: ein gebuchter Kurs gilt
                    // mit Beginn als erledigt.
                    let zustand: TerminZustand = angemeldet && beginnKurs <= heute ? .erledigt : .geplant
                    return .kurs(titel: k.name, beginn: beginnKurs, angemeldet: angemeldet, zustand: zustand)
                }

            if filter == .kurse {
                liste = kursTermine
            } else {
                if filter == .alle || filter == .kraft, let termin = einheitTermine[start] {
                    liste.append(termin)
                }
                if filter == .alle || filter == .cardio, hatSlots, cardioTage.contains(iso) {
                    let erledigtCardio = cardioErledigt.contains(schluessel)
                    // Vor `verlaufAb` oder ausserhalb der geladenen Haken ist ein
                    // offener vergangener Slot neutral (kein Termin).
                    let cardioBekannt = cardioGeladen.contains { $0.contains(schluessel) }
                    if erledigtCardio || !vergangen || (verlaufBekannt(start) && cardioBekannt) {
                        let zustand: TerminZustand = erledigtCardio ? .erledigt
                            : vergangen ? .verpasst(verschobenAuf: nil) : .geplant
                        liste.append(.cardio(arten: [], zustand: zustand))
                    }
                }
                if filter == .alle {
                    // Nur gebuchte Kurse; ein Raster-Kurstag ohne Buchung bleibt leer
                    // (alte Wochen sind nicht geladen, "verpasst" waere falsch).
                    liste += kursTermine.filter { if case .kurs(_, _, true, _) = $0 { true } else { false } }
                }
            }
            if !liste.isEmpty { ergebnis[start] = liste }
        }
        return ergebnis
    }

    /// Wie viele Einheiten `GET /me/sessions` hoechstens liefert (`SESSION_LIMIT`
    /// in packages/domain/src/sessions.ts).
    static let verlaufDeckel = 50

    /// Ab welchem Tag der geladene Verlauf vollstaendig ist (`verlaufAb` in
    /// `termine`). Nie geladen (weder Netz noch Cache): nil. Vollstaendig:
    /// `beginn`. Gedeckelt (mehr Einheiten als geladen, oder ohne Gesamtzahl
    /// genau am Deckel): der Tag der aeltesten geladenen Einheit.
    static func verlaufAb(
        sessions: [SessionSummary], gesamt: Int?, geladen: Bool, beginn: Date?, kalender: Calendar
    ) -> Date? {
        guard geladen else { return nil }
        let gedeckelt = gesamt.map { $0 > sessions.count } ?? (sessions.count >= verlaufDeckel)
        guard gedeckelt else { return beginn }
        return sessions.compactMap { Zeitpunkt.parse($0.startedAt) }.min()
            .map { kalender.startOfDay(for: $0) }
    }

    /// Erster Termin ab heute (heute eingeschlossen) mit Zustand .geplant.
    static func naechster(
        _ termine: [Date: [PlanTermin]], ab heute: Date, kalender: Calendar
    ) -> (tag: Date, termin: PlanTermin)? {
        let start = kalender.startOfDay(for: heute)
        for tag in termine.keys.filter({ $0 >= start }).sorted() {
            if let termin = termine[tag]?.first(where: { $0.zustand == .geplant }) {
                return (tag: tag, termin: termin)
            }
        }
        return nil
    }

    // MARK: - Folge

    /// Die Einheiten-Termine aller Kraft-Slots von `beginn` (bzw. heute) bis
    /// zum letzten sichtbaren Tag.
    private static func einheitenAufSlots(
        sichtbar: Set<Date>, kalender: Calendar, kraftTage: Set<Int>, einheiten: [String],
        naechsteEinheitKey: String?, erledigtJeTag: [Date: [String]], trainiertAn: Set<String>,
        beginnStart: Date?, heuteStart: Date, verlaufBekannt: (Date) -> Bool
    ) -> [Date: PlanTermin] {
        let n = einheiten.count
        guard n > 0, !kraftTage.isEmpty, let letzter = sichtbar.max() else { return [:] }

        func istSlot(_ tag: Date) -> Bool { kraftTage.contains(PlanWoche.isoWochentag(tag, kalender)) }
        func weiter(_ tag: Date) -> Date {
            kalender.startOfDay(for: kalender.date(byAdding: .day, value: 1, to: tag) ?? tag.addingTimeInterval(86_400))
        }

        var ergebnis: [Date: PlanTermin] = [:]
        var verpasst: [(tag: Date, key: String)] = []
        // Zeiger in die Folge: rueckt je erledigter Einheit hinter diese.
        var p = 0

        /// Erledigtes eines Tages: setzt den Zeiger weiter, liefert den ersten Key.
        func erledigte(_ tag: Date) -> String? {
            let keys = erledigtJeTag[tag] ?? []
            for key in keys {
                if let index = einheiten.firstIndex(of: key) { p = index + 1 }
            }
            return keys.first
        }

        // Vergangenheit: nur ab Planbeginn.
        if let beginnStart {
            var tag = beginnStart
            while tag < heuteStart {
                let key = erledigte(tag)
                if istSlot(tag) {
                    if let key {
                        ergebnis[tag] = .einheit(key: key, zustand: .erledigt)
                    } else if verlaufBekannt(tag), !trainiertAn.contains(PlanWoche.tagesSchluessel(tag, kalender)) {
                        // Ein freies Training zaehlt den Tag als trainiert, die Einheit bleibt offen.
                        verpasst.append((tag: tag, key: einheiten[p % n]))
                    }
                }
                tag = weiter(tag)
            }
        }

        // Heute und kuenftig: die Folge ab der Server-Wahrheit.
        let heuteKey = erledigte(heuteStart)
        var index = naechsteEinheitKey.flatMap { einheiten.firstIndex(of: $0) } ?? p
        let vorn = einheiten[index % n]
        var tag = heuteStart
        while tag <= letzter {
            if istSlot(tag) {
                if tag == heuteStart, let heuteKey {
                    ergebnis[tag] = .einheit(key: heuteKey, zustand: .erledigt)
                } else {
                    ergebnis[tag] = .einheit(key: einheiten[index % n], zustand: .geplant)
                    index += 1
                }
            }
            tag = weiter(tag)
        }

        // Verschoben ist eine verpasste Einheit nur, solange sie vorn in der
        // Folge liegt und seither nicht erledigt wurde -- sonst nur "verpasst".
        let kuenftig = ergebnis.filter { $0.key >= heuteStart }.keys.sorted()
        for (verpassterTag, key) in verpasst {
            let seitherErledigt = erledigtJeTag.contains { $0.key > verpassterTag && $0.value.contains(key) }
            let ziel = key == vorn && !seitherErledigt
                ? kuenftig.first { ergebnis[$0] == .einheit(key: key, zustand: .geplant) }
                : nil
            ergebnis[verpassterTag] = .einheit(key: key, zustand: .verpasst(verschobenAuf: ziel))
        }
        return ergebnis
    }
}
