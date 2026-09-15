import SwiftUI

#if DEBUG
/// Wo ein markiertes Element im Code steht.
struct ElementHerkunft: Equatable, Sendable {
    let typ: String
    let datei: String
    let zeile: Int
}

/// Kennung -> Herkunft. Rahmen braucht es nicht: die liefert der
/// Accessibility-Baum, samt Kennung (Spike 2026-09-14).
struct TestnotizElementRegister {
    private var herkuenfte: [String: ElementHerkunft] = [:]

    mutating func melden(kennung: String, herkunft: ElementHerkunft) {
        herkuenfte[kennung] = herkunft
    }

    func herkunft(kennung: String?) -> ElementHerkunft? {
        kennung.flatMap { herkuenfte[$0] }
    }

    func element(aus kandidat: AccessibilityKandidat) -> TestnotizEintrag.Element {
        let herkunft = herkunft(kennung: kandidat.kennung)
        return TestnotizEintrag.Element(
            source: .accessibility,
            identifier: kandidat.kennung,
            label: kandidat.label,
            type: herkunft?.typ ?? kandidat.typ,
            frame: TestnotizEintrag.Rechteck(kandidat.rahmen),
            file: herkunft?.datei,
            line: herkunft?.zeile
        )
    }
}

extension View {
    /// An der Aufrufstelle, nicht in der Komponente: die Kennung wandert vom
    /// Container auf den Knopf darin, und #filePath/#line zeigen so auf den
    /// Screen statt auf PrimaryButton.swift.
    func testnotizElement(_ kennung: String, typ: String, datei: String = #filePath, zeile: Int = #line) -> some View {
        accessibilityIdentifier(kennung)
            .onAppear {
                Testnotiz.shared.register.melden(
                    kennung: kennung,
                    herkunft: ElementHerkunft(typ: typ, datei: Quellpfad.relativ(datei), zeile: zeile)
                )
            }
    }
}
#else
extension View {
    /// Release: die Kennung bleibt -- sie ist fuer XCUITests ohnehin richtig.
    @inline(__always)
    func testnotizElement(_ kennung: String, typ: String) -> some View {
        accessibilityIdentifier(kennung)
    }
}
#endif
