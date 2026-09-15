#if DEBUG
import UIKit

struct AccessibilityKandidat: Equatable, Sendable {
    var kennung: String?
    var label: String?
    var typ: String
    /// Bildschirmkoordinaten, wie accessibilityFrame sie liefert.
    var rahmen: CGRect
}

/// Findet das Element unter einem Finger ueber den Accessibility-Baum.
enum AccessibilityBaum {
    static let toleranz: CGFloat = 22

    /// Das kleinste Element, das den Punkt enthaelt; sonst das naechste
    /// innerhalb einer Fingerbreite. SwiftUI-Textknoten sind oft nur so gross
    /// wie der Text, ein Tipp daneben soll trotzdem treffen.
    static func treffer(_ kandidaten: [AccessibilityKandidat], punkt: CGPoint) -> AccessibilityKandidat? {
        if let kleinstes = kandidaten
            .filter({ $0.rahmen.contains(punkt) })
            .min(by: { flaeche($0.rahmen) < flaeche($1.rahmen) }) {
            return kleinstes
        }
        return kandidaten
            .map { ($0, abstand(punkt, $0.rahmen)) }
            .filter { $0.1 <= toleranz }
            .min(by: { $0.1 < $1.1 })?.0
    }

    static func flaeche(_ r: CGRect) -> CGFloat { r.width * r.height }

    static func abstand(_ p: CGPoint, _ r: CGRect) -> CGFloat {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX)
        let dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }

    /// SwiftUI-Knoten heissen alle "AccessibilityNode"; die Traits sagen mehr.
    static func typ(traits: UIAccessibilityTraits, klasse: String) -> String {
        if traits.contains(.button) { return "Button" }
        if traits.contains(.link) { return "Link" }
        if traits.contains(.adjustable) { return "Adjustable" }
        if traits.contains(.header) { return "Header" }
        if traits.contains(.image) { return "Image" }
        if traits.contains(.staticText) { return "Text" }
        return klasse
    }

    @MainActor
    static func sammeln(ab wurzel: NSObject) -> [AccessibilityKandidat] {
        var ergebnis: [AccessibilityKandidat] = []
        var gesehen = Set<ObjectIdentifier>()

        func gehen(_ objekt: NSObject, tiefe: Int) {
            // Ein UIButton ist ueber accessibilityElements UND subviews
            // erreichbar; ohne diese Menge stuende er doppelt drin.
            guard tiefe < 60, gesehen.insert(ObjectIdentifier(objekt)).inserted else { return }
            if let view = objekt as? UIView, view.isHidden || view.alpha < 0.01 { return }
            if objekt.accessibilityElementsHidden { return }

            if objekt.isAccessibilityElement {
                ergebnis.append(AccessibilityKandidat(
                    kennung: kennung(von: objekt),
                    label: objekt.accessibilityLabel,
                    typ: typ(traits: objekt.accessibilityTraits, klasse: String(describing: type(of: objekt))),
                    rahmen: objekt.accessibilityFrame
                ))
            }
            if let elemente = objekt.accessibilityElements {
                for case let kind as NSObject in elemente { gehen(kind, tiefe: tiefe + 1) }
            } else {
                let anzahl = objekt.accessibilityElementCount()
                if anzahl != NSNotFound, anzahl > 0 {
                    for i in 0..<anzahl {
                        if let kind = objekt.accessibilityElement(at: i) as? NSObject { gehen(kind, tiefe: tiefe + 1) }
                    }
                }
            }
            if let view = objekt as? UIView {
                for sub in view.subviews { gehen(sub, tiefe: tiefe + 1) }
            }
        }

        gehen(wurzel, tiefe: 0)
        return ergebnis
    }

    /// SwiftUI-Knoten tragen die Kennung, ohne UIAccessibilityIdentification
    /// zu erklaeren; sie antworten aber auf den Selektor.
    @MainActor
    private static func kennung(von objekt: NSObject) -> String? {
        let wert: String?
        if let identifizierbar = objekt as? UIAccessibilityIdentification {
            wert = identifizierbar.accessibilityIdentifier
        } else {
            let selektor = NSSelectorFromString("accessibilityIdentifier")
            wert = objekt.responds(to: selektor) ? objekt.perform(selektor)?.takeUnretainedValue() as? String : nil
        }
        guard let wert, !wert.isEmpty else { return nil }
        return wert
    }

    /// Das oberste App-Fenster, das den Punkt faengt, und darin der Teilbaum
    /// unter dem Finger. So gewinnt ein Sheet gegen den Screen darunter,
    /// obwohl beide im selben Fenster haengen.
    @MainActor
    static func element(an punkt: CGPoint, szene: UIWindowScene, ohne eigenes: UIWindow) async -> AccessibilityKandidat? {
        await AXSchalter.eingeschaltet {
            for fenster in szene.windows.reversed() where fenster !== eigenes && !fenster.isHidden {
                let lokal = fenster.convert(punkt, from: szene.screen.coordinateSpace)
                guard var knoten = fenster.hitTest(lokal, with: nil) else { continue }
                while true {
                    if let gefunden = treffer(sammeln(ab: knoten), punkt: punkt) { return gefunden }
                    guard let darueber = knoten.superview else { return nil }
                    knoten = darueber
                }
            }
            return nil
        }
    }
}

/// SwiftUI fuellt seinen Accessibility-Baum nur, wenn ein Assistenzdienst
/// laeuft -- im Prozess abgefragt liefert er sonst null Elemente. Dieser
/// Schalter ist private API aus libAccessibility, deshalb nur im Debug-Build.
///
/// Der Schalter bleibt fuer die Bundle-ID ueber Neustarts gespeichert (Spike
/// 2026-09-14). Er wird darum nur fuer die Dauer einer Suche gesetzt und
/// danach auf den vorigen Stand zurueckgestellt -- sonst liefe ein spaeter
/// installierter Release-Build mit derselben Bundle-ID dauerhaft mit
/// eingeschaltetem Baum.
@MainActor
enum AXSchalter {
    private typealias Lesen = @convention(c) () -> Int32
    private typealias Setzen = @convention(c) (Int32) -> Void

    private static func funktionen() -> (lesen: Lesen, setzen: Setzen)? {
        guard let bibliothek = dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW),
              let lesenZeiger = dlsym(bibliothek, "_AXSApplicationAccessibilityEnabled"),
              let setzenZeiger = dlsym(bibliothek, "_AXSApplicationAccessibilitySetEnabled")
        else { return nil }
        return (unsafeBitCast(lesenZeiger, to: Lesen.self), unsafeBitCast(setzenZeiger, to: Setzen.self))
    }

    /// nil, wenn die Bibliothek fehlt -- dann laeuft die Suche ohne Schalter.
    static var stand: Int32? {
        funktionen()?.lesen()
    }

    static func eingeschaltet<T>(_ arbeit: @MainActor () -> T) async -> T {
        guard let schalter = funktionen() else { return arbeit() }
        let lesen = schalter.lesen
        let setzen = schalter.setzen

        let vorher = lesen()
        if vorher == 0 {
            setzen(1)
            // Ein Runloop-Durchlauf, damit SwiftUI den Baum aufbaut.
            try? await Task.sleep(for: .milliseconds(150))
        }
        let ergebnis = arbeit()
        if vorher == 0 { setzen(0) }
        return ergebnis
    }
}
#endif
