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
        let verbunden = SensorZustand.verbunden(name: datei.sensor.name, akkuProzent: datei.sensor.akkuProzent)
        setze(verbunden)
        lauf = Task { [weak self, eintraege, tempo] in
            var zuletzt: TimeInterval = 0
            for eintrag in eintraege {
                guard let self, !Task.isCancelled else { return }
                switch eintrag {
                case .messwert(let messwert):
                    if tempo == .echtzeit, messwert.t > zuletzt {
                        try? await Task.sleep(for: .seconds(messwert.t - zuletzt))
                    }
                    zuletzt = messwert.t
                    self.verteiler.senden(.messwert(messwert))
                case .luecke(_, let bis):
                    self.setze(.getrennt(wirdNeuVerbunden: true))
                    if tempo == .echtzeit, bis > zuletzt {
                        try? await Task.sleep(for: .seconds(bis - zuletzt))
                    }
                    zuletzt = bis
                    self.setze(verbunden)
                }
            }
            self?.setze(.getrennt(wirdNeuVerbunden: false))
            self?.lauf = nil
        }
    }

    func trennen() {
        lauf?.cancel()
        lauf = nil
        setze(.aus)
    }

    // Eine Datei hat nichts zu waehlen, zu vergessen oder umzustellen.
    func waehlen(_ fund: SensorFund) {}
    func vergessen() { trennen() }
    func rateSetzen(_ rate: SensorRate) {}
    func akkuLesen() {}

    private func setze(_ neu: SensorZustand) {
        zustand = neu
        verteiler.senden(.zustand(neu))
    }
}
#endif
