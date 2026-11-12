import Foundation

/// Womit der Training-Tab startet (E8).
/// String-Rohwerte: `TrainingEinstiegSpeicher` legt ihn je Session ab.
enum TrainingEinstieg: String, Equatable { case auswahl, plan, frei }

/// Eine weitere Option der Auswahl. Ohne Tag (Spec P2): die Woche hat keine
/// festen Tage, nur ein Ziel.
enum TrainingAuswahlOption: Equatable, Identifiable {
    /// Eine spaetere Einheit der Reihe; Starten zieht sie vor (E9).
    case einheit(key: String)
    /// Offenes Cardio-Ziel dieser Woche: "Cardio · 30 min".
    case cardio(minuten: Int)

    var id: String {
        switch self {
        case .einheit(let key): "einheit-\(key)"
        case .cardio: "cardio"
        }
    }
}

struct TrainingAuswahlModell: Equatable {
    /// Die Einheit, die die Reihe als naechste fuehrt ("Als nächstes");
    /// nil nur bei einem Plan ohne Einheiten.
    let naechsteEinheitKey: String?
    /// Die uebrigen Einheiten in der Reihenfolge der Folge nach der naechsten,
    /// danach Cardio, solange das Wochenziel offen ist.
    let weitere: [TrainingAuswahlOption]
}

enum TrainingAuswahl {
    /// Wie die offenen Kraft-Karten im Plan-Tab (`PlanWochenRechnung`): ab
    /// `naechsteEinheitKey` (unbekannt = die erste) die Einheiten an Position
    /// `(i + k) mod n`. Cardio nur mit Cardio-Ziel, das diese Woche noch nicht
    /// erfuellt ist.
    static func modell(einheiten: [String], naechsteEinheitKey: String?,
                       ziel: Wochenziel, cardioErledigt: Int) -> TrainingAuswahlModell {
        var weitere: [TrainingAuswahlOption] = []
        var naechste: String?
        if !einheiten.isEmpty {
            let i = naechsteEinheitKey.flatMap { einheiten.firstIndex(of: $0) } ?? 0
            naechste = einheiten[i]
            var gesehen: Set<String> = [einheiten[i]]
            for k in 1..<einheiten.count {
                let key = einheiten[(i + k) % einheiten.count]
                if gesehen.insert(key).inserted { weitere.append(.einheit(key: key)) }
            }
        }
        if ziel.cardio > 0, cardioErledigt < ziel.cardio {
            weitere.append(.cardio(minuten: ziel.cardioMinuten))
        }
        return TrainingAuswahlModell(naechsteEinheitKey: naechste, weitere: weitere)
    }

    /// Schluessel der Einheit, die nach dem Vorziehen von `einheitKey` drankommt (E9).
    static func danach(einheitKey: String, einheitKeys: [String]) -> String {
        TrainingsplanFolge.naechsteEinheitKey(einheitKeys: einheitKeys, zuletzt: einheitKey)
    }
}
