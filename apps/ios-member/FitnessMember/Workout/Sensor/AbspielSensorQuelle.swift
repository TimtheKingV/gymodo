#if DEBUG
import Foundation
import Observation

/// Eine Aufnahme als Sensor. Dafuer gibt es das Protokoll: der Zaehler in B
/// und das Spiel in D laufen im Simulator gegen echte Saetze, ohne Sensor.
@MainActor
@Observable
final class AbspielSensorQuelle: SensorQuelle {
    enum Tempo { case sofort, echtzeit }

    private(set) var zustand: SensorZustand = .aus
    let rate: SensorRate
    let verworfeneBytes = 0

    @ObservationIgnored private let datei: SensorAufnahmeDatei
    @ObservationIgnored private let eintraege: [SensorAufnahmeLeser.Eintrag]
    @ObservationIgnored private let tempo: Tempo
    @ObservationIgnored private let verteiler = SensorVerteiler()
    @ObservationIgnored private var lauf: Task<Void, Never>?
    /// Zaehlt jeden verbinden()-Lauf hoch. trennen() setzt `lauf` sofort auf
    /// nil, ein noch schlafender alter Task wacht danach aber trotzdem wieder
    /// auf (try? schluckt den CancellationError) -- ohne diesen Vergleich
    /// wuesste er nicht, dass er nicht mehr der aktuelle Lauf ist.
    @ObservationIgnored private var laufKennung = 0

    init(ordner: URL, tempo: Tempo) throws {
        let gelesen = try SensorAufnahmeLeser.lesen(ordner: ordner)
        datei = gelesen.datei
        eintraege = gelesen.eintraege
        rate = SensorRate(rawValue: gelesen.datei.sensor.rateSollHz) ?? .hz50
        self.tempo = tempo
    }

    func ereignisse() -> AsyncStream<SensorEreignis> { verteiler.strom() }

    func verbinden() {
        guard lauf == nil else { return }
        laufKennung += 1
        let meineKennung = laufKennung
        let verbunden = SensorZustand.verbunden(name: datei.sensor.name, akkuProzent: datei.sensor.akkuProzent)
        setze(verbunden)
        lauf = Task { [weak self, eintraege, tempo] in
            var zuletzt: TimeInterval = 0
            for eintrag in eintraege {
                guard let self, self.istAktuell(meineKennung) else { return }
                switch eintrag {
                case .messwert(let messwert):
                    if tempo == .echtzeit, messwert.t > zuletzt {
                        try? await Task.sleep(for: .seconds(messwert.t - zuletzt))
                        // trennen() konnte waehrend des Schlafs abbrechen; try?
                        // schluckt den CancellationError, also selbst pruefen,
                        // statt danach kommentarlos weiterzumachen.
                        guard self.istAktuell(meineKennung) else { return }
                    }
                    zuletzt = messwert.t
                    self.verteiler.senden(.messwert(messwert))
                case .luecke(_, let bis):
                    self.setze(.getrennt(wirdNeuVerbunden: true))
                    if tempo == .echtzeit, bis > zuletzt {
                        try? await Task.sleep(for: .seconds(bis - zuletzt))
                        guard self.istAktuell(meineKennung) else { return }
                    }
                    zuletzt = bis
                    self.setze(verbunden)
                }
            }
            // Auch der Abschluss zaehlt als Seiteneffekt: ein alter Lauf, der
            // die Schleife noch zu Ende bringt, darf den neuen `lauf` nicht
            // ueberschreiben.
            guard let self, self.istAktuell(meineKennung) else { return }
            self.setze(.getrennt(wirdNeuVerbunden: false))
            self.lauf = nil
        }
    }

    func trennen() {
        lauf?.cancel()
        lauf = nil
        // Macht einen noch schlafenden alten Lauf sofort erkennbar veraltet,
        // auch wenn Task.isCancelled durch try? nicht mehr durchkommt.
        laufKennung += 1
        setze(.aus)
    }

    // Eine Datei hat nichts zu waehlen, zu vergessen oder umzustellen.
    func waehlen(_ fund: SensorFund) {}
    func vergessen() { trennen() }
    func rateSetzen(_ rate: SensorRate) {}
    func akkuLesen() {}

    private func istAktuell(_ kennung: Int) -> Bool {
        !Task.isCancelled && kennung == laufKennung
    }

    private func setze(_ neu: SensorZustand) {
        zustand = neu
        verteiler.senden(.zustand(neu))
    }
}
#endif
