import Foundation
import Koerperbild

/// Die schmale Naht zwischen dem Kamera-Ablauf und dem Geraete-Screen
/// (Spec Kamera-Tempo-Ablauf): der Ablauf bekommt, was er zum Zaehlen
/// braucht, und gibt nur die gezaehlte Zahl zurueck. Gesichert wird
/// ausschliesslich ueber `GeraetModel`.
struct KameraStart: Equatable {
    let exerciseId: String
    let name: String
    /// Etikett des Geraetetyps ("Kurzhantel"); nil bei eigenen Uebungen.
    let geraet: String?
    let vorgabe: Kameravorgabe
    let tempo: Uebungstempo
    /// Die Wiederholungen, die im Drawer eingestellt wurden; nil ohne Drawer.
    let sollWiederholungen: Int?
    let satzZiel: Int
    /// Nur Debug (Testprofile im Flow): Katalogschluessel fuer Video und Skelett der
    /// Abspielquelle, wenn der Name allein mehrdeutig ist. nil: ueber den Namen.
    var katalogKey: String? = nil
}

/// Ob das Mitglied diese Uebung mit der Kamera zaehlt.
enum KameraWahl: Equatable { case keine, mitKamera, ohneKamera }

/// Womit der Ablauf beginnt: nach dem Drawer mit dem Erklaervideo, nach
/// einer Pause gleich mit dem Aufstell-Check.
enum KameraEinstieg: Equatable { case video, aufstellen }

enum KameraSichern: Equatable {
    case gesichert(letzterSatz: Bool)
    case abgelehnt(String)
}

@MainActor
protocol KameraNaht: AnyObject {
    var kameraStart: KameraStart? { get }
    var kameraWahl: KameraWahl { get }
    var kameraEinstieg: KameraEinstieg { get }
    var anzeigeSatz: Int { get }
    var laufendePause: Resttimer? { get }
    var satzAbgelehnt: String? { get }
    /// Sichert den Satz mit der gezaehlten Zahl, sofort und lokal.
    func kameraSatzSichern(wiederholungen: Int) async -> KameraSichern
    /// "Ohne Kamera weiterzaehlen": der Ablauf schliesst, das Rad uebernimmt `gezaehlt`.
    func kameraVerlassen(gezaehlt: Int?)
    /// Schliesst nur den Ablauf (Rueckblick, Gewicht aendern in der Pause).
    func kameraAblaufSchliessen()
    func kameraWiederAufnehmen()
    /// Korrigiert die Wiederholungen des zuletzt gesicherten Satzes.
    func umfangNachtragen(_ wiederholungen: Int)
    func pauseBeenden()
    func weitererSatz()
}

extension BootstrapResponse.Exercise {
    /// nil ohne Kameravorgabe oder Tempo und beim Profil `ohneKamera`.
    func kameraStart(satzZiel: Int, sollWiederholungen: Int?) -> KameraStart? {
        guard let vorgabe = kameravorgabe, let tempo = uebungstempo,
              vorgabe.profil != .ohneKamera else { return nil }
        return KameraStart(exerciseId: id, name: name, geraet: geraetLabel, vorgabe: vorgabe, tempo: tempo,
                           sollWiederholungen: sollWiederholungen, satzZiel: satzZiel)
    }
}
