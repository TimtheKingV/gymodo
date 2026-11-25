import Foundation
import Koerperbild
import Observation
import UIKit

/// Verbindet Bildquelle, Zustandsmaschine und Geraete-Naht fuer die Vollbild-Ansichten des
/// Kamera-Ablaufs. Gesichert wird ausschliesslich ueber die Naht, sofort am Satzende; ein
/// Kamerafehler verliert nie einen Satz (die Maschine bleibt, `ohneKamera()` nimmt die Zahl mit).
@MainActor @Observable
final class KameraAblaufModell {
    enum Ansicht: Equatable {
        /// 7.1 mit Weg in die Einstellungen.
        case erlaubnisFehlt
        /// Kamera nicht verfuegbar oder ausgefallen.
        case kameraFehlt
        /// Der Schritt steht in `ablauf.schritt`.
        case ablauf
        /// Nach dem Sichern.
        case rueckblick(Rueckblickdaten)
    }

    struct Rueckblickdaten: Equatable {
        let wiederholungen: Int
        let rueckblick: Koerperbild.Rueckblick?
        /// Grund, wenn das Sichern abgelehnt wurde; der Rueckblick erscheint trotzdem.
        let abgelehnt: String?
        let letzterSatz: Bool
        let tempo: Uebungstempo
    }

    private(set) var ansicht: Ansicht = .ablauf
    private(set) var ablauf: KameraSatzAblauf?
    var videoOffen = false
    var quelle: (any Bildquelle)? { aktiveQuelle }

    private let naht: any KameraNaht
    private let quellenFabrik: @MainActor (KameraStart) -> any Bildquelle
    private let hub: Hubspeicher
    private let erlaubnis: () -> Kameraerlaubnis
    private let anfragen: () async -> Kameraerlaubnis
    private let idleTimer: @MainActor (Bool) -> Void

    private var start: KameraStart?
    private var aktiveQuelle: (any Bildquelle)?
    private var kameraLaeuft = false
    /// Zaehlt Starts und Stopps; ein Start, der nach einem Stopp zurueckkehrt, gilt nicht mehr.
    private var startNummer = 0
    /// Wahr, sobald das Satzende der aktuellen Maschine behandelt wird (genau einmal sichern).
    private var satzendeBehandelt = false
    private var pausenwaechter: Task<Void, Never>?

    init(naht: any KameraNaht,
         quelle: @escaping @MainActor (KameraStart) -> any Bildquelle = Bildquellen.fuer,
         hub: Hubspeicher = .standard,
         erlaubnis: @escaping () -> Kameraerlaubnis = { .aktuell },
         anfragen: @escaping () async -> Kameraerlaubnis = Kameraerlaubnis.anfragen,
         idleTimer: @escaping @MainActor (Bool) -> Void = { UIApplication.shared.isIdleTimerDisabled = $0 }) {
        self.naht = naht
        self.quellenFabrik = quelle
        self.hub = hub
        self.erlaubnis = erlaubnis
        self.anfragen = anfragen
        self.idleTimer = idleTimer
    }

    // MARK: Einstieg

    func erscheint() async {
        guard let start = naht.kameraStart else {
            naht.kameraVerlassen(gezaehlt: nil)
            return
        }
        self.start = start
        idleTimer(true)
        let mitVideo = naht.kameraEinstieg == .video
        neuerAblauf(mitVideo: mitVideo)
        videoOffen = mitVideo
        ansicht = .ablauf
        if !mitVideo { await kameraStarten() }
    }

    func handyAufstellen() async {
        ablauf?.handyAufstellen()
        videoOffen = false
        await kameraStarten()
    }

    func ohneKamera() {
        ablauf?.ohneKamera()
        satzendePruefen()
    }

    func satzBeenden() async {
        ablauf?.satzBeenden()
        await satzendeAbarbeiten()
    }

    func abbrechen() { ablauf?.abbrechen() }

    func neuStarten() { ablauf?.neuStarten() }

    // MARK: Rueckblick

    func naechsterSatz() async {
        guard case .rueckblick(let daten) = ansicht else { return }
        if daten.letzterSatz { naht.weitererSatz() } else { naht.pauseBeenden() }
        await naechstenSatzBeginnen()
    }

    func rueckblickSchliessen() { naht.kameraAblaufSchliessen() }

    func umfangKorrigieren(_ n: Int) {
        naht.umfangNachtragen(n)
        guard case .rueckblick(let d) = ansicht else { return }
        ansicht = .rueckblick(Rueckblickdaten(wiederholungen: n, rueckblick: d.rueckblick, abgelehnt: d.abgelehnt,
                                              letzterSatz: d.letzterSatz, tempo: d.tempo))
    }

    // MARK: Lebenszyklus

    func szene(aktiv: Bool) {
        if !aktiv {
            ablauf?.unterbrechen()
            kameraStoppen()
        } else if ansicht == .ablauf, !kameraLaeuft, let schritt = ablauf?.schritt, Self.bildSchritt(schritt) {
            Task { await kameraStarten() }
        } else if ansicht == .erlaubnisFehlt, erlaubnis() == .erlaubt {
            // Zurueck aus den Einstellungen mit erteilter Erlaubnis.
            ansicht = .ablauf
            Task { await kameraStarten() }
        }
    }

    func verschwindet() {
        pausenwaechter?.cancel()
        pausenwaechter = nil
        kameraStoppen()
        idleTimer(false)
    }

    // MARK: Kamera

    /// Die Schritte, in denen die Kamera laeuft.
    private static func bildSchritt(_ schritt: KameraSatzAblauf.Schritt) -> Bool {
        switch schritt {
        case .aufstellen, .countdown, .satz, .verloren, .vorlauf, .keineBewegung: true
        case .video, .bewegungZuKlein, .fertig: false
        }
    }

    private func kameraStarten() async {
        guard let start, !kameraLaeuft else { return }
        var stand = erlaubnis()
        if stand == .offen { stand = await anfragen() }
        guard stand == .erlaubt else {
            ansicht = .erlaubnisFehlt
            return
        }
        let quelle = aktiveQuelle ?? quellenFabrik(start)
        aktiveQuelle = quelle
        quelle.beiFehler = { [weak self] in self?.kameraAusgefallen() }
        startNummer += 1
        let nummer = startNummer
        kameraLaeuft = true
        do {
            try await quelle.starten { [weak self] bild in self?.bildEmpfangen(bild) }
        } catch is CancellationError {
            // Ein Stopp kam dazwischen; der Zustand gehoert dem, der gestoppt hat.
            return
        } catch let fehler as BildquellenFehler {
            guard nummer == startNummer else { return }
            kameraLaeuft = false
            ansicht = fehler == .nichtErlaubt ? .erlaubnisFehlt : .kameraFehlt
        } catch {
            guard nummer == startNummer else { return }
            kameraLaeuft = false
            ansicht = .kameraFehlt
        }
    }

    private func kameraStoppen() {
        startNummer += 1
        kameraLaeuft = false
        aktiveQuelle?.stoppen()
    }

    /// Kann fuer einen Ausfall zweimal kommen; das zweite Mal ist wirkungslos.
    private func kameraAusgefallen() {
        guard ansicht == .ablauf, kameraLaeuft else { return }
        kameraStoppen()
        ansicht = .kameraFehlt
    }

    // MARK: Bilder und Satzende

    private func bildEmpfangen(_ bild: Kamerabild) {
        guard ansicht == .ablauf, kameraLaeuft, var maschine = ablauf else { return }
        if case .fertig = maschine.schritt { return }
        maschine.bild(t: bild.t, skelett: bild.skelett)
        ablauf = maschine
        satzendePruefen()
    }

    /// Reagiert auf den neuen Schritt: Kamera aus ausserhalb der Bild-Schritte, Satzende abarbeiten.
    private func satzendePruefen() {
        guard let schritt = ablauf?.schritt else { return }
        if !Self.bildSchritt(schritt), kameraLaeuft { kameraStoppen() }
        if case .fertig = schritt { Task { await satzendeAbarbeiten() } }
    }

    private func satzendeAbarbeiten() async {
        guard case .fertig(let ende)? = ablauf?.schritt, !satzendeBehandelt, let start else { return }
        satzendeBehandelt = true
        kameraStoppen()
        switch ende {
        case .ohneKamera(let gezaehlt):
            naht.kameraVerlassen(gezaehlt: gezaehlt)
        case .beendet(let ergebnis):
            if let grad = ergebnis.hubGrad { hub.merken(grad, fuer: start.exerciseId) }
            let sichern = await naht.kameraSatzSichern(wiederholungen: ergebnis.wiederholungen)
            var abgelehnt: String?
            var letzterSatz = false
            switch sichern {
            case .gesichert(let letzter): letzterSatz = letzter
            case .abgelehnt(let grund): abgelehnt = grund
            }
            ansicht = .rueckblick(Rueckblickdaten(wiederholungen: ergebnis.wiederholungen, rueckblick: ergebnis.rueckblick,
                                                  abgelehnt: abgelehnt, letzterSatz: letzterSatz, tempo: start.tempo))
            pauseBeobachten()
        }
    }

    // MARK: Naechster Satz

    /// Laeuft die Pause ab, beginnt der naechste Satz von selbst; verlaengert sie sich, wartet der Task weiter.
    private func pauseBeobachten() {
        pausenwaechter?.cancel()
        pausenwaechter = Task { [weak self] in
            while !Task.isCancelled, let self, case .rueckblick = self.ansicht,
                  let ende = self.naht.laufendePause?.endetAm {
                let rest = ende.timeIntervalSinceNow
                if rest > 0 {
                    try? await Task.sleep(for: .seconds(rest))
                    continue
                }
                self.naht.pauseBeenden()
                await self.naechstenSatzBeginnen()
                return
            }
        }
    }

    private func naechstenSatzBeginnen() async {
        // Zweiter Aufruf (Tippen und Pausenende zugleich) ist wirkungslos: die Ansicht wechselt vor dem ersten await.
        guard case .rueckblick = ansicht else { return }
        pausenwaechter?.cancel()
        pausenwaechter = nil
        neuerAblauf(mitVideo: false)
        ansicht = .ablauf
        await kameraStarten()
    }

    private func neuerAblauf(mitVideo: Bool) {
        guard let start else { return }
        ablauf = KameraSatzAblauf(vorgabe: start.vorgabe, tempo: start.tempo,
                                  gemerkterHub: hub.hub(start.exerciseId), mitVideo: mitVideo)
        satzendeBehandelt = false
    }
}
