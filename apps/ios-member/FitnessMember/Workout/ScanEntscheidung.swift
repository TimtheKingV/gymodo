import Foundation

/// Was ein gescannter Geraetecode bewirkt, als reine Funktion.
/// TrainingRootView fuehrt nur aus; die Regeln stehen hier, damit sie
/// ohne View testbar sind (Plan, Entscheidung 2).
enum ScanEntscheidung: Equatable {
    /// Das Geraet steht am aktuellen Ort -- oeffnen.
    case oeffnen(Station)
    /// Der Prefetch kennt den Code nicht: der Server entscheidet, ob er zu
    /// einem (fremden oder neuen) Geraet gehoert, und macht zum Mitglied.
    case beitreten
    /// Das Geraet steht in einem anderen eigenen Studio: wechseln, oeffnen.
    case wechselnUndOeffnen(Ort, Station)
    /// Eine Einheit laeuft an einem anderen Ort als dem des Geraets. Erst
    /// nach "Training beenden" wird gewechselt und geoeffnet.
    case erstBeenden(laufenderOrt: Ort, ziel: Ort, station: Station)

    static func fuer(token: String, bootstrap: BootstrapResponse?, ort: Ort,
                     offeneEinheit: LokaleSession?) -> ScanEntscheidung {
        guard let bootstrap, let maschine = MachineResolver.maschine(fuerToken: token, in: bootstrap)
        else { return .beitreten }
        let station = Station(maschine: maschine)
        let ziel = Ort.studio(maschine.studioId)
        switch Ortswechsel.pruefen(ziel: ziel, aktuell: ort, offeneEinheit: offeneEinheit) {
        case .erstBeenden(let laufenderOrt):
            return .erstBeenden(laufenderOrt: laufenderOrt, ziel: ziel, station: station)
        case .sofort:
            return ziel == ort ? .oeffnen(station) : .wechselnUndOeffnen(ziel, station)
        }
    }

    /// Nach `joinStudio(byTag:)`: der Ort ist schon das Studio des Codes.
    enum NachBeitritt: Equatable {
        case oeffnen(Station)
        /// Aushang (kein Geraet am Code) oder ein Geraet, das das frische
        /// Bootstrap nicht kennt: die Liste des Studios.
        case listeZeigen
        /// Der Beitritt ist geschehen; das Geraet (oder die Liste, station
        /// nil) erst nach "Training beenden". Abbrechen stellt `vorher` wieder her.
        case erstBeenden(laufenderOrt: Ort, station: Station?)
    }

    /// `vorher` ist der Ort VOR dem Beitritt -- an ihm kann eine offene
    /// Einheit ohne eigenen Ort laufen (Ortswechsel, Ruling 4).
    static func nachBeitritt(_ ergebnis: JoinResult, bootstrap: BootstrapResponse?, vorher: Ort,
                             offeneEinheit: LokaleSession?) -> NachBeitritt {
        let station = ergebnis.machineId.flatMap { id in
            bootstrap?.station(schluessel: Station.schluessel(machineId: id), studioId: ergebnis.studioId)
        }
        switch Ortswechsel.pruefen(ziel: .studio(ergebnis.studioId), aktuell: vorher,
                                   offeneEinheit: offeneEinheit) {
        case .erstBeenden(let laufenderOrt):
            return .erstBeenden(laufenderOrt: laufenderOrt, station: station)
        case .sofort:
            return station.map(NachBeitritt.oeffnen) ?? .listeZeigen
        }
    }

    /// Ein unbekannter oder gesperrter Code bekommt dieselbe neutrale
    /// Antwort wie bisher (M1-Spec SS10.4); nur "kein Netz" sagt, was los ist.
    static func fehlertext(_ fehler: APIError) -> String {
        switch fehler {
        case .notFound, .validation: "Dieser Code ist nicht aktiv. Frag im Studio nach."
        case .offline: "Keine Verbindung. Der Code wurde nicht gesendet."
        default: fehler.servertext
        }
    }
}
