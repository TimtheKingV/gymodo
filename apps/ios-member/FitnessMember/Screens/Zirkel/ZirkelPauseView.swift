import SwiftUI

/// Die Pause zwischen zwei Zirkel-Uebungen (Spec Mini-Zirkel 21.10.,
/// Entscheidung 5): der eine Pausen-Screen (UX-Paket 2, 2.1), gefuettert aus
/// ZirkelAblauf.
///
/// Der Screen haelt selbst keinen Zirkelstand. Er liest ZirkelAblauf und
/// meldet nur Absichten nach oben; navigiert wird in TrainingRootView,
/// damit Ablauf der Uhr und Tipp denselben, gegen doppelten Aufruf
/// gesperrten Weg nehmen (zirkelWeiter).
struct ZirkelPauseView: View {
    let ablauf: ZirkelAblauf
    let uebungsname: (ZirkelUebung) -> String
    /// Der Ort der Station fuer die Kopfzeile ("" ohne Ort).
    let ort: (ZirkelUebung) -> String
    /// Das Standbild je Zeile der Ablauf-Liste.
    let bildModellId: (ZirkelUebung) -> String?
    /// Oeffnet die Trainingssteuerung der Wurzel (Tipp auf die Uhr).
    let beiSteuerung: () -> Void
    /// Ende der Pause oder Tipp auf "<Name> starten".
    let beiStarten: () -> Void
    /// "+ Übung zum Zirkel" -- nur gesetzt, solange Erweitern offen ist
    /// (Task 7). nil blendet den Knopf aus.
    let beiErweitern: (() -> Void)?
    let beiBeenden: () -> Void
    var nachUeberspringen: (() -> Void)? = nil

    @Environment(WorkoutSessionStore.self) private var sessions

    var body: some View {
        // Ohne Zirkel (beendet, waehrend der Screen noch auf dem Stapel
        // liegt) bleibt die Flaeche leer statt einen Absturz zu riskieren.
        Group {
            if let zirkel = ablauf.zirkel, let naechste = zirkel.naechste {
                inhalt(zirkel, naechste: naechste)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Color.bg)
        .navigationBarTitleDisplayMode(.inline)
        // Unter der Pause liegt der Geraete-Screen der eben gemachten Uebung,
        // und dort ist Sichern fuer diesen Zirkel-Slot gesperrt
        // (zirkelSatzAbgegeben). Zurueck fuehrte also auf eine Seite, auf der
        // nichts mehr geht. Ohne Zurueck-Knopf sperrt SwiftUI auch das
        // Wischen vom Rand; heraus kommt man nur ueber die Knoepfe unten
        // oder den Ablauf der Uhr.
        .navigationBarBackButtonHidden(true)
        // Wie GeraetView: der Endzeitpunkt ist die id, damit "+30 s" den Task
        // neu aufsetzt statt zu frueh zu feuern. Kommt die App aus dem
        // Hintergrund und die Frist ist um, feuert er sofort. Dies ist die
        // einzige Stelle, die das Ende der Zirkel-Pause ausloest.
        .task(id: ablauf.pause?.endetAm) {
            guard let ende = ablauf.pause?.endetAm else { return }
            let rest = ende.timeIntervalSinceNow
            if rest > 0 { try? await Task.sleep(for: .seconds(rest)) }
            guard !Task.isCancelled else { return }
            beiStarten()
        }
        .testnotizScreen()
    }

    private func inhalt(_ zirkel: Zirkel, naechste: ZirkelUebung) -> some View {
        let ort = ort(naechste)
        // In der Rundenpause zaehlt der Zirkel schon die neue Runde -- die
        // Ablaufzeile nennt sie, und die Liste zeigt ihre Stationen als
        // naechste (Review Focus 2).
        return PausenScreen(
            ort: ort.isEmpty ? "MINI-ZIRKEL" : ort.uppercased(),
            ueberschrift: zirkel.naechsterSchrittIstRundenwechsel
                ? "RUNDENPAUSE · MINI-ZIRKEL" : "PAUSE · MINI-ZIRKEL",
            ablaufzeile: .zirkel(station: zirkel.position + 1, von: zirkel.uebungen.count,
                                 runde: zirkel.runde, runden: zirkel.runden),
            // Ohne Pause (nur einen Wimpernschlag vor dem Wechsel) ein
            // abgelaufener Ring statt keiner, damit nichts springt.
            timer: ablauf.pause ?? Resttimer(dauer: 0),
            zeilen: AblaufListe.zirkel(zirkel, bloecke: sessions.aktiveSession()?.bloecke ?? [],
                                       seit: ablauf.abschluss?.begann, name: uebungsname,
                                       bildModellId: bildModellId),
            knoepfe: PausenKnoepfe.fuer(.zirkel(naechsteUebung: uebungsname(naechste),
                                                kannErweitern: beiErweitern != nil)),
            beiSteuerung: beiSteuerung,
            beiVerlaengern: { ablauf.pauseVerlaengern() },
            beiHaupt: beiStarten,
            // "± Gewicht" fuer die naechste Station kommt mit Task 5; bis
            // dahin kein Knopf statt eines ohne Wirkung.
            beiGewicht: nil,
            // Gilt nur fuer diese Runde und sichert keinen Satz (Spec-
            // Annahme). Danach derselbe Weg wie am Ende der Pause: zur dann
            // naechsten Uebung bzw. zur Uebersicht, wenn keine mehr kommt.
            // Schloss der Slot die Runde, bleibt der Screen stehen und wird
            // zur Rundenpause; deren Uhr setzt der Task ueber das neue
            // endetAm auf.
            beiUeberspringen: {
                ablauf.ueberspringen()
                nachUeberspringen?()
                if let zirkel = ablauf.zirkel, ZirkelPfad.nachUeberspringenWeiter(zirkel) {
                    beiStarten()
                }
            },
            beiErweitern: { beiErweitern?() },
            beiZirkelBeenden: beiBeenden)
    }
}

/// Die Texte des Pausenscreens als reine Funktionen, damit sie ohne View
/// pruefbar sind.
enum ZirkelPauseText {
    static func startTitel(uebungsname: String) -> String {
        "\(uebungsname) starten"
    }

    /// Ein Satz eines Blocks in einer Zeile: "12,5 kg × 10", bei Cardio
    /// die Cardio-Werte. nil ohne Werte. Zirkel-Uebersicht und Ablauf-Liste
    /// schreiben damit jeden Satz.
    static func satzwerte(_ letzter: LokalerSatz, _ block: LokalerBlock) -> String? {
        if let cardio = letzter.cardio { return Zahlformat.cardio(cardio) }
        guard let load = letzter.load, let volume = letzter.volume else { return nil }
        return Zahlformat.satz(load, block.loadUnit, neben: letzter.secondaryLoad, block.secondaryUnit,
                               umfang: volume, block.volumeKind)
    }
}
