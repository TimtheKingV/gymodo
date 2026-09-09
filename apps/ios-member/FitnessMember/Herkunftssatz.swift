import Foundation

/// Der Satz ueber einem Inhalt, der nicht aus einem frischen Abruf
/// stammt -- eine Stelle fuer Kurse und Verlauf.
///
/// Getrennt von beiden Herkunftstypen, weil deren ZUSTAENDE sich
/// unterscheiden (eine Belegungszahl veraltet von selbst, ein Verlauf
/// nicht), der SATZ aber derselbe sein muss: zwei Formulierungen fuer
/// denselben Sachverhalt waeren fuer das Mitglied zwei Sachverhalte.
enum Herkunftssatz {
    static func bilden(ohneEmpfang: Bool, stand: Date?, zusatz: String? = nil) -> String {
        let anfang = ohneEmpfang
            ? "Ohne Empfang."
            : "Diese Angaben stammen vom letzten Abruf."
        let datum = stand.map { " Stand: \(Zahlformat.stand($0))." } ?? ""
        let rest = zusatz.map { " \($0)" } ?? ""
        return anfang + datum + rest
    }
}
