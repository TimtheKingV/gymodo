import Foundation

/// Eine Zeile der Ablauf-Liste im Pausen-Screen (UX-Paket 2): erledigt,
/// jetzt, naechste, offen. Reine Werte; die View (Task 4) zeigt sie nur an
/// (E6: Antippen springt nirgendwohin).
struct AblaufZeile: Identifiable, Equatable {
    enum Stand: Equatable { case erledigt, jetzt, naechste, offen }

    let id: String
    let name: String
    /// Erledigt: Saetze/Satzwerte; jetzt: letzter Satz und "Satz n";
    /// naechste/offen: die Vorgabe ("3 × 10–12") oder "".
    let detail: String
    let stand: Stand
    let bildModellId: String?
}

/// Die Ablauf-Liste fuer Plan, Mini-Zirkel und freies Training, als reine
/// Funktionen ohne View und Store.
enum AblaufListe {

    // MARK: - Plan

    /// Die Reihenfolge ist die des Ablaufs ohne ausgelassene Positionen.
    /// Erledigt = Status `.erledigt`/`.optional`, jetzt = `aktuelleUebung`
    /// (wirksame Uebung), die `naechstePlanstelle` ist `.naechste`, der
    /// Rest `.offen`.
    static func plan(plan: Trainingsplan, einheitKey: String, zustand: AblaufZustand?,
                     ausgelassen: Set<String>, bloecke: [LokalerBlock],
                     aktuelleUebung: String?, bootstrap: BootstrapResponse?) -> [AblaufZeile] {
        guard let einheit = plan.einheiten.first(where: { $0.key == einheitKey }) else { return [] }
        let stellen = PlanAnzeige.planstellen(einheit: einheit, zustand: zustand)
            .filter { !ausgelassen.contains($0.key) }
        let naechste = naechstePlanstelle(stellen: stellen, ausgelassen: ausgelassen,
                                          aktuelleUebung: aktuelleUebung)
        var jetztVergeben = false
        return stellen.map { stelle in
            let wirksam = stelle.wirksam
            let stand: AblaufZeile.Stand
            if !jetztVergeben, let aktuelleUebung, wirksam == aktuelleUebung {
                jetztVergeben = true
                stand = .jetzt
            } else if stelle.key == naechste?.key {
                stand = .naechste
            } else if stelle.status == .erledigt || stelle.status == .optional {
                stand = .erledigt
            } else {
                stand = .offen
            }
            let modelId = stelle.ersatz == nil && stelle.vorgabe?.exerciseId == stelle.geplant
                ? stelle.vorgabe?.modelId : nil
            let uebungsBloecke = bloecke.filter { $0.exerciseId == wirksam }
            let vorgabe = stelle.vorgabe.map(PlanZeilenModell.vorgabe) ?? ""
            let detail: String
            switch stand {
            case .erledigt: detail = erledigtText(uebungsBloecke) ?? vorgabe
            case .jetzt: detail = jetztText(uebungsBloecke, satzGemacht: PlanAnzeige.satzzahl(exerciseId: wirksam, bloecke: bloecke))
            case .naechste, .offen: detail = vorgabe
            }
            return AblaufZeile(
                id: stelle.key,
                name: PlanZeilenModell.uebungsname(exerciseId: wirksam, maschine: nil, bootstrap: bootstrap),
                detail: detail, stand: stand,
                bildModellId: PlanAnzeige.bildmodell(exerciseId: wirksam, modelId: modelId, bootstrap: bootstrap))
        }
    }

    /// E3: die erste Planstelle mit Status `.offen` oder `.getauscht`, nicht
    /// ausgelassen, nicht die aktuelle Uebung, in Ablauf-Reihenfolge. Die
    /// einzige Stelle dieser Regel: Ablauf-Liste und "Naechste Uebung: ..."
    /// (Task 6) fragen beide hier.
    static func naechstePlanstelle(stellen: [PlanAnzeige.Planstelle], ausgelassen: Set<String>,
                                   aktuelleUebung: String?) -> PlanAnzeige.Planstelle? {
        stellen.first { stelle in
            (stelle.status == .offen || stelle.status == .getauscht)
                && !ausgelassen.contains(stelle.key)
                && stelle.wirksam != aktuelleUebung
        }
    }

    // MARK: - Zirkel

    /// `abgeschlossen` ist erledigt, `naechste` die naechste Station (in der
    /// Rundenpause die erste der neuen Runde), alles andere offen. Ein
    /// "jetzt" gibt es in der Zirkel-Pause nicht. Erledigt nennt alle Saetze
    /// seit `seit`, naechste/offen den letzten Satz (je einmal).
    static func zirkel(_ zirkel: Zirkel, bloecke: [LokalerBlock], seit: Date?,
                       name: (ZirkelUebung) -> String,
                       bildModellId: (ZirkelUebung) -> String?) -> [AblaufZeile] {
        zirkel.uebungen.enumerated().map { index, uebung in
            let block = bloecke.first {
                $0.stationSchluessel == uebung.station && $0.exerciseId == uebung.exerciseId
            }
            let werte = block.map { block in
                block.saetze
                    .filter { satz in seit.map { satz.performedAt >= $0 } ?? true }
                    .compactMap { ZirkelPauseText.satzwerte($0, block) }
            } ?? []
            let stand: AblaufZeile.Stand
            switch zirkel.stand(an: index) {
            case .abgeschlossen: stand = .erledigt
            case .naechste: stand = .naechste
            case .dran, .offen: stand = .offen
            }
            let detail = stand == .erledigt ? werte.joined(separator: " · ") : (werte.last ?? "")
            return AblaufZeile(id: "\(uebung.station):\(uebung.exerciseId)", name: name(uebung),
                               detail: detail, stand: stand, bildModellId: bildModellId(uebung))
        }
    }

    // MARK: - Frei

    /// Alle Bloecke mit Satz sind erledigt, der aktuelle Block ist `.jetzt`
    /// -- auch ohne Satz. Reihenfolge wie in der Einheit (erster Satz).
    static func frei(bloecke: [LokalerBlock], aktuell: (stationSchluessel: String, exerciseId: String)?,
                     name: (LokalerBlock) -> String) -> [AblaufZeile] {
        bloecke.compactMap { block in
            let istAktuell = block.stationSchluessel == aktuell?.stationSchluessel
                && block.exerciseId == aktuell?.exerciseId
            guard istAktuell || !block.saetze.isEmpty else { return nil }
            return AblaufZeile(
                id: block.id, name: name(block),
                detail: istAktuell ? jetztText([block], satzGemacht: block.saetze.count)
                                   : TrainingTab.blockzeile(block),
                stand: istAktuell ? .jetzt : .erledigt, bildModellId: block.equipmentModelId)
        }
    }

    // MARK: - Ausschnitt

    /// Hoechstens 2 erledigte darueber (die letzten), der Anker (`.jetzt`,
    /// sonst die `.naechste`, sonst die erste offene), hoechstens 2 darunter;
    /// `ausgeklappt` zeigt alle.
    static func sichtbar(_ zeilen: [AblaufZeile], ausgeklappt: Bool) -> [AblaufZeile] {
        if ausgeklappt { return zeilen }
        let anker = zeilen.firstIndex { $0.stand == .jetzt }
            ?? zeilen.firstIndex { $0.stand == .naechste }
            ?? zeilen.firstIndex { $0.stand == .offen }
        guard let anker else { return Array(zeilen.suffix(2)) }
        return Array(zeilen[max(0, anker - 2)...min(zeilen.count - 1, anker + 2)])
    }

    static func hatMehr(_ zeilen: [AblaufZeile]) -> Bool {
        sichtbar(zeilen, ausgeklappt: false).count < zeilen.count
    }

    // MARK: - Texte

    /// "3 Sätze · 30,0 kg": Zahl ueber alle Bloecke der Uebung, Werte des
    /// zuletzt geschriebenen Satzes.
    private static func erledigtText(_ bloecke: [LokalerBlock]) -> String? {
        let anzahl = bloecke.reduce(0) { $0 + $1.saetze.count }
        guard anzahl > 0, let letzter = zuletzt(bloecke) else { return nil }
        let teile = TrainingTab.blockzeile(letzter).components(separatedBy: " · ").dropFirst()
        return ([anzahl == 1 ? "1 Satz" : "\(anzahl) Sätze"] + teile).joined(separator: " · ")
    }

    /// "12,5 kg × 10 · Satz 3": der letzte Satz und der, der jetzt kommt.
    private static func jetztText(_ bloecke: [LokalerBlock], satzGemacht: Int) -> String {
        let satz = "Satz \(satzGemacht + 1)"
        guard let block = zuletzt(bloecke), let letzter = block.saetze.last,
              let werte = ZirkelPauseText.satzwerte(letzter, block) else { return satz }
        return "\(werte) · \(satz)"
    }

    private static func zuletzt(_ bloecke: [LokalerBlock]) -> LokalerBlock? {
        bloecke.filter { !$0.saetze.isEmpty }.max {
            ($0.saetze.map(\.performedAt).max() ?? .distantPast) < ($1.saetze.map(\.performedAt).max() ?? .distantPast)
        }
    }
}
