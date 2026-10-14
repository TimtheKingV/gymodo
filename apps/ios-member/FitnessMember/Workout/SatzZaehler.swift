import Foundation
import Sensorik

// Naht zwischen Satzpfad und Zaehler (Sensor-Spec B 6.4, Nachtrag 14.10.).
//
// Immer kompiliert wie SatzMitschnitt: GeraetModel wird auch im Release
// gebaut und darf keinen Debug-Typ im Konstruktor tragen. Bis E5 ist der
// Parameter im Release nil.
//
// Nichts wirft, nichts ist async: der Satz darf am Zaehler weder scheitern
// noch auf ihn warten.

struct BefestigungsWahl: Equatable, Sendable {
    let art: Befestigungsart
    let quelle: BefestigungsartQuelle
}

struct SatzZaehlerKontext: Equatable, Sendable {
    /// Station statt machineId: am Geraetetyp gibt es keine (Nachtrag 14.10. Punkt 1).
    let station: Station
    let exerciseId: String
    let volumeKind: VolumeKind
}

enum ZaehltNichtGrund: Equatable, Sendable {
    case keinSensor, keineWiederholungen, keineBefestigung
    /// Erst ab E5: im Release zaehlen nur freigegebene Arten.
    case nichtFreigegeben
}

enum ZaehlerMeldung: Equatable, Sendable {
    case zaehltNicht(ZaehltNichtGrund)
    case bereit
    case stand(Int)
    case pruefen(Int, UnsicherGrund)
}

struct ZaehlerErgebnis: Equatable, Sendable {
    let gezaehlt: Int
    let repEvents: RepEvents
}

@MainActor
protocol SatzZaehler: AnyObject {
    /// Die Art des laufenden oder eben beendeten Satzes. Bleibt nach
    /// ergebnis() stehen, damit die Aufnahme sie noch lesen kann.
    var befestigung: BefestigungsWahl? { get }
    func satzBeginnt(_ kontext: SatzZaehlerKontext, melde: @escaping @MainActor (ZaehlerMeldung) -> Void)
    /// Beim Sichern abgeholt; beendet den Satz. nil, wenn nichts gezaehlt wurde.
    func ergebnis() -> ZaehlerErgebnis?
    func satzVerworfen()
}
