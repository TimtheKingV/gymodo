import AVFoundation
import Foundation

/// Nur die Phase, ohne Restsekunden: ihr Wechsel loest Haptik, Abschluss und
/// das Nachladen der Videos aus. Phasen kehren nie wieder.
enum FlowPhase: Equatable {
    case countdown, arbeit(Int), pause(Int), fertig

    init(_ zustand: FlowZustand) {
        switch zustand {
        case .countdown: self = .countdown
        case .arbeit(let s, _): self = .arbeit(s)
        case .pause(let n, _): self = .pause(n)
        case .fertig: self = .fertig
        }
    }
}

/// Was die Video-Seite eines Schritts anzeigt, aus dem Zustand abgeleitet.
struct FlowVideoSeite: Equatable {
    let schrittIndex: Int
    let ueberschrift: String
    let zeile: String?
    let restS: Int
    let mitBlickzeile: Bool
    /// Nur in der Arbeitsphase: Name des folgenden Schritts fuer "Als Nächstes: …".
    let naechsterName: String?
}

/// Reine Entscheidungen rund um die Videos des Flow-Laufs.
enum FlowVideoPlan {
    /// Nil im Zustand `fertig` oder ohne Schritte.
    static func seite(zustand: FlowZustand, schritte: [FlowSchritt]) -> FlowVideoSeite? {
        guard !schritte.isEmpty else { return nil }
        let letzter = schritte.count - 1
        switch zustand {
        case .countdown(let rest):
            return FlowVideoSeite(schrittIndex: 0, ueberschrift: "GLEICH GEHT'S LOS", zeile: "Als Nächstes",
                                  restS: rest, mitBlickzeile: true, naechsterName: nil)
        case .arbeit(let index, let rest):
            let i = min(index, letzter)
            return FlowVideoSeite(schrittIndex: i, ueberschrift: "SCHRITT \(i + 1) VON \(schritte.count)", zeile: nil,
                                  restS: rest, mitBlickzeile: false,
                                  naechsterName: i < letzter ? schritte[i + 1].name : nil)
        case .pause(let naechster, let rest):
            return FlowVideoSeite(schrittIndex: min(naechster, letzter), ueberschrift: "PAUSE", zeile: "Als Nächstes",
                                  restS: rest, mitBlickzeile: true, naechsterName: nil)
        case .fertig:
            return nil
        }
    }

    /// Die Schritte, deren Video in dieser Phase gebraucht wird: der gezeigte
    /// und der folgende, in dieser Reihenfolge.
    static func benoetigteSchritte(phase: FlowPhase, anzahl: Int) -> [Int] {
        let erster: Int
        switch phase {
        case .countdown: erster = 0
        case .arbeit(let i), .pause(let i): erster = i
        case .fertig: return []
        }
        return [erster, erster + 1].filter { $0 >= 0 && $0 < anzahl }
    }
}

/// Die fertig vorbereiteten Videos je Uebungs-ID. Ein Video, das erst mitten in
/// einer Phase eintrifft, wird erst ab der naechsten Phase gezeigt: die Ansicht
/// springt nie mitten in der Phase vom Ring zum Video.
struct FlowVideoStand {
    private struct Eintrag {
        let asset: AVAsset
        /// In welcher Phase es eintraf; nil: schon vor dem Start da.
        let eingetroffenIn: FlowPhase?
    }

    private var eintraege: [String: Eintrag] = [:]

    init(vorgeladen: [String: AVAsset] = [:]) {
        for (id, asset) in vorgeladen { eintraege[id] = Eintrag(asset: asset, eingetroffenIn: nil) }
    }

    func hat(_ exerciseId: String) -> Bool { eintraege[exerciseId] != nil }

    mutating func eingetroffen(_ exerciseId: String, asset: AVAsset, in phase: FlowPhase) {
        guard eintraege[exerciseId] == nil else { return }
        eintraege[exerciseId] = Eintrag(asset: asset, eingetroffenIn: phase)
    }

    /// Das Video, das `phase` von ihrem Beginn an zeigen darf; sonst nil (Ring).
    func asset(fuer exerciseId: String?, in phase: FlowPhase) -> AVAsset? {
        guard let exerciseId, let eintrag = eintraege[exerciseId],
              eintrag.eingetroffenIn != phase else { return nil }
        return eintrag.asset
    }

    /// Welche der gebrauchten Videos fehlen noch (zum Nachladen bei jedem Phasenwechsel).
    static func fehlende(schritte: [FlowSchritt], ansichten: [FlowSchrittAnsicht], phase: FlowPhase,
                         stand: FlowVideoStand) -> [String] {
        FlowVideoPlan.benoetigteSchritte(phase: phase, anzahl: schritte.count).compactMap { i in
            guard ansichten[i] != .ring, let id = schritte[i].exerciseId, !stand.hat(id) else { return nil }
            return id
        }
    }

    /// Laedt Datei und Bildspur; nil, wenn eines davon fehlschlaegt.
    @MainActor
    static func laden(exerciseId: String, videos: UebungsVideoVorrat) async -> AVAsset? {
        guard let datei = await videos.datei(exerciseId: exerciseId) else { return nil }
        return await Schleifenvideo.nurBild(datei)
    }
}
