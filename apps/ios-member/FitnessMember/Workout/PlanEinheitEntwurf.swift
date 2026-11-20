import Foundation

/// Art einer Entwurfsposition: Kraft (mit Typ "mehrgelenk" | "isolation") oder Cardio.
enum EntwurfsArt: Equatable {
    case kraft(typ: String)
    case cardio

    var istCardio: Bool { self == .cardio }
}

/// Welche Werte einer Position vom Ausgang abweichen (gruene Chips, P4).
enum WertFeld: Hashable {
    case saetze, wdh, pause, dauer
}

/// Eine Position im Entwurf. `id` ist nur lokal (stabil beim Ziehen), `key` der Schluessel
/// aus dem Plan; nil heisst neu (P4, Testnotiz 10.11.).
struct EntwurfsPosition: Equatable, Identifiable {
    let id: UUID
    var key: String?
    var exerciseId: String
    var modelId: String
    var art: EntwurfsArt
    var saetze: Int
    var wdhVon: Int?
    var wdhBis: Int?
    var pauseSek: Int
    var dauerMin: Int?
    var aufwaermsatz: Bool
    /// Name der alten Uebung fuer "statt X".
    var ersetzt: String?
    /// true: Art gewechselt oder neu, aber ohne Vorgaben (alter Server). Die Werte sind
    /// unbekannt, rumpf laesst sie weg und der Server fuellt sie.
    var werteOffen: Bool = false

    var neu: Bool { key == nil }
}

/// Eine Position im PUT-Rumpf (`ErsetzenPosition`). Fehlende Werte heissen: behalten bzw.
/// Server-Vorgabe. Nie Werte der falschen Art senden (Server antwortet 422).
struct ErsetzenPosition: Encodable, Equatable {
    var key: String?
    var exerciseId: String
    var modelId: String
    var saetze: Int?
    var wdhVon: Int?
    var wdhBis: Int?
    var pauseSek: Int?
    var dauerMin: Int?

    private enum CodingKeys: String, CodingKey {
        case key, exerciseId, modelId, saetze, wdhVon, wdhBis, pauseSek, dauerMin
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        // key ist Pflicht und darf null sein (neue Position).
        if let key { try c.encode(key, forKey: .key) } else { try c.encodeNil(forKey: .key) }
        try c.encode(exerciseId, forKey: .exerciseId)
        try c.encode(modelId, forKey: .modelId)
        try c.encodeIfPresent(saetze, forKey: .saetze)
        try c.encodeIfPresent(wdhVon, forKey: .wdhVon)
        try c.encodeIfPresent(wdhBis, forKey: .wdhBis)
        try c.encodeIfPresent(pauseSek, forKey: .pauseSek)
        try c.encodeIfPresent(dauerMin, forKey: .dauerMin)
    }
}

/// Arbeitsstand beim Bearbeiten einer ganzen Planeinheit: Reihenfolge, Entfernen,
/// Hinzufuegen, Tauschen und Werte. Gespeichert wird in einem Aufruf
/// (`APIClient.ersetzePlanEinheit`). Die Regeln spiegeln
/// packages/domain/src/plan-einheit-ersetzen.ts (P4, Testnotiz 10.11.).
struct PlanEinheitEntwurf: Equatable {
    private var ausgang: [EntwurfsPosition]
    private let vorgaben: PlanVorgaben?
    private let merkmale: [String: PlanUebungsMerkmal]
    private(set) var positionen: [EntwurfsPosition]

    init(einheit: TrainingsplanEinheit, vorgaben: PlanVorgaben?, merkmale: [String: PlanUebungsMerkmal]) {
        let start = einheit.positionen.map(Self.entwurfsposition)
        self.ausgang = start
        self.positionen = start
        self.vorgaben = vorgaben
        self.merkmale = merkmale
    }

    private static func entwurfsposition(_ p: TrainingsplanPosition) -> EntwurfsPosition {
        EntwurfsPosition(
            id: UUID(), key: p.key, exerciseId: p.exerciseId, modelId: p.modelId,
            art: p.baustein == "cardio" ? .cardio : .kraft(typ: p.typ),
            saetze: p.saetze, wdhVon: p.wdhVon, wdhBis: p.wdhBis, pauseSek: p.pauseSek,
            dauerMin: p.dauerMin, aufwaermsatz: p.aufwaermsatz)
    }

    /// E7: Solange an genau dieser Einheit eine Session haengt, bleibt sie, wie sie ist.
    static func darfBearbeiten(einheitKey: String, laufEinheitKey: String?, gebunden: Bool) -> Bool {
        !(gebunden && laufEinheitKey == einheitKey)
    }

    /// Ohne id und ersetzt-Name: nur was der Server sieht.
    private struct Stand: Equatable {
        let key: String?, exerciseId: String, modelId: String
        let saetze: Int, wdhVon: Int?, wdhBis: Int?, pauseSek: Int, dauerMin: Int?
    }

    private static func stand(_ p: EntwurfsPosition) -> Stand {
        Stand(key: p.key, exerciseId: p.exerciseId, modelId: p.modelId, saetze: p.saetze,
              wdhVon: p.wdhVon, wdhBis: p.wdhBis, pauseSek: p.pauseSek, dauerMin: p.dauerMin)
    }

    var geaendert: Bool { positionen.map(Self.stand) != ausgang.map(Self.stand) }
    var darfEntfernen: Bool { positionen.count > 1 }

    /// Semantik wie `Array.move(fromOffsets:toOffset:)`.
    mutating func verschieben(von: IndexSet, nach: Int) {
        let gueltig = IndexSet(von.filter { positionen.indices.contains($0) })
        guard !gueltig.isEmpty else { return }
        positionen.move(fromOffsets: gueltig, toOffset: nach)
    }

    /// `false` und unveraendert, wenn danach nichts bliebe oder die id fehlt.
    @discardableResult
    mutating func entfernen(id: UUID) -> Bool {
        guard positionen.count > 1, let i = positionen.firstIndex(where: { $0.id == id }) else { return false }
        positionen.remove(at: i)
        return true
    }

    private func ausVorgaben(cardio: Bool, typ: String, vorgaben v: PlanVorgaben) -> (
        saetze: Int, wdhVon: Int?, wdhBis: Int?, pauseSek: Int, dauerMin: Int?, aufwaermsatz: Bool
    ) {
        if cardio { return (1, nil, nil, 0, v.cardioMin, false) }
        let t = typ == "mehrgelenk" ? v.mehrgelenk : v.isolation
        return (v.saetze, t.wdhVon, t.wdhBis, t.pauseSek, nil, t.aufwaermsatz)
    }

    private func art(fuer exerciseId: String, bisher: EntwurfsArt?) -> EntwurfsArt {
        if let m = merkmale[exerciseId] { return m.istCardio ? .cardio : .kraft(typ: m.typ) }
        return bisher ?? .kraft(typ: "isolation")
    }

    /// Werte der Art aus den Vorgaben; ohne Vorgaben bleiben sie offen (Server fuellt).
    private func vorgabenSetzen(_ p: inout EntwurfsPosition) {
        guard let v = vorgaben else { p.werteOffen = true; return }
        let w = ausVorgaben(cardio: p.art.istCardio, typ: typ(p.art), vorgaben: v)
        p.saetze = w.saetze; p.wdhVon = w.wdhVon; p.wdhBis = w.wdhBis
        p.pauseSek = w.pauseSek; p.dauerMin = w.dauerMin; p.aufwaermsatz = w.aufwaermsatz
        p.werteOffen = false
    }

    private func typ(_ art: EntwurfsArt) -> String {
        if case .kraft(let t) = art { return t }
        return "isolation"
    }

    mutating func hinzufuegen(exerciseId: String, modelId: String) {
        var p = EntwurfsPosition(
            id: UUID(), key: nil, exerciseId: exerciseId, modelId: modelId,
            art: art(fuer: exerciseId, bisher: nil), saetze: 0, wdhVon: nil, wdhBis: nil,
            pauseSek: 0, dauerMin: nil, aufwaermsatz: false)
        vorgabenSetzen(&p)
        positionen.append(p)
    }

    mutating func tauschen(id: UUID, exerciseId: String, modelId: String, alterName: String) {
        guard let i = positionen.firstIndex(where: { $0.id == id }) else { return }
        var p = positionen[i]
        let neueArt = art(fuer: exerciseId, bisher: p.art)
        let artGewechselt = neueArt.istCardio != p.art.istCardio
        p.exerciseId = exerciseId
        p.modelId = modelId
        p.art = neueArt
        p.ersetzt = alterName
        if artGewechselt {
            vorgabenSetzen(&p)
        } else if !neueArt.istCardio {
            // Gleiche Art: Werte der Stelle bleiben, nur der Aufwaermsatz folgt der Uebung.
            p.aufwaermsatz = typ(neueArt) == "mehrgelenk"
        }
        positionen[i] = p
    }

    mutating func werteSetzen(id: UUID, saetze: Int, wdhVon: Int?, wdhBis: Int?, pauseSek: Int, dauerMin: Int?) {
        guard let i = positionen.firstIndex(where: { $0.id == id }) else { return }
        positionen[i].saetze = saetze
        positionen[i].wdhVon = wdhVon
        positionen[i].wdhBis = wdhBis
        positionen[i].pauseSek = pauseSek
        positionen[i].dauerMin = dauerMin
        positionen[i].werteOffen = false
    }

    /// Die Ausgangsposition, mit der Werte verglichen werden: nur bei gleichem Schluessel
    /// und gleicher Art (sonst ist alles neu).
    private func vergleichsbasis(_ p: EntwurfsPosition) -> EntwurfsPosition? {
        guard let key = p.key, let alt = ausgang.first(where: { $0.key == key }),
              alt.art.istCardio == p.art.istCardio else { return nil }
        return alt
    }

    func geaenderteWerte(id: UUID) -> Set<WertFeld> {
        guard let p = positionen.first(where: { $0.id == id }), !p.werteOffen else { return [] }
        let alle: Set<WertFeld> = p.art.istCardio ? [.dauer] : [.saetze, .wdh, .pause]
        guard let alt = vergleichsbasis(p) else { return alle }
        var s: Set<WertFeld> = []
        if p.art.istCardio {
            if p.dauerMin != alt.dauerMin { s.insert(.dauer) }
        } else {
            if p.saetze != alt.saetze { s.insert(.saetze) }
            if p.wdhVon != alt.wdhVon || p.wdhBis != alt.wdhBis { s.insert(.wdh) }
            if p.pauseSek != alt.pauseSek { s.insert(.pause) }
        }
        return s
    }

    /// Wie `positionMinuten` in packages/domain/src/plan-einheit-ersetzen.ts mit den
    /// ZEIT-Konstanten aus packages/domain/src/trainingsplan-zeit.ts (einstellenMin 1.5,
    /// satzMin 0.75, aufwaermsatzMin 1.5). Positionen mit offenen Werten zaehlen nicht.
    private static func minuten(_ p: EntwurfsPosition) -> Double {
        if p.werteOffen { return 0 }
        if p.art.istCardio { return Double(p.dauerMin ?? 0) }
        return 1.5 + Double(p.saetze) * 0.75 + Double((p.saetze - 1) * p.pauseSek) / 60
            + (p.aufwaermsatz ? 1.5 : 0)
    }

    /// Wie der Server rechnet: Aufwaermen plus Summe, ungerundet.
    var geschaetzteMinuten: Double {
        (vorgaben?.aufwaermenMin ?? 0) + positionen.reduce(0) { $0 + Self.minuten($1) }
    }

    /// Werte nur, wenn sie vom Ausgang abweichen oder die Position neu/getauscht/artgewechselt
    /// ist; Kraft nie mit dauerMin, Cardio nur mit dauerMin.
    var rumpf: [ErsetzenPosition] {
        positionen.map { p in
            var r = ErsetzenPosition(key: p.key, exerciseId: p.exerciseId, modelId: p.modelId)
            if p.werteOffen { return r }
            let basis = vergleichsbasis(p)
            let alleSenden = basis == nil || basis?.exerciseId != p.exerciseId
            if p.art.istCardio {
                if alleSenden || p.dauerMin != basis?.dauerMin { r.dauerMin = p.dauerMin }
            } else {
                if alleSenden || p.saetze != basis?.saetze { r.saetze = p.saetze }
                if alleSenden || p.wdhVon != basis?.wdhVon || p.wdhBis != basis?.wdhBis {
                    r.wdhVon = p.wdhVon; r.wdhBis = p.wdhBis
                }
                if alleSenden || p.pauseSek != basis?.pauseSek { r.pauseSek = p.pauseSek }
            }
            return r
        }
    }

    /// Nach 409 (Plan hat sich geaendert): Positionen, deren Key fehlt, werden neu (key nil);
    /// der Ausgang ist danach die neue Einheit, damit rumpf richtig vergleicht.
    mutating func nachKonflikt(neueEinheit: TrainingsplanEinheit) {
        let vorhanden = Set(neueEinheit.positionen.map(\.key))
        for i in positionen.indices {
            if let k = positionen[i].key, !vorhanden.contains(k) { positionen[i].key = nil }
        }
        ausgang = neueEinheit.positionen.map(Self.entwurfsposition)
    }
}
