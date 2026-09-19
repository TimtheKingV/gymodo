#if DEBUG
import Foundation
import Testing
import UIKit
@testable import FitnessMember

// Knopf -> Modus -> Sichern ohne Overlay-Fenster: dort lag der Abbruch-Fehler
// der Element-Suche, und nur eine eigene Instanz mit tmp-Ablage kommt ohne
// Szene aus.
@MainActor
struct TestnotizAblaufTests {
    private func entwurf() -> Testnotiz.Entwurf {
        let bild = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { kontext in
            UIColor.red.setFill()
            kontext.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        return Testnotiz.Entwurf(zeitpunkt: Date(), vollbild: bild, screen: nil)
    }

    @Test func sichernSchreibtEinenEintragUndGehtZurRuhe() async throws {
        let testnotiz = Testnotiz()
        let wurzel = FileManager.default.temporaryDirectory.appendingPathComponent("testnotiz-ablauf-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: wurzel) }
        testnotiz.ablageWurzel = wurzel
        testnotiz.entwurf = entwurf()
        testnotiz.modus = .notiz

        await testnotiz.sichern(notiz: "x")

        let ordner = try #require(testnotiz.ablage?.ordner)
        #expect(ordner.deletingLastPathComponent().standardizedFileURL == wurzel.standardizedFileURL)
        #expect(FileManager.default.fileExists(atPath: ordner.appendingPathComponent("01-voll.png").path))
        let json = try Data(contentsOf: ordner.appendingPathComponent("sitzung.json"))
        let sitzung = try JSONDecoder.testnotiz().decode(TestnotizSitzung.self, from: json)
        #expect(sitzung.entries.count == 1)
        #expect(sitzung.entries.first?.note == "x")
        #expect(testnotiz.eintragsanzahl == 1)
        #expect(testnotiz.modus == .ruhe)
        #expect(testnotiz.letzterFehler == nil)
        #expect(try wurzel.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }

    // "Seite" ist ein Ausschnitt ohne Ziehen: das ganze Vollbild als Rechteck,
    // aber ohne eigenes Ausschnittbild -- das waere dasselbe wie das Vollbild.
    @Test func seiteGewaehltUebernimmtDenRahmenOhneEigenesBild() throws {
        let testnotiz = Testnotiz()
        let neu = entwurf()
        testnotiz.entwurf = neu
        testnotiz.modus = .menue

        testnotiz.seiteGewaehlt()

        let entwurfNachher = try #require(testnotiz.entwurf)
        #expect(entwurfNachher.art == .crop)
        #expect(entwurfNachher.ausschnitt == nil)
        #expect(entwurfNachher.ausschnittsrahmen?.points == TestnotizEintrag.Rechteck(CGRect(origin: .zero, size: neu.vollbild.size)))
        #expect(testnotiz.modus == .notiz)
    }

    // Abbrechen waehrend der Element-Suche darf den verworfenen Entwurf nicht
    // als Notiz-Blatt zurueckholen.
    @Test func elementSucheNachZurRuheSchreibtNichts() async {
        let testnotiz = Testnotiz()
        testnotiz.entwurf = entwurf()
        testnotiz.modus = .element

        testnotiz.zurRuhe()
        #expect(testnotiz.suchtElement == false)

        await testnotiz.elementGewaehlt(CGPoint(x: 10, y: 10))
        #expect(testnotiz.modus == .ruhe)
        #expect(testnotiz.entwurf == nil)
        #expect(testnotiz.suchtElement == false)
    }
}
#endif
