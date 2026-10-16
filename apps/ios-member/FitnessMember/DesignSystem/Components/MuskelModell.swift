import SwiftUI

/// Ein Muskel einer Uebung, wie ihn Bootstrap und Geraetekontext als
/// `muscles: [{ key, name, role }]` liefern. Unbekannte Schluessel (ein
/// kuenftiger Muskel vom Server) sind erlaubt: Sie stehen in der Legende,
/// haben aber keine Flaeche im Modell.
struct GeraetMuskel: Decodable, Hashable, Sendable {
    let key: String
    let name: String
    let role: Rolle

    enum Rolle: String, Decodable, Sendable {
        case primary, secondary
    }
}

/// Pfaddaten aus `muskelmodell.json`, erzeugt von
/// scripts/muskelmodell-json.mjs aus assets/muskelmodell (Revision 4,
/// MIT-Lizenz, Copyright (c) 2022 ELABBASSI Hicham -- `lizenz`). Die Pfade
/// werden beim Laden einmal geparst, nicht bei jedem Zeichnen.
struct MuskelGeometrie: Decodable, Sendable {
    let lizenz: String
    let maennlich: Modell
    let weiblich: Modell

    struct Modell: Decodable, Sendable {
        let vorne: Ansicht
        let hinten: Ansicht

        /// Alle Muskelschluessel, die in einer der beiden Ansichten eine
        /// Flaeche haben.
        var schluessel: Set<String> {
            Set(vorne.muskeln.map(\.muscle)).union(hinten.muskeln.map(\.muscle))
        }
    }

    struct Ansicht: Decodable, Sendable {
        let viewBox: CGRect
        let body: [Path]
        let detail: [Path]
        let muskeln: [Muskelflaeche]

        private enum CodingKeys: String, CodingKey {
            case viewBox, body, detail, muscles, clipPfade
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let vb = try c.decode([CGFloat].self, forKey: .viewBox)
            guard vb.count == 4 else {
                throw DecodingError.dataCorruptedError(forKey: .viewBox, in: c, debugDescription: "viewBox braucht vier Zahlen")
            }
            viewBox = CGRect(x: vb[0], y: vb[1], width: vb[2], height: vb[3])
            body = try c.decode([String].self, forKey: .body).map(MuskelModell.pfad)
            detail = try c.decode([String].self, forKey: .detail).map(MuskelModell.pfad)
            let clipPfade = try c.decodeIfPresent([String: String].self, forKey: .clipPfade) ?? [:]
            muskeln = try c.decode([Roh].self, forKey: .muscles).map { roh in
                Muskelflaeche(
                    muscle: roh.muscle,
                    pfad: MuskelModell.pfad(roh.d),
                    geradeUngerade: roh.evenodd ?? false,
                    clip: roh.clip.flatMap { $0.count == 4 ? CGRect(x: $0[0], y: $0[1], width: $0[2], height: $0[3]) : nil },
                    clipPfad: roh.clipPfad.flatMap { clipPfade[$0] }.map(MuskelModell.pfad)
                )
            }
        }

        private struct Roh: Decodable {
            let muscle: String
            let d: String
            let evenodd: Bool?
            let clip: [CGFloat]?
            let clipPfad: String?
        }
    }

    struct Muskelflaeche: Sendable {
        let muscle: String
        let pfad: Path
        /// SVG `fill-rule="evenodd"`.
        let geradeUngerade: Bool
        /// Schulter: Rechteck, das vordere/seitliche/hintere Schulter trennt.
        let clip: CGRect?
        /// Wade hinten: Koerperumriss, ueber den der Muskel nicht hinausragt.
        let clipPfad: Path?
    }
}

enum MuskelModell {
    /// Die gebuendelte Geometrie; `nil` nur, wenn die Ressource fehlt oder
    /// kaputt ist -- dann zeigt die Karte nichts.
    static let geometrie: MuskelGeometrie? = {
        guard let url = Bundle.main.url(forResource: "muskelmodell", withExtension: "json"),
              let daten = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(MuskelGeometrie.self, from: daten)
    }()

    /// Liest SVG-Pfaddaten mit den absoluten Befehlen `M`, `L`, `C`, `Z`
    /// (mehr kommen in den Quellen nicht vor; das Skript prueft das).
    /// Unbekannte Befehle werden uebersprungen statt abzustuerzen.
    static func pfad(_ d: String) -> Path {
        var pfad = Path()
        var befehl: UInt8 = 0
        var zahlen: [CGFloat] = []
        zahlen.reserveCapacity(6)
        var zahl: [UInt8] = []

        func zahlAbschliessen() {
            guard !zahl.isEmpty else { return }
            if let wert = Double(String(decoding: zahl, as: UTF8.self)) {
                zahlen.append(CGFloat(wert))
            }
            zahl.removeAll(keepingCapacity: true)
            ausfuehrenWennVollstaendig()
        }

        func ausfuehrenWennVollstaendig() {
            switch befehl {
            case UInt8(ascii: "M") where zahlen.count == 2:
                pfad.move(to: CGPoint(x: zahlen[0], y: zahlen[1]))
                // Weitere Paare nach M sind implizite L (SVG-Regel).
                befehl = UInt8(ascii: "L")
                zahlen.removeAll(keepingCapacity: true)
            case UInt8(ascii: "L") where zahlen.count == 2:
                pfad.addLine(to: CGPoint(x: zahlen[0], y: zahlen[1]))
                zahlen.removeAll(keepingCapacity: true)
            case UInt8(ascii: "C") where zahlen.count == 6:
                pfad.addCurve(
                    to: CGPoint(x: zahlen[4], y: zahlen[5]),
                    control1: CGPoint(x: zahlen[0], y: zahlen[1]),
                    control2: CGPoint(x: zahlen[2], y: zahlen[3])
                )
                zahlen.removeAll(keepingCapacity: true)
            case UInt8(ascii: "M"), UInt8(ascii: "L"), UInt8(ascii: "C"):
                break
            default:
                // Z oder Unbekanntes: Zahlen dahinter verwerfen.
                zahlen.removeAll(keepingCapacity: true)
            }
        }

        for zeichen in d.utf8 {
            switch zeichen {
            case UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "."):
                zahl.append(zeichen)
            case UInt8(ascii: "-"), UInt8(ascii: "+"):
                // Ein Vorzeichen beginnt eine neue Zahl, ausser nach einem Exponenten.
                if let letztes = zahl.last, letztes != UInt8(ascii: "e"), letztes != UInt8(ascii: "E") {
                    zahlAbschliessen()
                }
                zahl.append(zeichen)
            case UInt8(ascii: "e"), UInt8(ascii: "E"):
                zahl.append(zeichen)
            case UInt8(ascii: "A")...UInt8(ascii: "Z"), UInt8(ascii: "a")...UInt8(ascii: "z"):
                zahlAbschliessen()
                zahlen.removeAll(keepingCapacity: true)
                befehl = zeichen
                if zeichen == UInt8(ascii: "Z") || zeichen == UInt8(ascii: "z") {
                    pfad.closeSubpath()
                }
            default:
                zahlAbschliessen()
            }
        }
        zahlAbschliessen()
        return pfad
    }

    /// Fuellfarbe eines Muskels in dieser Uebung (designsystem.md SS13.1);
    /// `nil` heisst "nicht angesprochen". Hauptmuskel nimmt `accent`,
    /// unterstuetzende laufen nach ihrer Reihenfolge durch die Stufen und
    /// bleiben am letzten Ton stehen.
    static func fuellung(fuer key: String, in muskeln: [GeraetMuskel]) -> Color? {
        let eintraege = muskeln.filter { $0.key == key }
        guard !eintraege.isEmpty else { return nil }
        if eintraege.contains(where: { $0.role == .primary }) {
            return DesignSystem.Color.accent
        }
        let hauptmuskeln = Set(muskeln.filter { $0.role == .primary }.map(\.key))
        var nachrangige: [String] = []
        for muskel in muskeln where muskel.role == .secondary
            && !hauptmuskeln.contains(muskel.key) && !nachrangige.contains(muskel.key) {
            nachrangige.append(muskel.key)
        }
        let stufen = DesignSystem.Color.muskelNachrangig
        let index = nachrangige.firstIndex(of: key) ?? 0
        return stufen[min(index, stufen.count - 1)]
    }

    /// Wahr, wenn mindestens ein Muskel eine Flaeche im Modell hat. Sonst
    /// entfiele nur ein Modell ohne jede Hervorhebung (SS13.1).
    static func zeigtModell(_ muskeln: [GeraetMuskel]) -> Bool {
        guard let geometrie else { return false }
        let flaechen = geometrie.maennlich.schluessel.union(geometrie.weiblich.schluessel)
        return muskeln.contains { flaechen.contains($0.key) }
    }
}
