import Foundation

/// Schalter fuer Funktionen, die gebaut sind, aber noch nicht fuer alle
/// Mitglieder gelten. Eine Stelle, ein Name je Funktion -- freischalten heisst
/// hier den Wert aendern, nicht Screens anfassen.
enum Funktionen {
    /// Die Sensor-Karte auf der Geraeteauswahl und an jeder Uebung
    /// (Testnotiz 15.10., #5). Vorerst nur im Debug-Build, also nur fuer den
    /// Entwickler.
    ///
    /// Live schalten braucht mehr als diesen Wert: der Sensor-Unterbau
    /// (Workout/Sensor, SensorZeile, SensorKarte) ist selbst noch `#if DEBUG`
    /// und die Bluetooth-Texte stehen nur in Info-Additions-Debug.plist.
    static var sensorKarte: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}
