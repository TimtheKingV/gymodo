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
        let load: Double
        let loadUnit: LoadUnit
    }

    struct Eintrag: Equatable, Identifiable {
        var id: String { station.schluessel }
        let station: Station
        /// `equipmentModel.id` -- der Schluessel, unter dem der Server das
        /// Foto signiert.
        let modellId: String
        /// `equipmentModel.name` -- das Wort, das am Geraet steht.
        let name: String
        /// Nur fuer die Gruppierung ohne Suchtext (Cardio-Spec 3.5). Die
        /// Suche selbst kennt sie nicht: wer "lauf" tippt, will das
        /// Laufband, egal unter welcher Ueberschrift es sonst stuende.
        let kategorie: Kategorie
        /// `label · locationNote`, dieselbe Fuegung wie die Kopfzeile auf
        /// dem Geraete-Screen. Am Typ der Hersteller (oder leer).
        let ortsangabe: String
        let zuletzt: Zuletzt?
        /// Gesetzt, wenn der Treffer NUR ueber eine Uebung kam. Bei einem
        /// Geraetetreffer erklaert die Zeile nichts und bleibt leer.
        let trefferUebung: String?
        /// `status != "active"`.
        let gesperrt: Bool
        /// `tokenHashes.isEmpty` -- also kein AKTIVER Tag. getBootstrap
        /// liest machine_tags mit status = active, ein abgeschalteter
        /// Aufkleber klebt also weiter am Geraet. Am Typ immer false: ein
        /// Typ ist kein Geraet ohne Sticker.
        let nichtScannbar: Bool
    }

    /// Ohne Suchtext: zuletzt, dann Kraft und Cardio je alphabetisch. Mit
    /// Suchtext: nur `treffer`, flach wie vor der Kategorie -- die drei
    /// anderen sind dann leer. Eine leere Gruppe zeigt die Ansicht nicht.
    struct Gruppen: Equatable {
        /// Hoechstens drei; bei aktiver Suche leer.
        let zuletzt: [Eintrag]
        let kraft: [Eintrag]
        let cardio: [Eintrag]
        let treffer: [Eintrag]

        static let leer = Gruppen(zuletzt: [], kraft: [], cardio: [], treffer: [])

        var istLeer: Bool { zuletzt.isEmpty && kraft.isEmpty && cardio.isEmpty && treffer.isEmpty }
    }

    /// Mehr, und die Gruppe verdraengt die Liste, die sie abkuerzen soll.
    private static let deckel = 3

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

    private static func typen(_ bootstrap: BootstrapResponse, studioId: String?) -> [Station] {
        (bootstrap.catalog?.equipmentTypes ?? []).map { Station(typ: $0, studioId: studioId) }
    }

    static func gruppen(
        bootstrap: BootstrapResponse,
        ort: Ort,
        suchtext: String
    ) -> Gruppen {
        let stationen = stationen(bootstrap: bootstrap, ort: ort)
        let maschinen = Dictionary(bootstrap.machines.map { ($0.id, $0) }, uniquingKeysWith: { erste, _ in erste })
        let besuche = maschinen.mapValues(\.visitCount)
        func notiz(_ station: Station) -> String? {
            station.machineId.flatMap { maschinen[$0]?.locationNote }
        }
        let letzteSaetze = juengsteSaetze(in: bootstrap, stationen: stationen)
        let gesucht = normalisiert(suchtext)

        func eintrag(_ station: Station, trefferUebung: String?) -> Eintrag {
            Eintrag(
                station: station,
                modellId: station.equipmentModel.id,
                name: station.equipmentModel.name,
                kategorie: station.equipmentModel.category,
                ortsangabe: ortsangabe(station, notiz: notiz(station)),
                zuletzt: letzteSaetze[station.schluessel],
                trefferUebung: trefferUebung,
                gesperrt: station.gesperrt,
                nichtScannbar: station.machineId != nil && station.tokenHashes.isEmpty)
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
                .prefix(deckel)
            let obenIds = Set(benutzt.map(\.schluessel))
            // Was oben steht, steht unten nicht noch einmal.
            let unten = stationen
                .filter { !obenIds.contains($0.schluessel) }
                .map { eintrag($0, trefferUebung: nil) }
                .sorted(by: alphabetischGesperrteAnsEnde)

            return Gruppen(
                zuletzt: benutzt.map { eintrag($0, trefferUebung: nil) },
                kraft: unten.filter { $0.kategorie == .kraft },
                cardio: unten.filter { $0.kategorie == .cardio },
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
            }?.name
            guard imGeraet || uebung != nil else { return nil }
            return eintrag(station, trefferUebung: uebung)
        }

        return Gruppen(zuletzt: [], kraft: [], cardio: [], treffer: treffer.sorted(by: trefferReihenfolge))
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
        func merke(_ schluessel: String, load: Double, performedAt: String) {
            guard let einheit = einheiten[schluessel] else { return }
            guard let datum = Zeitpunkt.parse(performedAt) else { return }
            if let vorhanden = juengste[schluessel], vorhanden.performedAt >= datum { return }
            juengste[schluessel] = Zuletzt(performedAt: datum, load: load, loadUnit: einheit)
        }
        for satz in bootstrap.lastSets {
            merke(Station.schluessel(machineId: satz.machineId, equipmentModelId: ""),
                  load: satz.load, performedAt: satz.performedAt)
        }
        for satz in bootstrap.lastTypeSets {
            merke(Station.schluessel(machineId: nil, equipmentModelId: satz.equipmentModelId),
                  load: satz.load, performedAt: satz.performedAt)
        }
        return juengste
    }
}
