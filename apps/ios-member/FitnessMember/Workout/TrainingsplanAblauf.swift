import Foundation

/// Ablaufstatus eines Trainingsplans, offline auf dem Geraet berechnet (Spec F17).
///
/// Spiegelt packages/domain/src/trainingsplan-ablauf.ts 1:1; beide Seiten laufen gegen
/// dieselben Testfaelle (packages/domain/fixtures/plan-ablauf.json). Reine Wertetypen ohne
/// UI- oder Store-Abhaengigkeit, damit die Regeln ohne Umbau testbar bleiben.
enum PositionStatus: String, Codable, Sendable {
    case offen, erledigt, optional, getauscht
}

struct AblaufPosition: Codable, Equatable, Sendable {
    var key: String
    var exerciseId: String
    /// Gilt fuer die wirksame Uebung, bei Tausch also fuer die Ersatzuebung.
    var hauptmuskeln: [String]
    var cardio: Bool
    var status: PositionStatus
    var ersatzExerciseId: String?

    /// Wirksam ist die Ersatzuebung, sobald getauscht wurde; sonst die geplante.
    fileprivate var wirksam: String { ersatzExerciseId ?? exerciseId }

    /// Nur diese Stati koennen noch durch einen Satz abgehakt werden (erledigt ist fertig).
    fileprivate var abhakbar: Bool { status == .offen || status == .getauscht || status == .optional }
}

struct AblaufZustand: Codable, Equatable, Sendable {
    var positionen: [AblaufPosition]
    var ungeplanteGesehen: [String]
}

struct AblaufSatz: Codable, Equatable, Sendable {
    var exerciseId: String
    var hauptmuskeln: [String]
    var cardio: Bool
}

enum TrainingsplanAblauf {
    /// Regel 1: passende Position wird erledigt. Regel 2: sonst ungeplante Uebung, hoechstens
    /// einmal je Uebung genau eine Position optional. Cardio und Kraft beruehren sich nie,
    /// damit ein Kraftsatz keine Cardio-Position verdraengt.
    static func nachSatz(_ z: AblaufZustand, _ satz: AblaufSatz) -> AblaufZustand {
        // Bei Cardio zaehlt jedes Geraet (F19), bei Kraft nur die erste passende Position in
        // Planreihenfolge, damit eine doppelt geplante Uebung nicht auf einen Schlag abgehakt wird.
        func passt(_ p: AblaufPosition) -> Bool {
            p.cardio == satz.cardio && p.abhakbar && (satz.cardio || p.wirksam == satz.exerciseId)
        }
        if let treffer = z.positionen.firstIndex(where: passt) {
            var neu = z
            for i in neu.positionen.indices where satz.cardio ? passt(z.positionen[i]) : i == treffer {
                neu.positionen[i].status = .erledigt
            }
            return neu
        }

        // Regel 2: fuehrt irgendeine Position (auch erledigt/optional) die Uebung, ist sie geplant.
        if satz.cardio { return z }
        if z.positionen.contains(where: { !$0.cardio && $0.wirksam == satz.exerciseId }) { return z }
        if z.ungeplanteGesehen.contains(satz.exerciseId) { return z }

        var neu = z
        neu.ungeplanteGesehen.append(satz.exerciseId)
        var besterIdx: Int?
        var besteAnzahl = 0
        for (i, p) in z.positionen.enumerated() {
            if p.cardio || (p.status != .offen && p.status != .getauscht) { continue }
            let gemeinsam = p.hauptmuskeln.filter { satz.hauptmuskeln.contains($0) }.count
            // Strikt groesser: bei Gleichstand gewinnt die zuerst im Plan.
            if gemeinsam > besteAnzahl {
                besteAnzahl = gemeinsam
                besterIdx = i
            }
        }
        if let besterIdx { neu.positionen[besterIdx].status = .optional }
        return neu
    }

    /// Tauscht eine Position dauerhaft; Cardio und bereits gezaehlte Positionen bleiben unveraendert.
    static func tauschen(
        _ z: AblaufZustand,
        positionKey: String,
        ersatz: (exerciseId: String, hauptmuskeln: [String])
    ) -> AblaufZustand {
        var neu = z
        for i in neu.positionen.indices {
            let p = neu.positionen[i]
            guard p.key == positionKey, !p.cardio, p.status == .offen || p.status == .getauscht else { continue }
            neu.positionen[i].status = .getauscht
            neu.positionen[i].ersatzExerciseId = ersatz.exerciseId
            neu.positionen[i].hauptmuskeln = ersatz.hauptmuskeln
        }
        return neu
    }

    /// Eine Einheit zaehlt fuer die Folge, sobald mindestens eine Position erledigt oder optional ist.
    static func zaehlt(_ z: AblaufZustand) -> Bool {
        z.positionen.contains { $0.status == .erledigt || $0.status == .optional }
    }
}

enum TrainingsplanFolge {
    /// Nachfolger in der Folge; nach der letzten wieder die erste, unbekannt oder nil gibt die erste.
    /// Leere einheitKeys sind nicht definiert (Aufrufer garantieren mindestens eine Einheit).
    static func naechsteEinheitKey(einheitKeys: [String], zuletzt: String?) -> String {
        let idx = zuletzt.flatMap { einheitKeys.firstIndex(of: $0) } ?? -1
        return einheitKeys[(idx + 1) % einheitKeys.count]
    }
}
