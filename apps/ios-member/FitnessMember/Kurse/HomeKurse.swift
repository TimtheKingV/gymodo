import Foundation

/// Die eigenen Kurse im Wochenstreifen auf Home (Testnotiz 06.10., #1):
/// ein Punkt unter dem Tag, und ein Tipp auf den Tag zeigt die Anmeldung
/// mit "Abmelden" wie auf der Kurse-Seite.
///
/// Quelle sind die gespeicherten eigenen Buchungen (`KurseStore.eigene`),
/// nicht der volle Wochenplan: Home braucht nur, wo man selbst steht.
/// Zaehlen tun dieselben Termine wie im Band "Angemeldet" der Kurse-Seite
/// (`KurseMeineEinteilung.bilden`): bestaetigt oder auf der Warteliste,
/// nicht abgesagt und noch nicht begonnen.
enum HomeKurse {
    enum Punkt: Equatable {
        case keiner
        /// Mindestens ein bestaetigter Platz -- in der Signalfarbe.
        case angemeldet
        /// Nur Wartelistenplaetze -- im Gelb der Warteliste. Anders als auf
        /// der Kurse-Seite (dort faerbt sie nichts, `KurseTagesindikator`)
        /// bekommt sie hier einen eigenen Punkt: der Streifen auf Home
        /// zeigt sonst keine Kurse, und ohne ihn waere eine Warteliste von
        /// hier aus unsichtbar. So auf Rueckfrage entschieden.
        case warteliste
    }

    static func termineJeTag(_ termine: [GespeicherterTermin], jetzt: Date) -> [String: [GespeicherterTermin]] {
        let relevant = termine.filter {
            let zustand = KursDetailOfflineZustand.zustand(fuer: $0, jetzt: jetzt)
            return zustand == .angemeldet || zustand == .warteliste
        }
        return Dictionary(grouping: relevant, by: \.localDay)
    }

    static func punkt(_ termine: [GespeicherterTermin]?, jetzt: Date) -> Punkt {
        let zustaende = (termine ?? []).map { KursDetailOfflineZustand.zustand(fuer: $0, jetzt: jetzt) }
        if zustaende.contains(.angemeldet) { return .angemeldet }
        if zustaende.contains(.warteliste) { return .warteliste }
        return .keiner
    }
}
