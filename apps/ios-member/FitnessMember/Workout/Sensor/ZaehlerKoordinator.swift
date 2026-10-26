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
    private let einstellungen: UserDefaults
    var automatikAktiv: Bool {
        didSet {
            einstellungen.set(!automatikAktiv, forKey: "sensor.automatikAus")
            automatik = SatzAutomatik()
            automatikAusgewertetBis = nil
            aktivesModell?.automatikUmschalten(aktiv: automatikAktiv)
            gehaltenerKontext = automatikAktiv ? besitzer : nil
        }
    }
    private(set) var automatik = SatzAutomatik()
    @ObservationIgnored private var automatischerBeginn: TimeInterval?
    @ObservationIgnored private var automatikAusgewertetBis: TimeInterval?
    @ObservationIgnored private var automatikLueckenKennung = 0
    @ObservationIgnored private var vorherigerMesswert: SensorMesswert?
    @ObservationIgnored private var automatikMelden: (@MainActor (SatzAutomatik.Ereignis) -> Void)?
    /// Der Kontext lebt am Sensor, unabhaengig davon, ob SwiftUI sichtbar ist.
    @ObservationIgnored private weak var besitzer: GeraetModel?
    @ObservationIgnored private var gehaltenerKontext: GeraetModel?
    var aktivesModell: GeraetModel? {
        get { besitzer }
        set {
            besitzer = newValue
            gehaltenerKontext = automatikAktiv ? newValue : nil
        }
    }

    func automatikBeobachten(_ melde: (@MainActor (SatzAutomatik.Ereignis) -> Void)?) {
        automatikMelden = melde
    }

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
    /// Messwerte des Satzes, nur fuer Arten mit Takt-Profil: dort zaehlt am
    /// Satzende die Takt-Auswertung (Satztakt) und ersetzt die Live-Zahl.
    /// Hoechstens `fensterS` Sekunden: die Auswertung waechst quadratisch mit
    /// der Satzlaenge (Mac, Release: 4 min = 0,5 s, Debug rund das 70-Fache).
    /// Danach rechnet der Takt nicht mehr; gespeichert wird seine letzte fertige
    /// Zahl (die das Rad zeigt), nicht die Live-Zahl.
    @ObservationIgnored private var satzMesswerte: [SensorMesswert] = []
    @ObservationIgnored private var satzZuLang = false
    @ObservationIgnored private var hatLuecke = false
    @ObservationIgnored private var trennstellen: [Int] = []
    @ObservationIgnored private var letzterMesswert: TimeInterval?
    private let fensterS: TimeInterval
    var satzMesswerteAnzahl: Int { satzMesswerte.count }
    /// Wie oft ergebnis() selbst rechnen musste statt die fertige Live-Auswertung zu nehmen (Tests).
    @ObservationIgnored private(set) var syncAuswertungen = 0
    /// Neueste fertige Auswertung und die Zahl der Messwerte, auf denen sie beruht.
    @ObservationIgnored private var taktErgebnis: Satztakt.Ergebnis?
    @ObservationIgnored private var taktWerte = 0
    /// Testnotiz 16.10., #4: das Rad folgte der Live-Zahl (in 1421-03 eine
    /// 1), gespeichert wurde sie neben der Takt-Zahl 8 als "korrigiert".
    /// Seither zaehlt der Takt auch waehrend des Satzes. Er kostet im
    /// Debug-Build rund 0,8 s je Auswertung (37-s-Satz, Mac) und laeuft
    /// deshalb abseits des Main Actors, nie zwei auf einmal.
    @ObservationIgnored private var taktStand: Int?
    @ObservationIgnored private var taktLaeuft = false
    @ObservationIgnored private var taktBis: TimeInterval = 0
    /// Steigt mit jedem Satz: ein spaetes Ergebnis gehoert sonst zum falschen.
    @ObservationIgnored private var satzKennung = 0
    @ObservationIgnored private var lauscher: Task<Void, Never>?

    init(quelle: any SensorQuelle, einstellungen: UserDefaults = .standard,
         uhr: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         fensterS: TimeInterval = 150) {
        self.einstellungen = einstellungen
        self.automatikAktiv = !einstellungen.bool(forKey: "sensor.automatikAus")
        self.fensterS = fensterS
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
        if let takt = taktAmSatzende(art: art) {
            let reps = Satztakt.wiederholungen(takt)
            let wiederholungen = reps.map { ZaehlerEreignis.wiederholung($0) }
            let grund: UnsicherGrund? = hatLuecke || takt.hatLuecke ? .luecke
                : (takt.guete <= Satztakt.unsicherGrenze ? .signalSchwach : nil)
            let unsicher: [ZaehlerEreignis] = grund.map { [.unsicher($0)] } ?? []
            return ZaehlerErgebnis(
                gezaehlt: takt.anzahl,
                repEvents: RepEvents(algo: Satztakt.algo(fuer: art), befestigungsart: art,
                                     ereignisse: wiederholungen + unsicher + [.zuende], satzbeginn: satzbeginn))
        }
        let gezaehlt = automatischerBeginn != nil
            ? ereignisse.filter { if case .wiederholung = $0 { true } else { false } }.count
            : zaehler.anzahl
        guard gezaehlt > 0 else { return nil }
        return ZaehlerErgebnis(
            gezaehlt: gezaehlt,
            repEvents: RepEvents(algo: zaehler.profil.algo, befestigungsart: art,
                                 ereignisse: ereignisse + (hatLuecke ? [.unsicher(.luecke)] : []), satzbeginn: satzbeginn))
    }

    /// Die fertige Live-Auswertung, wenn sie den Satz bis auf drei Sekunden
    /// gesehen hat; sonst rechnet das Satzende selbst (Main Actor).
    private func taktAmSatzende(art: Befestigungsart) -> Satztakt.Ergebnis? {
        guard let profil = TaktProfil.fuer(art) else { return nil }
        if satzZuLang { return taktErgebnis }
        let rate = Double(quelle.rate.rawValue)
        if !hatLuecke, let taktErgebnis, satzMesswerte.count - taktWerte <= Int(3 * rate) { return taktErgebnis }
        syncAuswertungen += 1
        return Satztakt.auswerten(satzMesswerte, rateHz: rate, profil: profil, trennstellen: trennstellen)
    }

    func satzVerworfen() { beenden() }

    /// Ein Tipp in der Sensor-Zeile. Mit der neuen Art beginnt die Zaehlung
    /// von vorn: was bisher gezaehlt wurde, lief mit dem falschen Profil.
    func befestigungWaehlen(_ art: Befestigungsart) {
        guard let kontext else { return }
        speicher.merken(art, fuer: kontext)
        befestigung = BefestigungsWahl(art: art, quelle: .gewaehlt)
        aktivesModell?.automatikUnterbrochen()
        neuStarten()
    }

    // MARK: - Eingang

    func empfangen(_ ereignis: SensorEreignis) {
        switch ereignis {
        case .messwert(let messwert):
            // Ein Paket von vor dem Satzbeginn kann noch im Strom stecken;
            // es gehoert nicht zum Satz.
            if automatikAktiv, automatikMelden != nil,
               automatik.zustand == .wartet
                || (automatik.zustand == .startkandidat && messwert.t - (automatik.letzteBewegung ?? messwert.t) > 8),
               messwert.t - satzbeginn > 30, kontext != nil {
                let vorlauf = automatik.vorlauf.filter { $0.t >= messwert.t - 5 }
                neuStarten()
                satzbeginn = vorlauf.first?.t ?? messwert.t
                for wert in vorlauf { empfangen(.messwert(wert)) }
            }
            guard var zaehler, messwert.t >= satzbeginn else { return }
            if let letzterMesswert, messwert.t - letzterMesswert > Satztakt.lueckeAb {
                lueckeMerken()
            }
            let vorher = vorherigerMesswert
            if vorher.map({ messwert.t - $0.t >= 0.2 }) ?? true { vorherigerMesswert = messwert }
            automatik.empfangen(messwert)
            if let vorher {
                let a = messwert.beschleunigung, b = vorher.beschleunigung, d = messwert.drehrate
                let delta = abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z)
                if delta > 0.01 || max(abs(d.x), abs(d.y), abs(d.z)) > 8 {
                    automatik.bewegung(bis: messwert.t)
                }
            }
            letzterMesswert = messwert.t
            if let art = befestigung?.art, TaktProfil.fuer(art) != nil, !satzZuLang {
                satzMesswerte.append(messwert)
                begrenzen()
            }
            let neu = zaehler.verarbeite(messwert)
            self.zaehler = zaehler
            weitergeben(neu)
            if befestigung.map({ TaktProfil.fuer($0.art) == nil }) == true {
                automatikEreignisse(neu.compactMap { if case .wiederholung(let w) = $0 { w } else { nil } }, bis: messwert.t)
            }
            taktAnstossen()
            if automatikAktiv, let bis = automatikAusgewertetBis,
               let ende = automatik.ausgewertet(bis: bis) { automatikMelden?(ende) }
        case .zustand(let zustand):
            if zustand.istVerbunden {
                // Nur wenn der Satz mangels Sensor noch nicht zaehlte (Spec 9).
                // Ohne bisherige Messwerte kann nach dem Verbinden neu begonnen werden.
                if zaehler == nil, kontext != nil, meldung == .zaehltNicht(.keinSensor) { neuStarten() }
            } else if var zaehler {
                // Der Strom liefert Zustaende verspaetet: ist die Quelle schon
                // wieder verbunden, gehoert die Trennung zu einem frueheren
                // Moment und haelt diesen Satz nicht an.
                guard !quelle.zustand.istVerbunden else { return }
                guard letzterMesswert != nil else {
                    // Vor dem ersten Messwert gibt es nichts zu schuetzen:
                    // wie ohne Sensor, beim Wiederverbinden beginnt der Satz
                    // in bereit (Spec B 9, erste Zeile).
                    self.zaehler = nil
                    ereignisse = []
                    return senden(.zaehltNicht(.keinSensor))
                }
                lueckeMerken()
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
        automatik = SatzAutomatik()
        automatischerBeginn = nil
        automatikAusgewertetBis = nil
        vorherigerMesswert = nil
        zaehler = nil
        ereignisse = []
        satzMesswerte = []
        satzZuLang = false
        hatLuecke = false
        trennstellen = []
        letzterMesswert = nil
        syncAuswertungen = 0
        taktZuruecksetzen()
        guard let kontext else { return }
        guard kontext.volumeKind == .reps else { return senden(.zaehltNicht(.keineWiederholungen)) }
        guard let art = befestigung?.art else { return senden(.zaehltNicht(.keineBefestigung)) }
        guard quelle.zustand.istVerbunden else { return senden(.zaehltNicht(.keinSensor)) }
        // Debug zaehlt jede Art, auch nicht freigegebene (Nachtrag 14.10. Punkt 4).
        zaehler = Zaehler(profil: .fuer(art), rateHz: Double(quelle.rate.rawValue))
        satzbeginn = uhr()
        senden(.bereit)
    }

    /// Altes vom Anfang abschneiden, in Schritten, damit nicht jeder Messwert
    /// das ganze Feld verschiebt. Danach gilt der Satz als zu lang fuer den Takt.
    private func begrenzen() {
        let grenze = Int(fensterS * Double(quelle.rate.rawValue))
        guard satzMesswerte.count > grenze + 250 else { return }
        let entfernt = satzMesswerte.count - grenze
        satzMesswerte.removeFirst(entfernt)
        trennstellen = trennstellen.filter { $0 >= entfernt }.map { $0 - entfernt }
        satzZuLang = true
    }

    /// Hoechstens einmal je Sekunde Messzeit und nie neben einer laufenden
    /// Auswertung; wer waehrenddessen kam, ist bei der naechsten dabei.
    private func taktAnstossen() {
        guard let art = befestigung?.art, let profil = TaktProfil.fuer(art), !taktLaeuft, !satzZuLang,
              let letzter = satzMesswerte.last, letzter.t - taktBis >= 1 else { return }
        taktLaeuft = true
        taktBis = letzter.t
        let kopie = satzMesswerte, grenzen = trennstellen, rate = Double(quelle.rate.rawValue), kennung = satzKennung, lueckenKennung = automatikLueckenKennung
        Task { [weak self] in
            let ergebnis = await Task.detached(priority: .userInitiated) {
                Satztakt.auswerten(kopie, rateHz: rate, profil: profil, trennstellen: grenzen)
            }.value
            self?.taktFertig(ergebnis, werte: kopie.count, kennung: kennung, lueckenKennung: lueckenKennung)
        }
    }

    private func taktFertig(_ ergebnis: Satztakt.Ergebnis?, werte: Int, kennung: Int, lueckenKennung: Int) {
        guard kennung == satzKennung else { return }
        taktLaeuft = false
        if let ergebnis { taktErgebnis = ergebnis; taktWerte = werte } else if !satzZuLang { taktErgebnis = nil }
        if let anzahl = ergebnis?.anzahl, anzahl > 0, anzahl != taktStand {
            taktStand = anzahl
            senden(.stand(anzahl))
        }
        if lueckenKennung == automatikLueckenKennung, let bis = satzMesswerte.prefix(werte).last?.t {
            automatikEreignisse(ergebnis.map(Satztakt.wiederholungen) ?? [], bis: bis)
        }
        taktAnstossen()
    }

    private func automatikEreignisse(_ wiederholungen: [Wiederholung], bis: TimeInterval) {
        guard automatikAktiv, automatikMelden != nil, aktivesModell?.hatAutomatikStartwerte != false else { return }
        let ereignisse = automatik.wiederholungen(wiederholungen)
        for ereignis in ereignisse {
            if case .begonnen(_, let beginn, _) = ereignis {
                // Der begrenzte Vorlauf gehoert jetzt diesem Satz. Einzelne
                // fruehere Bewegungen duerfen dessen Endzahl nicht erhoehen.
                // Tiefpass und Schwerkraft-Schaetzung brauchen ihren
                // Einschwingbereich. Nur der Mitschnitt beginnt exakt an
                // der ersten Wiederholung; die Auswertung behaelt 5 s Kontext.
                let auswertungAb = beginn - 5
                let entfernt = satzMesswerte.prefix { $0.t < auswertungAb }.count
                satzMesswerte.removeFirst(entfernt)
                trennstellen = trennstellen.filter { $0 >= entfernt }.map { $0 - entfernt }
                self.ereignisse.removeAll {
                    if case .wiederholung(let w) = $0 { return w.beginn < beginn }
                    return false
                }
                satzbeginn = beginn
                automatischerBeginn = beginn
                taktZuruecksetzen()
            }
            automatikMelden?(ereignis)
        }
        automatikAusgewertetBis = bis
    }

    private func weitergeben(_ neu: [ZaehlerEreignis]) {
        for ereignis in neu {
            ereignisse.append(ereignis)
            switch ereignis {
            // Sobald der Takt zaehlt, fuehrt er das Rad; vorher die Live-Zahl.
            case .wiederholung(let w): if taktStand == nil { senden(.stand(w.nummer)) }
            case .unsicher(let grund): senden(.pruefen(taktStand ?? zaehler?.anzahl ?? 0, grund))
            case .zuende: break
            }
        }
    }

    private func lueckeMerken() {
        automatik.luecke()
        automatikAusgewertetBis = nil
        automatikLueckenKennung += 1
        hatLuecke = true
        if !satzZuLang, trennstellen.last != satzMesswerte.count {
            trennstellen.append(satzMesswerte.count)
        }
        senden(.pruefen(taktStand ?? zaehler?.anzahl ?? 0, .luecke))
    }

    private func senden(_ neu: ZaehlerMeldung) {
        let meldung: ZaehlerMeldung
        switch neu {
        case .stand(let n) where hatLuecke: meldung = .pruefen(n, .luecke)
        case .pruefen(let n, _) where hatLuecke: meldung = .pruefen(n, .luecke)
        default: meldung = neu
        }
        self.meldung = meldung
        melde?(meldung)
    }

    /// Die Art bleibt stehen: die Aufnahme liest sie nach ergebnis().
    private func beenden() {
        zaehler = nil
        kontext = nil
        automatikMelden = nil
        melde = nil
        meldung = nil
        ereignisse = []
        satzMesswerte = []
        taktZuruecksetzen()
    }

    private func taktZuruecksetzen() {
        satzKennung += 1
        taktStand = nil
        taktErgebnis = nil
        taktWerte = 0
        taktLaeuft = false
        taktBis = 0
    }
}
#endif
