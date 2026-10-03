import Foundation

/// Liste und Suche der Geraete eines Studios -- der Weg zum Geraet, wenn
/// kein Aufkleber daran klebt.
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
        var id: String { machineId }
        let machineId: String
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
        /// dem Geraete-Screen.
        let ortsangabe: String
        let zuletzt: Zuletzt?
        /// Gesetzt, wenn der Treffer NUR ueber eine Uebung kam. Bei einem
        /// Geraetetreffer erklaert die Zeile nichts und bleibt leer.
        let trefferUebung: String?
        /// `status != "active"`.
        let gesperrt: Bool
        /// `tokenHashes.isEmpty` -- also kein AKTIVER Tag. getBootstrap
        /// liest machine_tags mit status = active, ein abgeschalteter
        /// Aufkleber klebt also weiter am Geraet.
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

    /// `studioId: nil` liefert bewusst leere Gruppen -- keine Maschine hat
    /// eine leere studioId, der Filter unten greift dann also nie. Das ist
    /// der Ruhezustand, bevor der Bootstrap geladen ist, kein Bug.
    static func gruppen(
        bootstrap: BootstrapResponse,
        studioId: String?,
        suchtext: String
    ) -> Gruppen {
        let maschinen = bootstrap.machines.filter { $0.studioId == studioId }
        let letzteSaetze = juengsteSaetze(in: bootstrap)
        let gesucht = normalisiert(suchtext)

        guard !gesucht.isEmpty else {
            // Spec 5.1 nennt nur "visitCount > 0". Die zweite Bedingung ist
            // im echten Datenbestand wirkungslos -- bootstrap.ts leitet
            // visitCount und lastSets aus denselben Zeilen ab
            // (bootstrap.ts:153-158) -- AUSSER wenn ein performedAt sich
            // nicht parsen laesst: dann fehlt der Eintrag in letzteSaetze,
            // obwohl visitCount > 0 gilt. Genau das bewahrt die
            // Force-Unwraps in der naechsten Zeile davor abzustuerzen --
            // ohne diese Bedingung nicht "vereinfachen".
            let benutzt = maschinen
                .filter { $0.visitCount > 0 && letzteSaetze[$0.id] != nil }
                .sorted { letzteSaetze[$0.id]!.performedAt > letzteSaetze[$1.id]!.performedAt }
                .prefix(deckel)
            let obenIds = Set(benutzt.map(\.id))
            // Was oben steht, steht unten nicht noch einmal.
            let unten = maschinen
                .filter { !obenIds.contains($0.id) }
                .map { eintrag($0, zuletzt: letzteSaetze[$0.id], trefferUebung: nil) }
                .sorted(by: alphabetischGesperrteAnsEnde)

            return Gruppen(
                zuletzt: benutzt.map { eintrag($0, zuletzt: letzteSaetze[$0.id], trefferUebung: nil) },
                kraft: unten.filter { $0.kategorie == .kraft },
                cardio: unten.filter { $0.kategorie == .cardio },
                treffer: []
            )
        }

        let treffer = maschinen.compactMap { maschine -> Eintrag? in
            let imGeraet = felder(maschine).contains { normalisiert($0).contains(gesucht) }
            // Die Uebungszeile nur setzen, wenn das Geraet selbst NICHT
            // trifft -- sonst bekaeme bei "bein" auch die Beinpresse eine,
            // und die Zeile verloere ihren Zweck.
            let uebung = imGeraet ? nil : maschine.exercises.first {
                normalisiert($0.name).contains(gesucht)
            }?.name
            guard imGeraet || uebung != nil else { return nil }
            return eintrag(maschine, zuletzt: letzteSaetze[maschine.id], trefferUebung: uebung)
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

    private static func eintrag(
        _ maschine: BootstrapResponse.Machine,
        zuletzt: Zuletzt?,
        trefferUebung: String?
    ) -> Eintrag {
        Eintrag(
            machineId: maschine.id,
            modellId: maschine.equipmentModel.id,
            name: maschine.equipmentModel.name,
            kategorie: maschine.equipmentModel.category,
            ortsangabe: [maschine.label, maschine.locationNote]
                .compactMap { $0 }
                .joined(separator: " · "),
            zuletzt: zuletzt,
            trefferUebung: trefferUebung,
            gesperrt: maschine.status != "active",
            nichtScannbar: maschine.tokenHashes.isEmpty
        )
    }

    private static func felder(_ maschine: BootstrapResponse.Machine) -> [String] {
        [maschine.equipmentModel.name, maschine.label, maschine.locationNote]
            .compactMap { $0 }
    }

    /// Klein, ohne Diakritika, ohne Rand -- damit "RÜCKEN" und "rucken"
    /// dasselbe treffen.
    private static func normalisiert(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    /// Der juengste Satz je Geraet. Rechnet selbst, statt sich auf die
    /// Serversortierung von `lastSets` zu verlassen -- dieselbe Vorsicht
    /// wie in `GeraetEinstiegRechner.letzteUebung`.
    private static func juengsteSaetze(in bootstrap: BootstrapResponse) -> [String: Zuletzt] {
        var juengste: [String: Zuletzt] = [:]
        let einheiten = Dictionary(
            bootstrap.machines.map { ($0.id, $0.equipmentModel.loadUnit) },
            uniquingKeysWith: { erste, _ in erste })
        for satz in bootstrap.lastSets {
            // Ohne das Geraet im Prefetch keine Einheit -- und ohne Einheit
            // keine Zahl. Zeigen koennte die Zeile das Geraet ohnehin nicht.
            guard let einheit = einheiten[satz.machineId] else { continue }
            guard let datum = Zeitpunkt.parse(satz.performedAt) else { continue }
            if let vorhanden = juengste[satz.machineId], vorhanden.performedAt >= datum { continue }
            juengste[satz.machineId] = Zuletzt(performedAt: datum, load: satz.load, loadUnit: einheit)
        }
        return juengste
    }
}
