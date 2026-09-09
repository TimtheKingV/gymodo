import Foundation

/// Die Pause zwischen zwei Saetzen.
///
/// Der Timer haelt einen Endzeitpunkt, keinen Zaehler -- "Laeuft weiter,
/// auch wenn du wegsiehst" (GeraetResttimer.dc.html) haelt ueber
/// Hintergrund und Sperrbildschirm nur so.
struct Resttimer: Codable, Equatable {
    /// Die Vorgabe. Seit Sub-Projekt 4 im Profil einstellbar
    /// (Einstellungen.resttimerSekunden) -- der Wert hier gilt, solange
    /// niemand etwas anderes gewaehlt hat.
    static let dauer: TimeInterval = 90
    static let verlaengerung: TimeInterval = 30

    let start: Date
    let endetAm: Date

    init(start: Date = Date(), dauer: TimeInterval = Resttimer.dauer) {
        self.start = start
        endetAm = start.addingTimeInterval(dauer)
    }

    private init(start: Date, endetAm: Date) {
        self.start = start
        self.endetAm = endetAm
    }

    /// Die tatsaechliche Spanne DIESER Pause -- waechst mit jeder
    /// Verlaengerung, anders als die feste Self.dauer. anteil() und der
    /// Kopftext im Balken rechnen dagegen, sonst friert der Balken nach
    /// "+30 s" bei 100 % ein, waehrend die Ziffern weiter runterzaehlen.
    var gesamtdauer: TimeInterval { endetAm.timeIntervalSince(start) }

    func restsekunden(jetzt: Date = Date()) -> Int {
        max(0, Int(endetAm.timeIntervalSince(jetzt).rounded(.up)))
    }

    func laeuft(jetzt: Date = Date()) -> Bool {
        restsekunden(jetzt: jetzt) > 0
    }

    /// 1,0 zu Beginn, 0,0 am Ende -- der Balken zeigt Restdauer.
    func anteil(jetzt: Date = Date()) -> Double {
        guard gesamtdauer > 0 else { return 0 }
        return min(1, max(0, Double(restsekunden(jetzt: jetzt)) / gesamtdauer))
    }

    func verlaengert() -> Resttimer {
        Resttimer(start: start, endetAm: endetAm.addingTimeInterval(Self.verlaengerung))
    }

    /// Die Live-Region-Ansage aus designsystem.md SS12.
    func gesprochen(_ jetzt: Date = Date()) -> String {
        let rest = restsekunden(jetzt: jetzt)
        guard rest > 0 else { return "Pause beendet" }

        let minuten = rest / 60
        let sekunden = rest % 60
        switch (minuten, sekunden) {
        case (0, let s): return "Pause, noch \(s) Sekunden"
        case (let m, 0): return "Pause, noch \(m) Minute\(m == 1 ? "" : "n")"
        case (let m, let s): return "Pause, noch \(m) Minute\(m == 1 ? "" : "n") \(s) Sekunden"
        }
    }
}
