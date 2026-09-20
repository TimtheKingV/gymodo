import SwiftUI
import UIKit

/// Die Systemnavigationsleiste in der Schrift des Design Systems.
///
/// **Warum es das braucht.** Die meisten Screens zeichnen ihren Titel
/// selbst -- "KURSE", "TRAINING", "GERÄT WÄHLEN" stehen als `Text` mit
/// `DesignSystem.Typography.screentitel` im Inhalt. Profil und Studios
/// nutzen stattdessen `.navigationTitle`, und das aus gutem Grund: nur
/// der Systemtitel klappt beim Scrollen von selbst in die Leiste ein.
/// Genau diese Bewegung ist der Grund, sie zu behalten (Testnotiz vom
/// 19. September, Eintrag 10, wo sie als Vorbild genannt wird).
///
/// Den Preis dafuer zahlte bisher die Schrift: "PROFIL" stand in der
/// Systemschrift zwischen lauter 32pt-Black-Titeln und sah aus wie aus
/// einer anderen App (Eintrag 11). Hier wird die Leiste einmalig auf
/// dieselben Werte gesetzt -- dann klappt der Titel weiter ein UND passt.
///
/// **Absichtlich nur Schrift und Farbe, kein Hintergrund.** Ein
/// `backgroundColor` oder `backgroundEffect` auf der Appearance ersetzte
/// das Material der Leiste durch eine Flaeche. Die Leiste soll bleiben,
/// was das System aus ihr macht -- auf iOS 26 also durchscheinendes Glas,
/// zu dem der Zurueck-Knopf gehoert. Wir sagen ihr nur, wie sie schreibt.
///
/// **Warum `UINavigationBar.appearance()` und kein SwiftUI-Modifier.**
/// SwiftUI kann die Schrift des grossen Titels nicht setzen; es gibt
/// dafuer schlicht keinen Modifier. Der Umweg ueber UIKit ist die einzige
/// Stelle im Projekt, die so etwas tut, und er steht deshalb hier und
/// nicht verstreut an den Screens.
enum Navigationsleiste {
    /// Einmal beim Start, vor dem ersten Aufbau einer Leiste --
    /// `appearance()` wirkt nur auf Leisten, die danach entstehen.
    static func einrichten() {
        let erscheinung = UINavigationBarAppearance()
        // Genau die Werte aus DesignSystem.Typography.screentitel bzw.
        // uebungsname -- SwiftUI-Fonts lassen sich nicht in UIFont
        // umrechnen, deshalb stehen sie hier ein zweites Mal. Aendert
        // sich dort etwas, muss es hier mit.
        erscheinung.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 32, weight: .black),
            .foregroundColor: UIColor(DesignSystem.Color.text),
            .kern: -1,
        ]
        erscheinung.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .heavy),
            .foregroundColor: UIColor(DesignSystem.Color.text),
        ]

        // Beide Zustaende, sonst faellt der eingeklappte Titel beim
        // Scrollen auf die Systemschrift zurueck -- und genau im
        // Uebergang saehe man den Wechsel.
        let leiste = UINavigationBar.appearance()
        leiste.standardAppearance = erscheinung
        leiste.scrollEdgeAppearance = erscheinung
        leiste.compactAppearance = erscheinung
    }
}
