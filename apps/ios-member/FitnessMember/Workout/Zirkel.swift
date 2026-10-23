import Foundation

// Mini-Zirkel: reiner Wertetyp ohne UI und ohne Store (Spec 21.10.).
//
// Der Zirkel kennt nur einen Zaehler: `schritt` = Anzahl erledigter Slots
// (Satz gemacht oder uebersprungen). Runde, Position und Pausenart leiten
// sich daraus ab, so gibt es keinen zweiten Stand, der auseinanderlaufen kann.

struct ZirkelUebung: Hashable, Sendable {
    let station: String
    let exerciseId: String
    /// Der Uebungsstart-Token der Uebung, falls eine Einheit schon laeuft.
    let token: String?
}

struct Zirkel: Equatable, Sendable {
    static let rundenBereich = 2...6
    static let mindestUebungen = 2

    private(set) var uebungen: [ZirkelUebung]
    var runden: Int
    /// Pause zwischen zwei Uebungen derselben Runde, in Sekunden.
    var uebungspause: Int
    /// Pause beim Wechsel in die naechste Runde, in Sekunden.
    var rundenpause: Int
    /// Anzahl erledigter Slots, uebersprungene eingeschlossen.
    private(set) var schritt: Int

    init(uebungen: [ZirkelUebung], runden: Int = 3, uebungspause: Int, rundenpause: Int, schritt: Int = 0) {
        // Teilen und Modulo laufen ueber uebungen.count: ohne zwei Uebungen
        // ist es kein Zirkel. Einzige Tuer fuer den Start mit einer Uebung
        // ist ausEinzelsatz, das gleich zwei erzeugt.
        precondition(uebungen.count >= Self.mindestUebungen, "Zirkel braucht mindestens \(Self.mindestUebungen) Uebungen")
        self.uebungen = uebungen
        self.runden = min(max(runden, Self.rundenBereich.lowerBound), Self.rundenBereich.upperBound)
        self.uebungspause = uebungspause
        self.rundenpause = rundenpause
        self.schritt = max(schritt, 0)
    }

    /// 1-basiert. Nach dem letzten Slot zaehlt sie ueber `runden` hinaus;
    /// wer sie anzeigt, prueft vorher `istFertig`.
    var runde: Int { schritt / uebungen.count + 1 }
    var position: Int { schritt % uebungen.count }

    var istFertig: Bool { schritt >= runden * uebungen.count }

    /// Die zuletzt erledigte Uebung; vor dem ersten Slot nil.
    var aktuelle: ZirkelUebung? {
        schritt > 0 ? uebungen[(schritt - 1) % uebungen.count] : nil
    }

    /// Die Uebung des naechsten Slots; nil, wenn der Zirkel fertig ist.
    var naechste: ZirkelUebung? { istFertig ? nil : uebungen[position] }

    var naechsterSchrittIstRundenwechsel: Bool {
        schritt > 0 && schritt % uebungen.count == 0 && !istFertig
    }

    var pausenSekunden: Int { naechsterSchrittIstRundenwechsel ? rundenpause : uebungspause }

    /// Erweitern ist nur offen, solange Runde 1 gerade komplett ist: danach
    /// haetten die Runden unterschiedlich viele Uebungen.
    var kannErweitern: Bool { schritt == uebungen.count }

    mutating func weiter() {
        guard !istFertig else { return }
        schritt += 1
    }

    /// Wie `weiter()`; der eigene Name macht die Aufrufer lesbar.
    mutating func ueberspringen() { weiter() }

    @discardableResult
    mutating func erweitern(um uebung: ZirkelUebung) -> Bool {
        guard kannErweitern else { return false }
        uebungen.append(uebung)
        return true
    }

    /// Aus einem Einzelsatz wird ein Zirkel: der erste Satz zaehlt schon als
    /// Slot 1 der ersten Runde.
    static func ausEinzelsatz(_ erste: ZirkelUebung, zweite: ZirkelUebung, runden: Int, uebungspause: Int, rundenpause: Int) -> Zirkel {
        Zirkel(uebungen: [erste, zweite], runden: runden, uebungspause: uebungspause, rundenpause: rundenpause, schritt: 1)
    }

    /// "Zirkel mit weiterem Gerät" (Task 7): ohne Planungs-Screen, also drei
    /// Runden und die Pausen aus dem Profil -- dieselben Vorgaben wie
    /// ZirkelEntwurf (Spec, Meine Annahmen zum Erweitern).
    static func ausEinzelsatz(_ erste: ZirkelUebung, zweite: ZirkelUebung, defaults: UserDefaults = .standard) -> Zirkel {
        ausEinzelsatz(erste, zweite: zweite, runden: 3,
                      uebungspause: Einstellungen.zirkelPauseSekunden(defaults),
                      rundenpause: Einstellungen.resttimerSekunden(defaults))
    }

    /// Station und Uebung, nicht der Token: dieselbe Uebung zweimal haette
    /// nur einen Block in der Einheit (siehe ZirkelEntwurf.hinzufuegen).
    func enthaelt(_ uebung: ZirkelUebung) -> Bool {
        uebungen.contains { $0.station == uebung.station && $0.exerciseId == uebung.exerciseId }
    }
}

// MARK: - Fortschritt je Uebung

/// Wo eine Uebung im laufenden Zirkel steht -- die Zeilen der Pausenliste.
enum ZirkelStand: Equatable {
    /// Alle Runden dran gewesen: Haekchen.
    case abgeschlossen
    /// Die Uebung, die jetzt kommt.
    case naechste
    /// In der laufenden Runde schon dran (gruen): "1/3".
    case dran(Int, von: Int)
    /// In der laufenden Runde noch nicht dran: "0/3".
    case offen(Int, von: Int)
}

extension Zirkel {
    /// Ein Slot gilt als gemacht, sobald er erledigt ist -- auch uebersprungen,
    /// denn der Zirkel kennt nur `schritt`.
    func stand(an index: Int) -> ZirkelStand {
        let anzahl = uebungen.count
        let gemacht = schritt / anzahl + (index < schritt % anzahl ? 1 : 0)
        if gemacht >= runden { return .abgeschlossen }
        if index == position { return .naechste }
        return index < schritt % anzahl ? .dran(gemacht, von: runden) : .offen(gemacht, von: runden)
    }
}

// MARK: - Planung (Spec 21.10., Entscheidungen 1-4)

/// Der Zirkel, solange er noch geplant wird. Eigener Typ statt eines
/// halbfertigen Zirkels: der verlangt zwei Uebungen schon beim Bauen, die
/// Planung beginnt aber mit einer (dem gewaehlten Geraet).
struct ZirkelEntwurf: Equatable {
    var uebungen: [ZirkelUebung]
    var runden: Int = 3
    var uebungspause: Int
    var rundenpause: Int
    /// Gewicht und Wiederholungen je Uebung, beim Anlegen festgelegt: im
    /// Zirkel entfaellt so der Drawer vor jeder Uebung. Uebungen ohne
    /// Eintrag (Cardio) gehen den bisherigen Weg.
    private(set) var werte: [ZirkelUebung: Startwerte] = [:]

    /// Die Pausen kommen aus den Einstellungen: zwischen Uebungen die kurze
    /// Zirkelpause, zwischen Runden der normale Satz-Resttimer -- die
    /// Rundenpause ist eine Pause wie zwischen zwei Saetzen.
    init(uebungen: [ZirkelUebung], runden: Int = 3, defaults: UserDefaults = .standard) {
        self.init(uebungen: uebungen, runden: runden,
                  uebungspause: Einstellungen.zirkelPauseSekunden(defaults),
                  rundenpause: Einstellungen.resttimerSekunden(defaults))
    }

    init(uebungen: [ZirkelUebung], runden: Int = 3, uebungspause: Int, rundenpause: Int) {
        self.uebungen = uebungen
        self.runden = runden
        self.uebungspause = uebungspause
        self.rundenpause = rundenpause
    }

    /// Dieselben Grenzen wie Zirkel.init -- der klemmt die Runden still, die
    /// Planung soll dagegen gar nicht erst starten lassen.
    var istGueltig: Bool {
        uebungen.count >= Zirkel.mindestUebungen && Zirkel.rundenBereich.contains(runden)
    }

    /// Dieselbe Uebung zweimal haette zwei Slots, aber nur einen Block in
    /// der Einheit -- Rundenzusammenfassung und "Letztes Mal" koennten die
    /// beiden nicht auseinanderhalten. Die Liste traegt ausserdem die Uebung
    /// selbst als Identitaet.
    @discardableResult
    mutating func hinzufuegen(_ uebung: ZirkelUebung) -> Bool {
        guard !uebungen.contains(where: { $0.station == uebung.station && $0.exerciseId == uebung.exerciseId })
        else { return false }
        uebungen.append(uebung)
        return true
    }

    /// Wie List.onMove: `nach` zaehlt vor dem Entfernen.
    mutating func verschiebe(von quelle: IndexSet, nach ziel: Int) {
        uebungen.move(fromOffsets: quelle, toOffset: ziel)
    }

    mutating func entferne(at stellen: IndexSet) {
        for stelle in stellen { werte[uebungen[stelle]] = nil }
        uebungen.remove(atOffsets: stellen)
    }

    /// nil loescht den Eintrag.
    mutating func setzeWerte(_ werte: Startwerte?, fuer uebung: ZirkelUebung) {
        self.werte[uebung] = werte
    }

    /// Nur fuer einen gueltigen Entwurf (Zirkel.init prueft die
    /// Mindestzahl hart); der Knopf "Zirkel starten" ist sonst gesperrt.
    func zirkel() -> Zirkel {
        Zirkel(uebungen: uebungen, runden: runden, uebungspause: uebungspause, rundenpause: rundenpause)
    }
}

/// Welche Uebung ein Geraet beitraegt, das in der Planung dazukommt. Kein
/// Drawer an dieser Stelle (Anti-Ziel: Zirkel darf nicht umstaendlicher
/// werden): dieselbe Vorauswahl wie beim Oeffnen eines Geraets
/// (TrainingRootView.modell), das Gewicht fragt der Drawer in Runde 1.
enum ZirkelAuswahl {
    /// `uebungId`: ein Uebungstreffer der Suche. Aus der Liste gibt es
    /// keinen Token -- der kommt nur mit einem Scan.
    static func uebung(station: Station, uebungId: String?, bootstrap: BootstrapResponse) -> ZirkelUebung? {
        let gewaehlt = uebungId
            ?? GeraetEinstiegRechner.letzteUebung(station: station.schluessel, in: bootstrap)
            ?? station.exercises.first?.id
        guard let gewaehlt else { return nil }
        return ZirkelUebung(station: station.schluessel, exerciseId: gewaehlt, token: nil)
    }

    /// Was ein gewaehltes Geraet in Planung oder Erweitern beitraegt.
    enum Angebot: Equatable {
        /// Steht fest -- in den Zirkel damit.
        case uebung(ZirkelUebung)
        /// Mehrere Uebungen an einer Station: das Mitglied waehlt. `offen`
        /// steht zur Wahl, `schonDabei` nur im Hinweis.
        case auswahl(offen: [ZirkelUebung], schonDabei: [ZirkelUebung])
        case schonDabei
        /// Ein Geraet ohne Uebung.
        case keine
    }

    /// Finding I-2: eine Station mit mehreren Uebungen (Spec-Beispiel: drei
    /// Kurzhantel-Uebungen) loeste vorher still auf die zuletzt genutzte
    /// auf -- war die schon im Zirkel, kam man an die anderen nur ueber die
    /// Suche. Jetzt fragt sie nach. Eine schon gewaehlte Uebung (Suchtreffer,
    /// Wahl im Dialog) und eine Station mit einer Uebung bleiben ohne Frage.
    /// Vergleich ueber Station und Uebung, nicht den Token (wie Zirkel.enthaelt).
    static func angebot(station: Station, uebungId: String?, bootstrap: BootstrapResponse,
                        imZirkel: [ZirkelUebung]) -> Angebot {
        func dabei(_ u: ZirkelUebung) -> Bool {
            imZirkel.contains { $0.station == u.station && $0.exerciseId == u.exerciseId }
        }
        if uebungId == nil, station.exercises.count > 1 {
            let alle = station.exercises.map {
                ZirkelUebung(station: station.schluessel, exerciseId: $0.id, token: nil)
            }
            let offen = alle.filter { !dabei($0) }
            return offen.isEmpty ? .schonDabei : .auswahl(offen: offen, schonDabei: alle.filter(dabei))
        }
        guard let u = uebung(station: station, uebungId: uebungId, bootstrap: bootstrap) else { return .keine }
        return dabei(u) ? .schonDabei : .uebung(u)
    }
}

/// Die Startwerte aus dem Drawer gehoeren zu der Uebung, fuer die sie
/// eingegeben wurden -- nicht zu Platz 1 des Zirkels. Wird umsortiert,
/// gelten sie, sobald diese Uebung in Runde 1 drankommt; ohne sie liefe
/// eine einfache Uebung ueber den Direktstart ohne das gewaehlte Gewicht.
struct ZirkelVormerkung: Equatable {
    private var werte: [ZirkelUebung: Startwerte]

    init(_ uebung: ZirkelUebung, werte: Startwerte) {
        self.werte = [uebung: werte]
    }

    init(_ werte: [ZirkelUebung: Startwerte]) {
        self.werte = werte
    }

    private init(werte: [ZirkelUebung: Startwerte]) {
        self.werte = werte
    }

    static let leer = ZirkelVormerkung(werte: [:])

    /// Beim Start: nur, was noch im Entwurf steht. Eine entfernte Uebung
    /// nimmt ihre Werte mit.
    func behalten(nur uebungen: [ZirkelUebung]) -> ZirkelVormerkung {
        ZirkelVormerkung(werte: werte.filter { uebungen.contains($0.key) })
    }

    /// Einmal und nur in Runde 1: ab Runde 2 belegt GeraetModel das Gewicht
    /// aus der Vorrunde vor. Auch eine Frage aus Runde 2 raeumt den Eintrag
    /// (wurde die Uebung in Runde 1 uebersprungen, waere er sonst veraltet).
    mutating func entnehmen(_ uebung: ZirkelUebung, runde: Int) -> Startwerte? {
        let gemerkt = werte.removeValue(forKey: uebung)
        return runde == 1 ? gemerkt : nil
    }
}
