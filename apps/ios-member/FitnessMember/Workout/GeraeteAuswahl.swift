import Foundation

/// Liste und Suche der Stationen eines Orts -- der Weg zum Geraet, wenn
/// kein Aufkleber daran klebt. Stationen sind die Geraete des Studios oder,
/// in einem Studio ohne Geraete und im Freien Training, die Gymtavo-Typen.
///
/// Das Gegenstueck zu `MachineResolver`: der loest ein Geraet ueber den
/// Token auf, dieser ueber die Suche. Beide rechnen auf demselben
/// Prefetch und brauchen kein Netz.
///
/// Reines `enum` statt `@Observable`: es gibt kein Netz, keinen
/// Lebenszyklus und keinen Ladezustand -- dieselbe Aufteilung wie bei
/// `KurseWochenInhalt` und `GeraetEinstiegRechner`, damit die Regeln ohne
/// UI pruefbar sind.
enum GeraeteAuswahl {

    /// Der letzte Satz an diesem Geraet -- die Belastung mit ihrer
    /// Einheit, damit die Zeile "vor 2 Tagen · 8,5 km/h" schreiben kann.
    struct Zuletzt: Equatable {
        let performedAt: Date
        /// nil bei einem Cardio-Satz.
        let load: Double?
        let loadUnit: LoadUnit
        var cardio: CardioWerte? = nil

        /// Was hinter "vor 2 Tagen" steht: die Cardio-Werte oder die Belastung.
        var werte: String {
            if let cardio { return Zahlformat.cardio(cardio) }
            guard let load else { return "" }
            return Zahlformat.belastungMitEinheit(load, loadUnit)
        }
    }

    struct Eintrag: Equatable, Identifiable {
        var id: String { station.schluessel }
        let station: Station
        /// `equipmentModel.id` -- der Schluessel, unter dem der Server das
        /// Foto signiert.
        let modellId: String
        /// `equipmentModel.name` -- das Wort, das am Geraet steht.
        let name: String
        /// Nur fuer die Kacheln ohne Suchtext (Testnotiz 12.10., #3; vorher
        /// Kraft/Cardio nach Cardio-Spec 3.5). Die Suche an der Wurzel kennt
        /// sie nicht: wer "lauf" tippt, will das Laufband, egal unter
        /// welcher Kachel es sonst stuende.
        let gruppe: Geraetegruppe
        /// `label · locationNote`, dieselbe Fuegung wie die Kopfzeile auf
        /// dem Geraete-Screen. Am Typ der Hersteller (oder leer).
        let ortsangabe: String
        let zuletzt: Zuletzt?
        /// Gesetzt, wenn der Treffer NUR ueber eine Uebung kam. Bei einem
        /// Geraetetreffer erklaert die Zeile nichts und bleibt leer. Die
        /// ganze Uebung, nicht nur der Name: ein Tipp oeffnet genau sie
        /// (Testnotiz 14.10., 18:45 #2).
        let trefferUebung: BootstrapResponse.Exercise?
        /// `status != "active"`.
        let gesperrt: Bool
        /// `tokenHashes.isEmpty` -- also kein AKTIVER Tag. getBootstrap
        /// liest machine_tags mit status = active, ein abgeschalteter
        /// Aufkleber klebt also weiter am Geraet. Am Typ immer false: ein
        /// Typ ist kein Geraet ohne Sticker.
        let nichtScannbar: Bool
    }

    /// Eine Kachel (Testnotiz 12.10., #3): ihre Gruppe mit ALLEN Geraeten
    /// darin, alphabetisch -- auch denen, die oben unter "Zuletzt" stehen.
    /// Sie zaehlt und oeffnet ihre ganze Gruppe; fehlte das zuletzt
    /// benutzte Geraet darin, suchte man es genau dort vergeblich.
    struct Kachel: Equatable, Identifiable {
        var id: Geraetegruppe { gruppe }
        let gruppe: Geraetegruppe
        let eintraege: [Eintrag]
    }

    /// An der Wurzel ohne Suchtext: `zuletzt` und `kategorien`. In einer
    /// Kategorie ohne Suchtext: nur `liste`. Mit Suchtext: nur `treffer`,
    /// flach -- die anderen sind dann leer. Leere Teile zeigt die Ansicht
    /// nicht.
    struct Gruppen: Equatable {
        /// Hoechstens drei; nur an der Wurzel ohne Suche.
        let zuletzt: [Eintrag]
        /// Zuletzt benutzte zuerst (16.10., #2), unbenutzte in fester
        /// Reihenfolge; ohne leere Gruppen (#5).
        let kategorien: [Kachel]
        /// Die Geraete einer Kategorie, alphabetisch.
        let liste: [Eintrag]
        let treffer: [Eintrag]

        static let leer = Gruppen(zuletzt: [], kategorien: [], liste: [], treffer: [])

        var istLeer: Bool { zuletzt.isEmpty && kategorien.isEmpty && liste.isEmpty && treffer.isEmpty }
    }

    /// Wohin ein Tipp auf eine Kachel fuehrt (Rueckfrage D).
    enum Ziel: Equatable {
        /// Genau ein Geraet: gleich dessen Uebungen -- der Kabelzug (#3).
        case station(Station)
        /// Sonst die Liste der Gruppe -- Freihantel mit drei Hanteln (#4).
        case liste(Geraetegruppe)
    }

    /// So viele stehen unter "Zuletzt bei dir", der Rest hinter "Mehr
    /// anzeigen" (Testnotiz 17.10., #3). `Gruppen.zuletzt` traegt alle.
    static let zuletztSichtbar = 10

    /// Die Stationen des Orts (Spec 6): die Geraete des Studios; hat es
    /// keine, alle Katalogtypen mit der studioId des Studios; im Freien
    /// Training alle Katalogtypen ohne studioId. Ohne Katalog und ohne
    /// Geraete ist die Liste leer -- der Ruhezustand vor dem Bootstrap,
    /// kein Bug.
    static func stationen(bootstrap: BootstrapResponse, ort: Ort) -> [Station] {
        switch ort {
        case .studio(let studioId):
            let geraete = bootstrap.machines.filter { $0.studioId == studioId }
            if !geraete.isEmpty { return geraete.map(Station.init(maschine:)) }
            return typen(bootstrap, studioId: studioId)
        case .freiesTraining:
            return typen(bootstrap, studioId: nil)
        }
    }

    /// Ohne abgeloeste Typen (Testnotiz 12.10., #1): sie sind in einem
    /// anderen aufgegangen. `BootstrapResponse.station(schluessel:)` loest
    /// sie weiter auf, damit alte Bloecke und Saetze sich oeffnen lassen.
    private static func typen(_ bootstrap: BootstrapResponse, studioId: String?) -> [Station] {
        (bootstrap.catalog?.equipmentTypes ?? [])
            .filter { $0.retired != true }
            .map { Station(typ: $0, studioId: studioId) }
    }

    /// Ob die Suchberechnung warten soll (Offline-Spec 1b): nur wenn sich
    /// allein der Text geaendert hat und er nicht leer ist. Erster Durchlauf,
    /// Leeren und Aenderungen an Bootstrap, Ort oder Gruppe rechnen sofort.
    static func entprellt(textVorher: String?, textJetzt: String, restGleich: Bool) -> Bool {
        guard let textVorher, restGleich else { return false }
        return !textJetzt.isEmpty && textJetzt != textVorher
    }

    /// Ob `kopfinhalt` (im laufenden Training Uhr und Bloecke) ueber der
    /// Liste steht. Mit Suchtext nicht: sonst stehen die Treffer unter dem
    /// Training, und es sieht aus, als filtere die Suche nicht (Testnotiz
    /// 14.10., 18:45 #1).
    static func zeigtKopf(suchtext: String) -> Bool {
        normalisiert(suchtext).isEmpty
    }

    /// `gruppe` gesetzt: die Kategorieliste dieser Gruppe -- ohne Zuletzt
    /// und ohne Kacheln, und die Suche bleibt in der Gruppe.
    static func gruppen(
        bootstrap: BootstrapResponse,
        ort: Ort,
        suchtext: String,
        gruppe: Geraetegruppe? = nil
    ) -> Gruppen {
        let stationen = stationen(bootstrap: bootstrap, ort: ort)
            .filter { gruppe == nil || Geraetegruppe.fuer($0.equipmentModel) == gruppe }
        let maschinen = Dictionary(bootstrap.machines.map { ($0.id, $0) }, uniquingKeysWith: { erste, _ in erste })
        let besuche = maschinen.mapValues(\.visitCount)
        func notiz(_ station: Station) -> String? {
            station.machineId.flatMap { maschinen[$0]?.locationNote }
        }
        let letzteSaetze = juengsteSaetze(in: bootstrap, stationen: stationen)
        let gesucht = normalisiert(suchtext)

        func eintrag(_ station: Station, trefferUebung: BootstrapResponse.Exercise?) -> Eintrag {
            Eintrag(
                station: station,
                modellId: station.equipmentModel.id,
                name: station.equipmentModel.name,
                gruppe: Geraetegruppe.fuer(station.equipmentModel),
                ortsangabe: ortsangabe(station, notiz: notiz(station)),
                zuletzt: letzteSaetze[station.schluessel],
                trefferUebung: trefferUebung,
                gesperrt: station.gesperrt,
                nichtScannbar: station.machineId != nil && station.tokenHashes.isEmpty)
        }

        if gesucht.isEmpty, gruppe != nil {
            let liste = stationen
                .map { eintrag($0, trefferUebung: nil) }
                .sorted(by: alphabetischGesperrteAnsEnde)
            return Gruppen(zuletzt: [], kategorien: [], liste: liste, treffer: [])
        }

        guard !gesucht.isEmpty else {
            // Spec 5.1 nennt nur "visitCount > 0". Die zweite Bedingung ist
            // im echten Datenbestand wirkungslos -- bootstrap.ts leitet
            // visitCount und lastSets aus denselben Zeilen ab
            // (bootstrap.ts:153-158) -- AUSSER wenn ein performedAt sich
            // nicht parsen laesst: dann fehlt der Eintrag in letzteSaetze,
            // obwohl visitCount > 0 gilt. Genau das bewahrt die
            // Force-Unwraps in der naechsten Zeile davor abzustuerzen --
            // ohne diese Bedingung nicht "vereinfachen". Ein Typ hat keinen
            // visitCount: dort entscheidet allein der freie Satz.
            let benutzt = stationen
                .filter { station in
                    guard letzteSaetze[station.schluessel] != nil else { return false }
                    return station.machineId.map { (besuche[$0] ?? 0) > 0 } ?? true
                }
                .sorted { letzteSaetze[$0.schluessel]!.performedAt > letzteSaetze[$1.schluessel]!.performedAt }
            let alle = stationen
                .map { eintrag($0, trefferUebung: nil) }
                .sorted(by: alphabetischGesperrteAnsEnde)
            let kacheln = Geraetegruppe.allCases.compactMap { g -> Kachel? in
                let darin = alle.filter { $0.gruppe == g }
                return darin.isEmpty ? nil : Kachel(gruppe: g, eintraege: darin)
            }
            // Testnotiz 16.10., #2: zuletzt benutzte Kategorie vorn. Der
            // Sortierschluessel ist der juengste Satz darin; unbenutzte
            // behalten untereinander die feste Reihenfolge (stabil ueber
            // den Index, sorted ist es nicht).
            func juengster(_ kachel: Kachel) -> Date? {
                kachel.eintraege.compactMap { $0.zuletzt?.performedAt }.max()
            }
            let sortiert = kacheln.enumerated().sorted { a, b in
                switch (juengster(a.element), juengster(b.element)) {
                case let (x?, y?) where x != y: x > y
                case (_?, nil): true
                case (nil, _?): false
                default: a.offset < b.offset
                }
            }.map(\.element)

            return Gruppen(
                zuletzt: benutzt.map { eintrag($0, trefferUebung: nil) },
                kategorien: sortiert,
                liste: [],
                treffer: []
            )
        }

        let treffer = stationen.compactMap { station -> Eintrag? in
            let imGeraet = felder(station, notiz: notiz(station))
                .contains { normalisiert($0).contains(gesucht) }
            // Die Uebungszeile nur setzen, wenn das Geraet selbst NICHT
            // trifft -- sonst bekaeme bei "bein" auch die Beinpresse eine,
            // und die Zeile verloere ihren Zweck.
            let uebung = imGeraet ? nil : station.exercises.first {
                normalisiert($0.name).contains(gesucht)
            }
            guard imGeraet || uebung != nil else { return nil }
            return eintrag(station, trefferUebung: uebung)
        }

        return Gruppen(zuletzt: [], kategorien: [], liste: [], treffer: treffer.sorted(by: trefferReihenfolge))
    }

    // MARK: - Reihenfolgen

    private static func alphabetischGesperrteAnsEnde(_ a: Eintrag, _ b: Eintrag) -> Bool {
        if a.gesperrt != b.gesperrt { return !a.gesperrt }
        return a.name.localizedStandardCompare(b.name) == .orderedAscending
    }

    /// Blatt 03: Geraetetreffer vor Uebungstreffern, darin Geraete mit
    /// Historie zuerst, dann alphabetisch. Deshalb steht dort die
    /// Beinpresse vor dem Beinbeuger, obwohl B vor P kommt.
    private static func trefferReihenfolge(_ a: Eintrag, _ b: Eintrag) -> Bool {
        if a.gesperrt != b.gesperrt { return !a.gesperrt }
        let aNurUebung = a.trefferUebung != nil
        let bNurUebung = b.trefferUebung != nil
        if aNurUebung != bNurUebung { return !aNurUebung }
        if (a.zuletzt != nil) != (b.zuletzt != nil) { return a.zuletzt != nil }
        return a.name.localizedStandardCompare(b.name) == .orderedAscending
    }

    // MARK: - Bausteine

    /// `label · locationNote` am Geraet, der Hersteller am Typ. locationNote
    /// steht nur an der Machine, nicht an der Station.
    private static func ortsangabe(_ station: Station, notiz: String?) -> String {
        if station.machineId != nil {
            return [station.label, notiz].compactMap { $0 }.joined(separator: " · ")
        }
        return station.equipmentModel.manufacturer ?? ""
    }

    private static func felder(_ station: Station, notiz: String?) -> [String] {
        if station.machineId != nil {
            return [station.equipmentModel.name, station.label, notiz].compactMap { $0 }
        }
        return [station.equipmentModel.name, station.equipmentModel.manufacturer].compactMap { $0 }
    }

    /// Klein, ohne Diakritika, ohne Rand -- damit "RÜCKEN" und "rucken"
    /// dasselbe treffen.
    private static func normalisiert(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    /// Der juengste Satz je Station, unter ihrem Schluessel: am Geraet aus
    /// lastSets, am Typ aus lastTypeSets. Rechnet selbst, statt sich auf die
    /// Serversortierung zu verlassen -- dieselbe Vorsicht wie in
    /// `GeraetEinstiegRechner.letzteUebung`.
    private static func juengsteSaetze(in bootstrap: BootstrapResponse, stationen: [Station]) -> [String: Zuletzt] {
        var juengste: [String: Zuletzt] = [:]
        // Ohne die Station keine Einheit -- und ohne Einheit keine Zahl.
        // Zeigen koennte die Zeile sie ohnehin nicht.
        let einheiten = Dictionary(
            stationen.map { ($0.schluessel, $0.equipmentModel.loadUnit) },
            uniquingKeysWith: { erste, _ in erste })
        func merke(_ schluessel: String, load: Double?, cardio: CardioWerte?, performedAt: String) {
            // Weder Belastung noch Cardio-Werte: nichts, was die Zeile zeigen koennte.
            guard load != nil || cardio != nil else { return }
            guard let einheit = einheiten[schluessel] else { return }
            guard let datum = Zeitpunkt.parse(performedAt) else { return }
            if let vorhanden = juengste[schluessel], vorhanden.performedAt >= datum { return }
            juengste[schluessel] = Zuletzt(performedAt: datum, load: load, loadUnit: einheit, cardio: cardio)
        }
        for satz in bootstrap.lastSets {
            merke(Station.schluessel(machineId: satz.machineId),
                  load: satz.load, cardio: satz.cardio, performedAt: satz.performedAt)
        }
        for satz in bootstrap.lastTypeSets {
            merke(Station.schluessel(equipmentModelId: satz.equipmentModelId),
                  load: satz.load, cardio: satz.cardio, performedAt: satz.performedAt)
        }
        return juengste
    }
}

// MARK: - Kachel und Uebungszahl (Testnotiz 11.10., #2, #3)

extension GeraeteAuswahl {
    /// Die Uebung, deren Video die Kachel eines Geraets zeigt. Nur bei
    /// genau einer Uebung steht ihr Video fuer das ganze Geraet; bei
    /// mehreren bleibt es beim Foto, bis ein eigenes Geraetebild kommt.
    static func videoUebung(uebungsIds: [String]) -> String? {
        uebungsIds.count == 1 ? uebungsIds.first : nil
    }

    /// Die zweite Zeile unter dem Geraetenamen. Ohne Uebung gibt es nichts
    /// zu zaehlen -- eine "0 Übungen" saehe aus wie ein Fehler.
    static func uebungsanzahlText(_ anzahl: Int) -> String? {
        switch anzahl {
        case 0: nil
        case 1: "1 Übung"
        default: "\(anzahl) Übungen"
        }
    }
}

// MARK: - Kacheln (Testnotiz 12.10., #3, #4)

extension GeraeteAuswahl {
    /// Ein einzelnes gesperrtes Geraet oeffnet nichts -- dann zeigt die
    /// Liste wenigstens, warum.
    static func ziel(_ kachel: Kachel) -> Ziel {
        if kachel.eintraege.count == 1, let einziges = kachel.eintraege.first, !einziges.gesperrt {
            return .station(einziges.station)
        }
        return .liste(kachel.gruppe)
    }

    /// Die Zahl unter dem Kacheltitel: bei einem Geraet seine Uebungen --
    /// dorthin fuehrt der Tipp --, sonst die Geraete.
    static func kachelText(_ kachel: Kachel) -> String {
        if kachel.eintraege.count == 1, let einziges = kachel.eintraege.first {
            return uebungsanzahlText(einziges.station.exercises.count) ?? "1 Gerät"
        }
        return "\(kachel.eintraege.count) Geräte"
    }
}
