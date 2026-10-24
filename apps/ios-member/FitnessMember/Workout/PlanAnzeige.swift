import Foundation

/// Was die Planansicht "heute dran" zeigt (Trainingsplan Etappe 3, Task 11,
/// Entwuerfe 2.1-2.3): Zeilen, Untertitel, Fortschritt, Restzeit,
/// "Zusätzlich gemacht", der Abschluss und die Pause aus der Planposition.
///
/// Reine Ableitung aus Plan (Bootstrap), Ablaufzustand (Speicher) und den
/// Bloecken der Session -- ohne View und ohne Store, damit jede Regel ohne
/// Simulator testbar bleibt. Der Ablaufstatus selbst entsteht nicht hier,
/// sondern in `TrainingsplanAblauf` (gemeinsamer Testfallsatz mit dem
/// Server, F17); hier wird er nur gelesen.
enum PlanAnzeige {
    /// Der Plan, die Einheit von heute und ihr Ablauf -- was alle drei Orte
    /// (Training-Tab, Home, Pause am Geraet) gemeinsam brauchen.
    struct Heute: Equatable {
        let plan: Trainingsplan
        let einheit: TrainingsplanEinheit
        /// nil, solange der Ablauf zu einem anderen Plan oder einer anderen
        /// Einheit gehoert: dann ist heute noch alles offen.
        let zustand: AblaufZustand?

        var einheitKey: String { einheit.key }
    }

    // MARK: - Sichtbarkeit

    /// Der Plan des aktiven Studios; nil im Freien Training, in einem
    /// Studio ohne Plan und ohne Bootstrap -- dann sieht der Tab aus wie
    /// heute. Ein Plan ohne Einheiten ist keiner (nichts zu zeigen).
    static func plan(bootstrap: BootstrapResponse?, studioId: String?) -> Trainingsplan? {
        guard let studioId else { return nil }
        return bootstrap?.member.plans.first { $0.studioId == studioId && !$0.einheiten.isEmpty }
    }

    /// Die Einheit von heute: der Ablauf desselben Plans hat Vorrang (er
    /// kennt einen lokalen Abschluss, den der Server noch nicht kennt), dann
    /// die naechste laut Speicher, dann die des Servers, sonst die erste.
    static func einheitKey(plan: Trainingsplan, ablaufPlanId: String?, ablaufEinheitKey: String?,
                           naechsteEinheitKey: String?) -> String {
        let keys = plan.einheiten.map(\.key)
        if ablaufPlanId == plan.planId, let key = ablaufEinheitKey, keys.contains(key) { return key }
        if let key = naechsteEinheitKey, keys.contains(key) { return key }
        if let key = plan.naechsteEinheitKey, keys.contains(key) { return key }
        return keys[0]
    }

    /// Alles zusammen; nil, wenn die Karte entfaellt.
    ///
    /// Ein gebundener Ablauf (die Einheit laeuft) gilt im Studio seines Plans
    /// auch dann, wenn der Bootstrap schon eine neue planId nennt: ein
    /// dauerhafter Tausch legt eine neue Planzeile an (0062), die laufende
    /// Einheit bleibt aber bei ihrer Version (Review Focus 2) -- ohne das
    /// stuende ihr Fortschritt mitten im Training wieder auf 0.
    static func heute(bootstrap: BootstrapResponse?, studioId: String?, ablaufPlanId: String?,
                      ablaufEinheitKey: String?, ablaufZustand: AblaufZustand?,
                      naechsteEinheitKey: String?, ablaufGebunden: Bool = false,
                      ablaufStudioId: String? = nil) -> Heute? {
        guard let plan = plan(bootstrap: bootstrap, studioId: studioId) else { return nil }
        let ablaufPlanId = ablaufGebunden && ablaufStudioId == plan.studioId ? plan.planId : ablaufPlanId
        let key = einheitKey(plan: plan, ablaufPlanId: ablaufPlanId, ablaufEinheitKey: ablaufEinheitKey,
                             naechsteEinheitKey: naechsteEinheitKey)
        guard let einheit = plan.einheiten.first(where: { $0.key == key }) else { return nil }
        let passt = ablaufPlanId == plan.planId && ablaufEinheitKey == key
        return Heute(plan: plan, einheit: einheit, zustand: passt ? ablaufZustand : nil)
    }

    // MARK: - Zeilen

    /// Eine Zeile je Planposition, in Planreihenfolge (Empfehlung, kein
    /// Zwang -- Entwurf 2.1). Mit Ablauf folgen Reihenfolge, geplante Uebung
    /// und Status der gebundenen Planversion (`planstellen`).
    static func zeilen(plan: Trainingsplan, einheitKey: String, zustand: AblaufZustand?,
                       bloecke: [LokalerBlock], bootstrap: BootstrapResponse?) -> [PlanZeilenModell] {
        guard let einheit = plan.einheiten.first(where: { $0.key == einheitKey }) else { return [] }
        let muskeln = HomeZeilen.muskelnJeUebung(bootstrap)
        let stellen = planstellen(einheit: einheit, zustand: zustand)
        let ungeplant = ungeplanteUebungen(stellen: stellen, bloecke: bloecke)
        return stellen.map { stelle in
            let wirksam = stelle.wirksam
            // Das Geraet der Position nur, solange es zur geplanten Uebung
            // gehoert (gleiche Version, kein Tausch); sonst irgendeins mit ihr.
            let machineId = stelle.ersatz == nil && stelle.vorgabe?.exerciseId == stelle.geplant
                ? stelle.vorgabe?.machineId : nil
            let maschine = bildmaschine(exerciseId: wirksam, machineId: machineId,
                                        studioId: plan.studioId, bootstrap: bootstrap)
            let untertitel: String
            switch stelle.status {
            case .offen:
                untertitel = vorgabeText(stelle)
            case .erledigt:
                let saetze = satzzahl(exerciseId: wirksam, bloecke: bloecke)
                untertitel = !stelle.cardio && saetze > 0 ? satzText(saetze) : vorgabeText(stelle)
            case .optional:
                untertitel = ausloeser(hauptmuskeln: stelle.hauptmuskeln, ungeplant: ungeplant, muskeln: muskeln)
                    .map { "Optional: \(uebungsname($0.exerciseId, bootstrap)) zählt für \($0.gruppe)" }
                    ?? "Optional"
            case .getauscht:
                untertitel = "Heute: \(uebungsname(wirksam, bootstrap))"
            }
            return PlanZeilenModell(
                id: stelle.key,
                name: uebungsname(stelle.geplant, bootstrap),
                untertitel: untertitel,
                exerciseId: wirksam,
                vorschaubildModell: maschine?.equipmentModel.id,
                status: stelle.status.anzeige)
        }
    }

    /// Die Vorgabe als Text aus dem Bootstrap-Plan. Fehlt die Position dort
    /// (neuere Version ohne diesen Schluessel), bleibt ein neutraler Text --
    /// die Zahlen der gebundenen Version kennt der Speicher nicht.
    private static func vorgabeText(_ stelle: Planstelle) -> String {
        if let vorgabe = stelle.vorgabe { return vorgabeMitReserve(vorgabe) }
        return stelle.cardio ? "Cardio" : "Wie geplant"
    }

    /// "3 × 8–12 · Reserve 1–3"; Cardio nur die Minuten (keine Reserve am
    /// Fahrrad).
    static func vorgabeMitReserve(_ position: TrainingsplanPosition) -> String {
        let vorgabe = PlanZeilenModell.vorgabe(position)
        guard position.dauerMin == nil, position.baustein != "cardio" else { return vorgabe }
        let reserve = position.reserveVon == position.reserveBis
            ? "Reserve \(position.reserveVon)"
            : "Reserve \(position.reserveVon)–\(position.reserveBis)"
        return "\(vorgabe) · \(reserve)"
    }

    // MARK: - Kopf

    /// "4 von 7": erledigte und optionale Positionen zaehlen (Entwurf 2.2).
    static func fortschritt(plan: Trainingsplan, einheitKey: String, zustand: AblaufZustand?) -> String {
        let gesamt = zustand?.positionen.count ?? plan.einheiten.first { $0.key == einheitKey }?.positionen.count ?? 0
        let fertig = zustand?.positionen.filter { $0.status == .erledigt || $0.status == .optional }.count ?? 0
        return "\(fertig) von \(gesamt)"
    }

    /// "noch ca. 35 Min": die Schaetzung der Einheit anteilig nach den noch
    /// offenen Positionen. Eine Schaetzung je Position liefert der Server
    /// nicht; der Anteil ist ehrlich genug fuer ein "ca.". nil ohne
    /// Schaetzung und wenn nichts mehr offen ist.
    static func restminutenText(plan: Trainingsplan, einheitKey: String, zustand: AblaufZustand?) -> String? {
        guard let einheit = plan.einheiten.first(where: { $0.key == einheitKey }),
              let minuten = einheit.geschaetzteMinuten, !einheit.positionen.isEmpty else { return nil }
        let stellen = planstellen(einheit: einheit, zustand: zustand)
        let offen = stellen.filter { $0.status == .offen || $0.status == .getauscht }.count
        guard offen > 0, !stellen.isEmpty else { return nil }
        let rest = max(1, Int((minuten * Double(offen) / Double(stellen.count)).rounded()))
        return "noch ca. \(rest) Min"
    }

    /// "7 Übungen · ca. 63 Min" (Entwurf 1.4/2.1); ohne Schaetzung nur die Zahl.
    static func metaText(_ einheit: TrainingsplanEinheit) -> String {
        let anzahl = uebungenText(einheit.positionen.count)
        guard let minuten = einheit.geschaetzteMinuten else { return anzahl }
        return "\(anzahl) · ca. \(Int(minuten.rounded())) Min"
    }

    static func uebungenText(_ anzahl: Int) -> String {
        anzahl == 1 ? "1 Übung" : "\(anzahl) Übungen"
    }

    /// Die Zeile auf Home: vor dem ersten Haken wie die Karte ("7 Übungen ·
    /// ca. 63 Min"), danach der Stand ("3 von 7", wie in der Karte: erledigt
    /// und optional -- "erledigt" waere fuer optionale falsch).
    static func heuteDranUntertitel(_ heute: Heute) -> String {
        let fertig = heute.zustand?.positionen.contains { $0.status == .erledigt || $0.status == .optional } ?? false
        guard fertig else { return metaText(heute.einheit) }
        return fortschritt(plan: heute.plan, einheitKey: heute.einheitKey, zustand: heute.zustand)
    }

    /// "Danach: Einheit B"; ein Plan mit nur einer Einheit hat kein Danach.
    static func danachText(plan: Trainingsplan, einheitKey: String) -> String? {
        let keys = plan.einheiten.map(\.key)
        guard keys.count > 1 else { return nil }
        return "Danach: \(EinheitName.text(TrainingsplanFolge.naechsteEinheitKey(einheitKeys: keys, zuletzt: einheitKey)))"
    }

    // MARK: - Zusaetzlich gemacht

    /// Die ungeplanten Uebungen der Session mit ihrer Satzzahl (Entwurf 2.2),
    /// in der Reihenfolge, in der sie dran waren. "zählt mit", wenn sie eine
    /// Position optional gemacht hat.
    static func zusaetzlichGemacht(plan: Trainingsplan, einheitKey: String, zustand: AblaufZustand?,
                                   bloecke: [LokalerBlock], bootstrap: BootstrapResponse?) -> [PlanZeilenModell] {
        guard let einheit = plan.einheiten.first(where: { $0.key == einheitKey }) else { return [] }
        let muskeln = HomeZeilen.muskelnJeUebung(bootstrap)
        let stellen = planstellen(einheit: einheit, zustand: zustand)
        let ungeplant = ungeplanteUebungen(stellen: stellen, bloecke: bloecke)
        // Welche ungeplanten Uebungen eine optionale Position erklaeren --
        // dieselbe Ableitung wie im Untertitel der Planzeile.
        let zaehlenMit = Set(stellen.compactMap { stelle -> String? in
            guard stelle.status == .optional else { return nil }
            return ausloeser(hauptmuskeln: stelle.hauptmuskeln, ungeplant: ungeplant, muskeln: muskeln)?.exerciseId
        })
        return ungeplant.map { uebung in
            let saetze = satzzahl(exerciseId: uebung.exerciseId, bloecke: bloecke)
            return PlanZeilenModell(
                id: "zusatz:\(uebung.exerciseId)",
                name: uebungsname(uebung.exerciseId, bootstrap),
                untertitel: satzText(saetze) + (zaehlenMit.contains(uebung.exerciseId) ? " · zählt mit" : ""),
                exerciseId: uebung.exerciseId,
                // Ein Block aus einer Sessiondatei von vor dem Katalog kennt
                // nur das Geraet: dann dessen Modell aus dem Bootstrap.
                vorschaubildModell: uebung.equipmentModelId
                    ?? bootstrap?.machines.first { $0.id == uebung.machineId }?.equipmentModel.id,
                status: .erledigt,
                zusatz: true)
        }
    }

    // MARK: - Pause (F6)

    /// Die Pause nach einem Satz: bei einer Planuebung die der Position,
    /// deren wirksame Uebung (bei Tausch der Ersatz) trainiert wurde; sonst
    /// genau die Profil-Satzpause wie bisher.
    static func pauseSek(fuer exerciseId: String, plan: Trainingsplan?, einheitKey: String?,
                         zustand: AblaufZustand?, profil: Int) -> Int {
        guard let plan, let einheitKey,
              let einheit = plan.einheiten.first(where: { $0.key == einheitKey }) else { return profil }
        // Gesucht wird ueber die Uebung der gebundenen Version (wie der
        // Ablauf abhakt); die Dauer steht nur im Bootstrap-Plan, je Schluessel.
        for stelle in planstellen(einheit: einheit, zustand: zustand) where stelle.wirksam == exerciseId {
            // 0 hat nur Cardio; eine Kraftpause von 0 s waere ein Datenfehler,
            // dann lieber die gewohnte Pause.
            if let pause = stelle.vorgabe?.pauseSek, pause > 0 { return pause }
            return profil
        }
        return profil
    }

    // MARK: - Bild

    /// Das Geraet fuer das Vorschaubild: das der Position, wenn es im Studio
    /// noch aktiv steht; sonst irgendein aktives Geraet des Studios mit
    /// derselben Uebung; sonst keins (die Zeile bleibt ohne Foto).
    static func bildmaschine(exerciseId: String, machineId: String?, studioId: String,
                             bootstrap: BootstrapResponse?) -> BootstrapResponse.Machine? {
        let aktive = (bootstrap?.machines ?? []).filter { $0.studioId == studioId && $0.status == "active" }
        if let machineId, let eigene = aktive.first(where: { $0.id == machineId }) { return eigene }
        return aktive.first { maschine in maschine.exercises.contains { $0.id == exerciseId } }
    }

    // MARK: - Abschluss (2.3)

    struct Abschluss: Equatable {
        let titel: String
        let zeile: String
        let naechstes: String?
    }

    /// "Einheit A · 5 von 7 Übungen erledigt, 1 optional · Nächstes Mal ist
    /// Einheit B dran." Optional zaehlt hier getrennt, damit "erledigt" nur
    /// heisst, was wirklich gemacht wurde. Gezaehlt wird der beendete Ablauf
    /// selbst, nicht der Plan im Bootstrap: der kann inzwischen eine neuere
    /// Version mit anderen Positionen sein.
    static func abschluss(einheitKey: String, zustand: AblaufZustand,
                          naechsteEinheitKey: String?) -> Abschluss {
        let gesamt = zustand.positionen.count
        let erledigt = zustand.positionen.filter { $0.status == .erledigt }.count
        let optional = zustand.positionen.filter { $0.status == .optional }.count
        var zeile = "\(erledigt) von \(gesamt) \(gesamt == 1 ? "Übung" : "Übungen") erledigt"
        if optional > 0 { zeile += ", \(optional) optional" }
        let naechstes = naechsteEinheitKey.map { key in
            key == einheitKey
                ? "Nächstes Mal ist wieder \(EinheitName.text(key)) dran."
                : "Nächstes Mal ist \(EinheitName.text(key)) dran."
        }
        return Abschluss(titel: EinheitName.text(einheitKey).uppercased(), zeile: zeile, naechstes: naechstes)
    }

    // MARK: - Anfaengerangebot (2.3)

    static let anfaengerAngebotKey = "planAnfaengerAngebotGesehen"

    /// Einmal je Plan: wer es gesehen hat ("Später" oder einfach "Fertig"),
    /// bekommt es fuer diesen Plan nicht noch einmal (Entwurf 2.3: "erscheint
    /// einmal"). Ein neuer Plan hat eine neue Kennung und faengt neu an.
    static func zeigtAnfaengerAngebot(plan: Trainingsplan?, gesehen: Set<String>) -> Bool {
        guard let plan else { return false }
        return plan.anfaengerUebergang && !gesehen.contains(plan.planId)
    }

    /// Die Entscheidung des Abschluss-Screens, bei jedem neuen Bootstrap neu
    /// gefragt (nach completeSession laedt er nach; erst der kennt die eben
    /// beendete achte Einheit). Eine schon gezeigte Karte bleibt; sonst
    /// erscheint sie, sobald der Plan sie will und sie fuer ihn noch nie
    /// gezeigt wurde. Gemerkt wird beim Zeigen -- "Später" und "Fertig"
    /// lassen sie so nicht wiederkommen.
    static func anfaengerAngebotNachPruefung(bisher: Trainingsplan?, plan: Trainingsplan?,
                                             gesehen: Set<String>) -> Trainingsplan? {
        if let bisher { return bisher }
        return zeigtAnfaengerAngebot(plan: plan, gesehen: gesehen) ? plan : nil
    }

    static func gesehneAnfaengerAngebote(_ defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: anfaengerAngebotKey) ?? [])
    }

    static func anfaengerAngebotGesehen(planId: String, _ defaults: UserDefaults = .standard) {
        var gesehen = defaults.stringArray(forKey: anfaengerAngebotKey) ?? []
        guard !gesehen.contains(planId) else { return }
        gesehen.append(planId)
        defaults.set(gesehen, forKey: anfaengerAngebotKey)
    }

    /// Kopf und Text der Karte. Der Bootstrap kennt die eben beendete
    /// Einheit noch nicht; die Zahl ist deshalb die des Servers, nie eine
    /// geratene.
    static func anfaengerTexte(_ plan: Trainingsplan) -> (label: String, text: String) {
        let anzahl = max(8, plan.einheitenErledigt)
        let label = anzahl == 8 ? "EINHEIT 8 VON 8 ALS ANFÄNGER" : "\(anzahl) EINHEITEN ALS ANFÄNGER"
        return (label, "Du hast \(anzahl) Einheiten geschafft. Wir schlagen dir einen Plan mit mehr Sätzen vor. Du entscheidest.")
    }

    // MARK: - Intern

    struct UngeplanteUebung: Equatable {
        let exerciseId: String
        let machineId: String?
        let equipmentModelId: String?
    }

    /// Eine Position, wie die Ansicht sie liest. Mit Ablauf gilt dessen
    /// gebundene Planversion (Reihenfolge, geplante Uebung, Muskeln, Status)
    /// -- genau das zaehlt der Ablauf (Task 9, Review Focus 2). Kommt
    /// mitten in der Einheit eine neue Version (dauerhafter Tausch,
    /// Trainer), aendert sich die Einheit erst mit der naechsten. Der
    /// Bootstrap-Plan liefert dann nur noch die Vorgabe als Text.
    struct Planstelle: Equatable {
        let key: String
        let geplant: String
        let ersatz: String?
        let status: PositionStatus
        let hauptmuskeln: [String]
        let cardio: Bool
        /// Die Position desselben Schluessels im Bootstrap-Plan, nur fuer
        /// Vorgabe, Pause und Geraet.
        let vorgabe: TrainingsplanPosition?

        var wirksam: String { ersatz ?? geplant }
    }

    static func planstellen(einheit: TrainingsplanEinheit, zustand: AblaufZustand?) -> [Planstelle] {
        if let zustand {
            return zustand.positionen.map { ablauf in
                Planstelle(key: ablauf.key, geplant: ablauf.exerciseId, ersatz: ablauf.ersatzExerciseId,
                           status: ablauf.status, hauptmuskeln: ablauf.hauptmuskeln, cardio: ablauf.cardio,
                           vorgabe: einheit.positionen.first { $0.key == ablauf.key })
            }
        }
        return einheit.positionen.map { position in
            Planstelle(key: position.key, geplant: position.exerciseId, ersatz: nil, status: .offen,
                       hauptmuskeln: position.hauptmuskeln, cardio: position.baustein == "cardio", vorgabe: position)
        }
    }

    /// Die Uebungen der Session, die keine Position fuehrt (wirksame Uebung,
    /// bei Tausch also der Ersatz -- wie Regel 2 in `TrainingsplanAblauf`),
    /// je Uebung einmal, in der Reihenfolge ihres ersten Satzes. Cardio ist
    /// nur ungeplant, wenn die Einheit keine Cardio-Position hat: sonst
    /// zaehlt jedes Cardiogeraet fuer sie (F19).
    static func ungeplanteUebungen(stellen: [Planstelle], bloecke: [LokalerBlock]) -> [UngeplanteUebung] {
        let geplant = Set(stellen.map(\.wirksam))
        let hatCardio = stellen.contains { $0.cardio }
        let geordnet = bloecke
            .filter { !$0.saetze.isEmpty }
            .sorted { ($0.saetze.map(\.performedAt).min() ?? .distantFuture) < ($1.saetze.map(\.performedAt).min() ?? .distantFuture) }
        var gesehen: Set<String> = []
        var ergebnis: [UngeplanteUebung] = []
        for block in geordnet {
            let cardio = block.saetze.contains { $0.cardio != nil }
            if geplant.contains(block.exerciseId) || (cardio && hatCardio) || gesehen.contains(block.exerciseId) { continue }
            gesehen.insert(block.exerciseId)
            ergebnis.append(UngeplanteUebung(exerciseId: block.exerciseId, machineId: block.machineId,
                                             equipmentModelId: block.equipmentModelId))
        }
        return ergebnis
    }

    /// Die erste ungeplante Uebung in Sessionreihenfolge, die einen
    /// Hauptmuskel mit der Position teilt, und die Muskelgruppe dieses
    /// Muskels. Der Ablauf speichert den Ausloeser nicht; das hier ist eine
    /// Erklaerung fuer das Mitglied, keine Regel -- im Zweifel steht nur
    /// "Optional".
    private static func ausloeser(hauptmuskeln: [String], ungeplant: [UngeplanteUebung],
                                  muskeln: [String: [GeraetMuskel]]) -> (exerciseId: String, gruppe: String)? {
        for uebung in ungeplant {
            let primaer = Set((muskeln[uebung.exerciseId] ?? []).filter { $0.role == .primary }.map(\.key))
            for muskel in hauptmuskeln where primaer.contains(muskel) {
                if let gruppe = MuskelHauptgruppe.angezeigt.first(where: { $0.muskelSchluessel.contains(muskel) }) {
                    return (uebung.exerciseId, gruppe.titel)
                }
            }
        }
        return nil
    }

    private static func satzzahl(exerciseId: String, bloecke: [LokalerBlock]) -> Int {
        bloecke.filter { $0.exerciseId == exerciseId }.reduce(0) { $0 + $1.saetze.count }
    }

    private static func satzText(_ anzahl: Int) -> String {
        anzahl == 1 ? "1 Satz" : "\(anzahl) Sätze"
    }

    private static func uebungsname(_ exerciseId: String, _ bootstrap: BootstrapResponse?) -> String {
        PlanZeilenModell.uebungsname(exerciseId: exerciseId, maschine: nil, bootstrap: bootstrap)
    }
}

extension PositionStatus {
    /// Der Status, wie ihn Zeile und Marke kennen (dieselben vier Werte wie
    /// in der Momentaufnahme).
    var anzeige: PlanMomentaufnahme.Status {
        switch self {
        case .offen: .offen
        case .erledigt: .erledigt
        case .optional: .optional
        case .getauscht: .getauscht
        }
    }
}
