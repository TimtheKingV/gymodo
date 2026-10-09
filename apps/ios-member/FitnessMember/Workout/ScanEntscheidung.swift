import Foundation

/// Was ein gescannter Geraetecode oder eine in der Liste gewaehlte Station
/// bewirkt, als reine Funktion.
/// TrainingRootView fuehrt nur aus; die Regeln stehen hier, damit sie
/// ohne View testbar sind (Plan, Entscheidung 2).
enum ScanEntscheidung: Equatable {
    /// Das Geraet steht am aktuellen Ort -- oeffnen.
    case oeffnen(Station)
    /// Der Prefetch kennt den Code nicht: der Server entscheidet, ob er zu
    /// einem (fremden oder neuen) Geraet gehoert, und macht zum Mitglied.
    case beitreten
    /// Die Station steht an einem anderen Ort (eigenes Studio oder Freies
    /// Training), und keine Einheit haelt dagegen: wechseln, oeffnen.
    case wechselnUndOeffnen(Ort, Station)
    /// Eine Einheit laeuft an einem anderen Ort als dem des Geraets. Erst
    /// nach "Training beenden" wird gewechselt und geoeffnet.
    case erstBeenden(laufenderOrt: Ort, ziel: Ort, station: Station)

    static func fuer(token: String, bootstrap: BootstrapResponse?, ort: Ort,
                     offeneEinheit: LokaleSession?) -> ScanEntscheidung {
        guard let bootstrap, let maschine = MachineResolver.maschine(fuerToken: token, in: bootstrap)
        else { return .beitreten }
        return fuer(station: Station(maschine: maschine), ort: ort, offeneEinheit: offeneEinheit)
    }

    /// Dieselbe Regel fuer eine Station aus der Liste: ueber "Auch in X
    /// suchen" kann sie an einem anderen Ort stehen. Nie `.beitreten` --
    /// die Liste kennt nur Stationen aus dem Bootstrap. Der Ort wird vor dem
    /// Oeffnen gewechselt, weil die Route nur den Schluessel traegt und ein
    /// Typ mit dem aktuellen Ort aufgeloest wird.
    static func fuer(station: Station, ort: Ort, offeneEinheit: LokaleSession?) -> ScanEntscheidung {
        let ziel = station.studioId.map(Ort.studio) ?? .freiesTraining
        switch Ortswechsel.pruefen(ziel: ziel, aktuell: ort, offeneEinheit: offeneEinheit) {
        case .erstBeenden(let laufenderOrt):
            return .erstBeenden(laufenderOrt: laufenderOrt, ziel: ziel, station: station)
        case .sofort:
            return ziel == ort ? .oeffnen(station) : .wechselnUndOeffnen(ziel, station)
        }
    }

    /// Nach `joinStudio(byTag:)`. Der Beitritt hat den Ort nicht gewechselt:
    /// `.oeffnen` und `.listeZeigen` wechseln erst (CatalogStore.ortNachBeitritt),
    /// dann zeigen sie.
    enum NachBeitritt: Equatable {
        case oeffnen(Station)
        /// Aushang (kein Geraet am Code) oder ein Geraet, das das frische
        /// Bootstrap nicht kennt: die Liste des Studios.
        case listeZeigen
        /// Der Beitritt ist geschehen; Wechsel und Geraet (oder die Liste,
        /// station nil) erst nach "Training beenden". Abbrechen laesst den
        /// Ort, wie er war -- Mitglied bleibt man trotzdem.
        case erstBeenden(laufenderOrt: Ort, station: Station?)
    }

    /// `ort` ist der Ort, an dem das Mitglied steht -- an ihm laeuft eine
    /// offene Einheit ohne eigenen Ort (eine Datei von vor dem Katalog), und
    /// fuer sie soll kein Dialog ohne Anlass kommen.
    static func nachBeitritt(_ ergebnis: JoinResult, bootstrap: BootstrapResponse?, ort: Ort,
                             offeneEinheit: LokaleSession?) -> NachBeitritt {
        let station = ergebnis.machineId.flatMap { id in
            bootstrap?.station(schluessel: Station.schluessel(machineId: id), studioId: ergebnis.studioId)
        }
        switch Ortswechsel.pruefen(ziel: .studio(ergebnis.studioId), aktuell: ort,
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
