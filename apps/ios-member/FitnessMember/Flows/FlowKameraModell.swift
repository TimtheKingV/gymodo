import Foundation
import Koerperbild
import Observation
import QuartzCore

/// Was die Kamera in einem Flow-Zustand tun soll.
enum FlowKameraSoll: Equatable {
    case aus
    /// Die Kamera laeuft schon fuer den kommenden Schritt, gezaehlt wird noch nicht.
    case vorlauf(Int)
    /// Arbeitsphase eines Kamera-Schritts.
    case zaehlen(Int)
}

/// Eine Zeile im Fertig-Bildschirm: "Liegestütze 14".
struct FlowFertigZeile: Equatable, Identifiable {
    let schrittIndex: Int
    let name: String
    let wiederholungen: Int
    var id: Int { schrittIndex }
}

/// Reine Entscheidungen rund um die Kamera des Flows, ohne Kamera und Uhr.
enum FlowKameraPlan {
    /// Der Countdown ist der Vorlauf vor Schritt 1; er ist kuerzer als der Vorlauf.
    static func soll(_ zustand: FlowZustand, kameraSchritt: (Int) -> Bool) -> FlowKameraSoll {
        switch zustand {
        case .countdown(let rest):
            return kameraSchritt(0) && rest <= FlowKameraModell.vorlaufS ? .vorlauf(0) : .aus
        case .pause(let naechster, let rest):
            return kameraSchritt(naechster) && rest <= FlowKameraModell.vorlaufS ? .vorlauf(naechster) : .aus
        case .arbeit(let schritt, _):
            return kameraSchritt(schritt) ? .zaehlen(schritt) : .aus
        case .fertig:
            return .aus
        }
    }

    /// Die gezaehlten Schritte in Schrittfolge; Schritte ohne Zaehlung fehlen.
    static func fertigZeilen(schritte: [FlowSchritt], gezaehlt: [Int: Int]) -> [FlowFertigZeile] {
        gezaehlt.keys.sorted().compactMap { i in
            guard schritte.indices.contains(i), let n = gezaehlt[i] else { return nil }
            return FlowFertigZeile(schrittIndex: i, name: schritte[i].name, wiederholungen: n)
        }
    }
}

/// Die Kamera eines Flows: einmal Aufstellen vor dem Start, dann je zaehlbarem Schritt Kamera an
/// (5 s vor Ende der Pause) und Zaehlung in der Arbeitsphase. Die Flow-Uhr bestimmt alles; das Modell
/// folgt nur ihrem Zustand (`folge`) und wartet nie. Ein Kamerafehler setzt hoechstens `hinweis`.
@MainActor @Observable
final class FlowKameraModell {
    enum Start: Equatable { case aufstellen, erlaubnisFehlt, kameraFehlt, bereit, ohneKamera }

    /// So viele Sekunden vor Ende der Pause startet die Kamera.
    nonisolated static let vorlaufS = 5
    static let hinweisText = "Kamera sieht dich gerade nicht"
    /// Kommt so lange kein Bild, speist der Leerlauf ein leeres Bild ein (Welle und Hinweis laufen weiter).
    static let bildluecke: TimeInterval = 0.5
    /// Die Aufstellpruefung: stehend, Schulter, Huefte, Knie und Fuss einer Seite.
    static let aufstellVorgabe = Kameravorgabe(profil: .ganzkoerperStehend, signal: .knie, seite: .beide)!

    private(set) var start: Start
    /// Aufstellen oder sein Hinweis steht noch an; der Lauf hat nicht begonnen.
    var vorDemStart: Bool {
        switch start {
        case .aufstellen, .erlaubnisFehlt, .kameraFehlt: true
        case .bereit, .ohneKamera: false
        }
    }
    /// false nach "Ohne Kamera starten", ohne Erlaubnis und bei Flows ohne Kamera-Schritt.
    var mitKamera: Bool { hatKameraSchritt && start == .bereit }
    /// Nur waehrend der Arbeitsphase eines Kamera-Schritts.
    private(set) var zaehler: FlowZaehler?
    private(set) var letztesSkelett: Skelett?
    var ziel: Livebildziel {
        Livebildziel(ebene: aktiveQuelle?.anzeige, gespiegelt: aktiveQuelle is FrontkameraQuelle)
    }
    private(set) var hinweis: String?
    /// Schritt-Index (0-basiert) -> Wiederholungen; nur Schritte, in denen die Kamera Bilder lieferte.
    private(set) var gezaehlt: [Int: Int] = [:]

    private enum Einsatz: Equatable { case aufstellen, schritt(Int) }

    private let schritte: [FlowSchritt]
    /// Je Schritt der Kamera-Start; nil bei Schritten ohne Kamera.
    private let kameraStarts: [KameraStart?]
    private let hatKameraSchritt: Bool
    private let quellenFabrik: @MainActor (KameraStart) -> any Bildquelle
    private let erlaubnis: () -> Kameraerlaubnis
    private let anfragen: () async -> Kameraerlaubnis
    private let uhr: () -> TimeInterval
    private let leerlaufTakt: Duration?

    private var aktiveQuelle: (any Bildquelle)?
    /// Die zuletzt gebaute Quelle und fuer welche Uebung: dieselbe Uebung (Aufstellen und erster Schritt,
    /// wiederholte Uebungen) nimmt dieselbe Quelle, deren Stopp und Start dann sicher hintereinander laufen.
    @ObservationIgnored private var letzteQuelle: (exerciseId: String, quelle: any Bildquelle)?
    private var einsatz: Einsatz?
    private var kameraLaeuft = false
    /// Zaehlt Starts und Stopps; ein Start, der nach einem Stopp zurueckkehrt, gilt nicht mehr.
    @ObservationIgnored private var startNummer = 0
    /// Bildzeit -> Modelluhr, gemessen am ersten Bild nach jedem Start.
    @ObservationIgnored private var versatz: TimeInterval?
    @ObservationIgnored private var letzterBildEmpfang: TimeInterval?
    @ObservationIgnored private var pruefung = Erkennungspruefung(vorgabe: FlowKameraModell.aufstellVorgabe)

    /// Der Schritt, fuer den die Kamera gerade laufen soll (Vorlauf oder Arbeit).
    private var zielSchritt: Int?
    /// In diesem Schritt ist die Kamera gescheitert; erst der naechste Kamera-Schritt versucht es neu.
    private var fehlerSchritt: Int?
    private var aktiverSchritt: Int?
    /// Der Zaehler des kommenden Schritts sieht schon im Vorlauf Bilder (Startlage), zaehlt aber nicht.
    @ObservationIgnored private var vorbereitet: (schritt: Int, zaehler: FlowZaehler)?
    @ObservationIgnored private var bilderImSchritt = false
    @ObservationIgnored private var angehalten = false
    @ObservationIgnored private var flowPausiert = false
    @ObservationIgnored private var leerlauf: Task<Void, Never>?
    /// scenePhase != .active: keine Kamerastarts, keine Fehlersperre.
    @ObservationIgnored private var nichtAktiv = false

    /// `uhr` muss dieselbe Zeitbasis wie die Bilder haben oder wird ueber `versatz` angeglichen;
    /// `leerlaufTakt` nil schaltet den Leerlauf-Takt ab (Tests rufen `leerlaufPruefen()` selbst).
    init(flow: Flow, uebungen: FlowUebungen,
         quelle: @escaping @MainActor (KameraStart) -> any Bildquelle = Bildquellen.fuer,
         erlaubnis: @escaping () -> Kameraerlaubnis = { .aktuell },
         anfragen: @escaping () async -> Kameraerlaubnis = Kameraerlaubnis.anfragen,
         uhr: @escaping () -> TimeInterval = CACurrentMediaTime,
         leerlaufTakt: Duration? = .milliseconds(250)) {
        schritte = flow.schritte
        kameraStarts = flow.schritte.map { schritt in
            if case .kamera(let start) = uebungen.ansicht(schritt, mitKamera: true) { return start }
            return nil
        }
        hatKameraSchritt = kameraStarts.contains { $0 != nil }
        start = hatKameraSchritt ? .aufstellen : .bereit
        quellenFabrik = quelle
        self.erlaubnis = erlaubnis
        self.anfragen = anfragen
        self.uhr = uhr
        self.leerlaufTakt = leerlaufTakt
    }

    // MARK: Vor dem Start

    /// Fragt die Erlaubnis, startet die Kamera und prueft `ganzkoerper_stehend`; bestanden -> `.bereit`.
    /// Wiederholbar (Rueckkehr aus den Einstellungen oder dem Hintergrund).
    func aufstellenBeginnen() async {
        guard hatKameraSchritt, start != .bereit, start != .ohneKamera else { return }
        if kameraLaeuft, einsatz == .aufstellen { return }
        var stand = erlaubnis()
        if stand == .offen {
            stand = await anfragen()
            // Waehrend der Frage kann "Ohne Kamera starten" gekommen sein.
            guard start != .bereit, start != .ohneKamera, !kameraLaeuft else { return }
        }
        guard stand == .erlaubt else {
            start = .erlaubnisFehlt
            return
        }
        start = .aufstellen
        pruefung = Erkennungspruefung(vorgabe: Self.aufstellVorgabe)
        await kameraAn(.aufstellen, start: aufstellStart())
    }

    func ohneKameraStarten() {
        kameraAus()
        start = .ohneKamera
    }

    /// Fuer die Bildquelle (im Debug-Build spielt sie das Video dieser Uebung ab) mit der Aufstellvorgabe.
    private func aufstellStart() -> KameraStart {
        let erster = kameraStarts.compactMap { $0 }.first
        return KameraStart(exerciseId: erster?.exerciseId ?? "aufstellen", name: erster?.name ?? "Aufstellen",
                           geraet: nil, vorgabe: Self.aufstellVorgabe,
                           tempo: erster?.tempo ?? .standard(beginntMit: .senken),
                           sollWiederholungen: nil, satzZiel: 1)
    }

    // MARK: Waehrend des Flows

    /// Bei jedem Wechsel des Flow-Zustands und bei Anhalten/Weiter aufrufen.
    func folge(_ zustand: FlowZustand, pausiert: Bool) async {
        let soll = mitKamera
            ? FlowKameraPlan.soll(zustand) { [kameraStarts] in kameraStarts.indices.contains($0) && kameraStarts[$0] != nil }
            : .aus
        flowPausiert = pausiert
        if let aktiv = aktiverSchritt, soll != .zaehlen(aktiv) { schrittAbschliessen() }
        switch soll {
        case .aus:
            zielSchritt = nil
            vorbereitet = nil
            kameraAus()
            hinweisAktualisieren()
        case .vorlauf(let n):
            zielSchritt = n
            if vorbereitet?.schritt != n, let start = kameraStarts[n] {
                vorbereitet = (n, FlowZaehler(vorgabe: start.vorgabe, tempo: start.tempo))
            }
            hinweisAktualisieren()
            await schrittKameraAn(n)
        case .zaehlen(let k):
            zielSchritt = k
            if aktiverSchritt != k { schrittBeginnen(k) } else if leerlauf == nil { leerlaufStarten() }
            anhaltenAnwenden(pausiert)
            hinweisAktualisieren()
            await schrittKameraAn(k)
        }
    }

    /// scenePhase != .active: Kamera aus und zu, auch wenn die Uhr in `.inactive` weiter `folge` ruft;
    /// ein Ausfall in dieser Zeit sperrt keinen Schritt. Zurueck in `.active` darf `folge` sie wieder starten.
    func szeneAktiv(_ aktiv: Bool) {
        nichtAktiv = !aktiv
        if !aktiv { kameraAus() }
    }

    /// Kamera aus und Leerlauf-Takt beendet (Abbrechen, Fertig, Verlassen); der Stand der Zaehlung bleibt,
    /// der Idle-Timer unberuehrt. Ein spaeteres `folge` in einer Arbeitsphase startet beides wieder.
    func schliessen() {
        kameraAus()
        leerlauf?.cancel()
        leerlauf = nil
    }

    /// Ob der Leerlauf-Takt laeuft (fuer Tests).
    var leerlaufLaeuft: Bool { leerlauf != nil }

    /// Ohne Bilder (Kamera aus, gescheitert, Bildrate eingebrochen) bekommt der Zaehler die Uhr als leeres Bild:
    /// so laufen Welle und Hinweis weiter. Ruft der Leerlauf-Takt auf.
    func leerlaufPruefen() {
        guard var z = zaehler, !angehalten else { return }
        let jetzt = uhr()
        if kameraLaeuft, let letzter = letzterBildEmpfang, jetzt - letzter < Self.bildluecke { return }
        z.bild(t: jetzt, skelett: nil)
        zaehler = z
        letztesSkelett = nil
        hinweisAktualisieren()
    }

    private func schrittBeginnen(_ k: Int) {
        guard let start = kameraStarts[k] else { return }
        var z = FlowZaehler(vorgabe: start.vorgabe, tempo: start.tempo)
        if let v = vorbereitet, v.schritt == k { z = v.zaehler }
        vorbereitet = nil
        z.start(t: uhr())
        zaehler = z
        aktiverSchritt = k
        bilderImSchritt = false
        angehalten = false
        leerlaufStarten()
    }

    private func schrittAbschliessen() {
        if let k = aktiverSchritt, let z = zaehler, bilderImSchritt { gezaehlt[k] = z.wiederholungen }
        leerlauf?.cancel()
        leerlauf = nil
        zaehler = nil
        aktiverSchritt = nil
        bilderImSchritt = false
        angehalten = false
    }

    private func anhaltenAnwenden(_ pausiert: Bool) {
        guard var z = zaehler, pausiert != angehalten else { return }
        if pausiert { z.anhalten(t: uhr()) } else { z.fortsetzen(t: uhr()) }
        zaehler = z
        angehalten = pausiert
    }

    private func leerlaufStarten() {
        leerlauf?.cancel()
        guard let takt = leerlaufTakt else { return }
        leerlauf = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: takt)
                guard !Task.isCancelled, let self else { return }
                self.leerlaufPruefen()
            }
        }
    }

    private func hinweisAktualisieren() {
        let gescheitert = zielSchritt != nil && fehlerSchritt == zielSchritt
        let neu = gescheitert || zaehler?.erkannt == false ? Self.hinweisText : nil
        if hinweis != neu { hinweis = neu }
    }

    // MARK: Kamera

    private func schrittKameraAn(_ i: Int) async {
        guard let start = kameraStarts[i], fehlerSchritt != i else { return }
        await kameraAn(.schritt(i), start: start)
    }

    /// Eine andere Uebung bekommt eine eigene Quelle (die Abspielquelle zeigt die Uebung des Schritts).
    private func kameraAn(_ neu: Einsatz, start: KameraStart) async {
        if kameraLaeuft, einsatz == neu { return }
        guard !nichtAktiv else { return }
        kameraAus()
        startNummer += 1
        let nummer = startNummer
        let quelle: any Bildquelle
        if let letzte = letzteQuelle, letzte.exerciseId == start.exerciseId {
            quelle = letzte.quelle
        } else {
            quelle = quellenFabrik(start)
            letzteQuelle = (start.exerciseId, quelle)
        }
        aktiveQuelle = quelle
        einsatz = neu
        kameraLaeuft = true
        versatz = nil
        letzterBildEmpfang = nil
        quelle.beiFehler = { [weak self] in self?.kameraAusgefallen(nummer: nummer) }
        do {
            try await quelle.starten { [weak self] bild in self?.bildEmpfangen(bild, nummer: nummer) }
            // Ein Stopp kam dazwischen und hat eine andere Quelle hinterlassen: diese wieder aus.
            if nummer != startNummer, aktiveQuelle !== quelle { quelle.stoppen() }
        } catch {
            guard nummer == startNummer else { return }
            kameraAus()
            gescheitert(neu, nichtErlaubt: (error as? BildquellenFehler) == .nichtErlaubt)
        }
    }

    private func kameraAus() {
        startNummer += 1
        kameraLaeuft = false
        aktiveQuelle?.stoppen()
        aktiveQuelle = nil
        einsatz = nil
        letztesSkelett = nil
    }

    /// Kann fuer einen Ausfall zweimal kommen; das zweite Mal ist wirkungslos.
    private func kameraAusgefallen(nummer: Int) {
        guard nummer == startNummer, kameraLaeuft, let betroffen = einsatz else { return }
        kameraAus()
        gescheitert(betroffen, nichtErlaubt: false)
    }

    private func gescheitert(_ betroffen: Einsatz, nichtErlaubt: Bool) {
        // Ausserhalb von .active beendet das System die Kamera; das ist kein Fehler des Schritts.
        guard !nichtAktiv else { return }
        switch betroffen {
        case .aufstellen:
            if start == .aufstellen { start = nichtErlaubt ? .erlaubnisFehlt : .kameraFehlt }
        case .schritt(let i):
            fehlerSchritt = i
            hinweisAktualisieren()
        }
    }

    // MARK: Bilder

    private func bildEmpfangen(_ bild: Kamerabild, nummer: Int) {
        guard nummer == startNummer, kameraLaeuft, let einsatz else { return }
        let jetzt = uhr()
        let versatz = self.versatz ?? jetzt - bild.t
        self.versatz = versatz
        let t = bild.t + versatz
        letzterBildEmpfang = jetzt
        letztesSkelett = bild.skelett
        switch einsatz {
        case .aufstellen:
            pruefung.eingabe(t: t, skelett: bild.skelett)
            if pruefung.bestanden, start == .aufstellen {
                kameraAus()
                start = .bereit
            }
        case .schritt(let i):
            guard !flowPausiert else { return }
            if i == aktiverSchritt, var z = zaehler {
                z.bild(t: t, skelett: bild.skelett)
                zaehler = z
                bilderImSchritt = true
                hinweisAktualisieren()
            } else if var v = vorbereitet, v.schritt == i {
                v.zaehler.bild(t: t, skelett: bild.skelett)
                vorbereitet = v
            }
        }
    }
}
