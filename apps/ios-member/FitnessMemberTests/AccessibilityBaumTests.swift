#if DEBUG
import SwiftUI
import Testing
@testable import FitnessMember

// Seriell: der Schalter ist prozessweit, und ein Test, der ihn umstellt,
// darf nicht in die 150-ms-Pause eines anderen fallen.
@MainActor
@Suite(.serialized)
struct AccessibilityBaumTests {
    private let karte = AccessibilityKandidat(kennung: nil, label: "Karte", typ: "Text", rahmen: CGRect(x: 0, y: 0, width: 300, height: 200))
    private let knopf = AccessibilityKandidat(kennung: "geraet.satz-sichern", label: "Satz 2 sichern", typ: "Button", rahmen: CGRect(x: 20, y: 120, width: 260, height: 64))

    @Test func kleinstesRechteckUmDenPunktGewinnt() {
        #expect(AccessibilityBaum.treffer([karte, knopf], punkt: CGPoint(x: 100, y: 150)) == knopf)
        #expect(AccessibilityBaum.treffer([karte, knopf], punkt: CGPoint(x: 100, y: 20)) == karte)
    }

    @Test func nebenDemTextTrifftEsInnerhalbEinerFingerbreite() {
        #expect(AccessibilityBaum.treffer([knopf], punkt: CGPoint(x: 100, y: 200)) == knopf)
        #expect(AccessibilityBaum.treffer([knopf], punkt: CGPoint(x: 100, y: 210)) == nil)
    }

    @Test func typKommtAusDenTraits() {
        #expect(AccessibilityBaum.typ(traits: [.button, .staticText], klasse: "AccessibilityNode") == "Button")
        #expect(AccessibilityBaum.typ(traits: .staticText, klasse: "AccessibilityNode") == "Text")
        #expect(AccessibilityBaum.typ(traits: [], klasse: "UISwitch") == "UISwitch")
    }

    @Test func registerReichertDenKandidatenAn() {
        var register = TestnotizElementRegister()
        register.melden(kennung: "geraet.satz-sichern", herkunft: ElementHerkunft(typ: "PrimaryButton", datei: "apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift", zeile: 246))
        let element = register.element(aus: knopf)
        #expect(element.type == "PrimaryButton")
        #expect(element.line == 246)
        #expect(element.frame == TestnotizEintrag.Rechteck(x: 20, y: 120, width: 260, height: 64))

        let unmarkiert = register.element(aus: karte)
        #expect(unmarkiert.type == "Text")
        #expect(unmarkiert.file == nil)
    }

    // Der Schalter bleibt je Bundle-ID gespeichert. Bliebe er nach der
    // Suche an, liefe ein spaeter installierter Release-Build mit Baum.
    @Test func stelltDenSchalterZurueck() async throws {
        let vorher = try #require(AXSchalter.stand)
        let waehrend = await AXSchalter.eingeschaltet { AXSchalter.stand }
        #expect(waehrend == 1)
        #expect(AXSchalter.stand == vorher)
    }

    // Endet der Prozess zwischen Ein- und Ausschalten, bliebe der Schalter
    // gespeichert an; der naechste Debug-Start muss das heilen.
    @Test func aufraeumenStelltEinenLiegengebliebenenSchalterZurueck() throws {
        let vorher = try #require(AXSchalter.stand)
        defer {
            AXSchalter.setzenFuerTest(vorher)
            UserDefaults.standard.removeObject(forKey: AXSchalter.marker)
        }
        AXSchalter.setzenFuerTest(1)
        UserDefaults.standard.set(true, forKey: AXSchalter.marker)

        AXSchalter.aufraeumen()

        #expect(AXSchalter.stand == 0)
        #expect(UserDefaults.standard.object(forKey: AXSchalter.marker) == nil)
    }

    // Der Beweis aus dem Spike, im echten Ziel: ohne VoiceOver liefert der
    // Baum nach dem Einschalten Label UND die Kennung von der Aufrufstelle.
    @Test func findetSwiftUIElementMitKennungImProzess() async throws {
        let szene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let fenster = UIWindow(windowScene: szene)
        fenster.rootViewController = UIHostingController(rootView: VStack(spacing: 40) {
            Text("Oben")
            PrimaryButton(title: "Satz 2 sichern") {}
                .testnotizElement("geraet.satz-sichern", typ: "PrimaryButton")
        }.padding())
        fenster.windowLevel = .alert
        fenster.isHidden = false
        defer { fenster.isHidden = true }
        try await Task.sleep(for: .milliseconds(500))

        let alle = await AXSchalter.eingeschaltet { AccessibilityBaum.sammeln(ab: fenster) }
        let knopfRahmen = try #require(alle.first { $0.kennung == "geraet.satz-sichern" }?.rahmen)
        let punkt = CGPoint(x: knopfRahmen.midX, y: knopfRahmen.midY)

        let gefunden = await AccessibilityBaum.element(an: punkt, szene: szene, ohne: UIWindow())
        #expect(gefunden?.kennung == "geraet.satz-sichern")
        #expect(gefunden?.label == "Satz 2 sichern")
        #expect(gefunden?.typ == "Button")
    }
}
#endif
