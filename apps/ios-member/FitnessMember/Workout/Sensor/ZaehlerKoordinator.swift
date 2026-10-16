#if DEBUG
import Foundation
import Observation
import Sensorik

/// Erfuellt die Naht SatzZaehler (Sensor-Spec B 6.4): hoert auf den
/// Messwert-Strom, baut je Satz einen Zaehler mit dem Profil der Art und
/// uebersetzt seine Ereignisse in Meldungen.
///
/// Unabhaengig vom SensorAufnahmeKoordinator; beide hoeren parallel, jeder
/// mit eigenem Strom (SensorVerteiler).
@MainActor
@Observable
final class ZaehlerKoordinator: SatzZaehler {
    let quelle: any SensorQuelle
    /// Fuer die Sensor-Zeile. nil, solange kein Satz offen ist.
    private(set) var meldung: ZaehlerMeldung?
    private(set) var befestigung: BefestigungsWahl?

    @ObservationIgnored private let speicher: Befestigungsspeicher
    @ObservationIgnored private let uhr: () -> TimeInterval
    @ObservationIgnored private var kontext: SatzZaehlerKontext?
    @ObservationIgnored private var melde: (@MainActor (ZaehlerMeldung) -> Void)?
    @ObservationIgnored private var zaehler: Zaehler?
    @ObservationIgnored private var satzbeginn: TimeInterval = 0
    @ObservationIgnored private var ereignisse: [ZaehlerEreignis] = []
    /// Alle Messwerte des Satzes, nur an der Kurzhantel: dort zaehlt am
    /// Satzende die Takt-Auswertung (Satztakt) und ersetzt die Live-Zahl.
    @ObservationIgnored private var satzMesswerte: [SensorMesswert] = []
    @ObservationIgnored private var lauscher: Task<Void, Never>?

    init(quelle: any SensorQuelle, einstellungen: UserDefaults = .standard,
         uhr: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.quelle = quelle
        self.speicher = Befestigungsspeicher(einstellungen: einstellungen)
        self.uhr = uhr
    }

    /// Einmal beim App-Start; getrennt vom init, damit Tests `empfangen`
    /// direkt und in fester Reihenfolge rufen koennen.
    func starten() {
        guard lauscher == nil else { return }
        let strom = quelle.ereignisse()
        lauscher = Task { [weak self] in
            for await ereignis in strom { self?.empfangen(ereignis) }
        }
    }

    // MARK: - SatzZaehler

    func satzBeginnt(_ kontext: SatzZaehlerKontext, melde: @escaping @MainActor (ZaehlerMeldung) -> Void) {
        self.kontext = kontext
        self.melde = melde
        befestigung = speicher.wahl(fuer: kontext)
        neuStarten()
    }

    func ergebnis() -> ZaehlerErgebnis? {
        defer { beenden() }
        guard var zaehler, let art = befestigung?.art else { return nil }
        ereignisse += zaehler.abschliessen()
        if art == .kurzhantel, let takt = Satztakt.auswerten(satzMesswerte, rateHz: Double(quelle.rate.rawValue)) {
            let wiederholungen = Satztakt.wiederholungen(takt).map { ZaehlerEreignis.wiederholung($0) }
            return ZaehlerErgebnis(
                gezaehlt: takt.anzahl,
                repEvents: RepEvents(algo: Satztakt.algo, befestigungsart: art,
                                     ereignisse: wiederholungen + [.zuende], satzbeginn: satzbeginn))
        }
        let gezaehlt = zaehler.anzahl
        guard gezaehlt > 0 else { return nil }
        return ZaehlerErgebnis(
            gezaehlt: gezaehlt,
            repEvents: RepEvents(algo: zaehler.profil.algo, befestigungsart: art,
                                 ereignisse: ereignisse, satzbeginn: satzbeginn))
    }

    func satzVerworfen() { beenden() }

    /// Ein Tipp in der Sensor-Zeile. Mit der neuen Art beginnt die Zaehlung
    /// von vorn: was bisher gezaehlt wurde, lief mit dem falschen Profil.
    func befestigungWaehlen(_ art: Befestigungsart) {
        guard let kontext else { return }
        speicher.merken(art, fuer: kontext)
        befestigung = BefestigungsWahl(art: art, quelle: .gewaehlt)
        neuStarten()
    }

    // MARK: - Eingang

    func empfangen(_ ereignis: SensorEreignis) {
        switch ereignis {
        case .messwert(let messwert):
            // Ein Paket von vor dem Satzbeginn kann noch im Strom stecken;
            // es gehoert nicht zum Satz.
            guard var zaehler, messwert.t >= satzbeginn else { return }
            if befestigung?.art == .kurzhantel { satzMesswerte.append(messwert) }
            let neu = zaehler.verarbeite(messwert)
            self.zaehler = zaehler
            weitergeben(neu)
        case .zustand(let zustand):
            if zustand.istVerbunden {
                // Nur wenn der Satz mangels Sensor noch nicht zaehlte (Spec 9).
                // Nach einer Luecke wird nicht weitergezaehlt.
                if zaehler == nil, kontext != nil, meldung == .zaehltNicht(.keinSensor) { neuStarten() }
            } else if var zaehler {
                // Der Strom liefert Zustaende verspaetet: ist die Quelle schon
                // wieder verbunden, gehoert die Trennung zu einem frueheren
                // Moment und haelt diesen Satz nicht an.
                guard !quelle.zustand.istVerbunden else { return }
                guard zaehler.anzahl > 0 else {
                    // Vor der ersten Wiederholung gibt es nichts zu schuetzen:
                    // wie ohne Sensor, beim Wiederverbinden beginnt der Satz
                    // in bereit (Spec B 9, erste Zeile).
                    self.zaehler = nil
                    ereignisse = []
                    return senden(.zaehltNicht(.keinSensor))
                }
                let jetzt = uhr()
                let neu = zaehler.luecke(von: jetzt, bis: jetzt)
                self.zaehler = zaehler
                weitergeben(neu)
            }
        case .akku:
            break
        }
    }

    // MARK: - Intern

    private func neuStarten() {
        zaehler = nil
        ereignisse = []
        satzMesswerte = []
        guard let kontext else { return }
        guard kontext.volumeKind == .reps else { return senden(.zaehltNicht(.keineWiederholungen)) }
        guard let art = befestigung?.art else { return senden(.zaehltNicht(.keineBefestigung)) }
        guard quelle.zustand.istVerbunden else { return senden(.zaehltNicht(.keinSensor)) }
        // Debug zaehlt jede Art, auch nicht freigegebene (Nachtrag 14.10. Punkt 4).
        zaehler = Zaehler(profil: .fuer(art), rateHz: Double(quelle.rate.rawValue))
        satzbeginn = uhr()
        senden(.bereit)
    }

    private func weitergeben(_ neu: [ZaehlerEreignis]) {
        for ereignis in neu {
            ereignisse.append(ereignis)
            switch ereignis {
            case .wiederholung(let w): senden(.stand(w.nummer))
            case .unsicher(let grund): senden(.pruefen(zaehler?.anzahl ?? 0, grund))
            case .zuende: break
            }
        }
    }

    private func senden(_ neu: ZaehlerMeldung) {
        meldung = neu
        melde?(neu)
    }

    /// Die Art bleibt stehen: die Aufnahme liest sie nach ergebnis().
    private func beenden() {
        zaehler = nil
        kontext = nil
        melde = nil
        meldung = nil
        ereignisse = []
        satzMesswerte = []
    }
}
#endif
