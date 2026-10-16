import Foundation
import SwiftUI
import Testing
@testable import FitnessMember

@Suite("Muskelmodell")
struct MuskelModellTests {
    private func muskel(_ key: String, _ rolle: GeraetMuskel.Rolle, name: String? = nil) -> GeraetMuskel {
        GeraetMuskel(key: key, name: name ?? key, role: rolle)
    }

    // MARK: Pfadparser

    @Test("M/L/Z ergibt die erwartete Begrenzung")
    func pfadBegrenzung() {
        let rahmen = MuskelModell.pfad("M 0,0 L 10,0 L 10,10 Z").boundingRect
        #expect(rahmen == CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    @Test("C endet am Zielpunkt")
    func pfadKurveEndetAmZiel() {
        let pfad = MuskelModell.pfad("M 0,0 C 5,10 15,10 20,0")
        #expect(pfad.currentPoint == CGPoint(x: 20, y: 0))
    }

    @Test("Zahlen ohne Komma und mit Minus werden gelesen")
    func pfadNegativeZahlen() {
        let rahmen = MuskelModell.pfad("M -5 -5 L 5,5 Z").boundingRect
        #expect(rahmen == CGRect(x: -5, y: -5, width: 10, height: 10))
    }

    // MARK: Farbwahl

    @Test("Hauptmuskel nimmt den Akzent")
    func fuellungHauptmuskel() {
        let muskeln = [muskel("pectorals", .primary)]
        #expect(MuskelModell.fuellung(fuer: "pectorals", in: muskeln) == DesignSystem.Color.accent)
    }

    @Test("Unterstützende laufen durch drei Töne und bleiben am letzten stehen")
    func fuellungUnterstuetzend() {
        let muskeln = [
            muskel("pectorals", .primary),
            muskel("triceps", .secondary),
            muskel("deltoid_anterior", .secondary),
            muskel("biceps", .secondary),
            muskel("forearms", .secondary),
        ]
        #expect(MuskelModell.fuellung(fuer: "triceps", in: muskeln) == Color(hex: 0xA8CC2A))
        #expect(MuskelModell.fuellung(fuer: "deltoid_anterior", in: muskeln) == Color(hex: 0x819B2A))
        #expect(MuskelModell.fuellung(fuer: "biceps", in: muskeln) == Color(hex: 0x5E7220))
        // Der vierte darf nicht ueber das Ende der Stufen hinauslaufen.
        #expect(MuskelModell.fuellung(fuer: "forearms", in: muskeln) == Color(hex: 0x5E7220))
    }

    @Test("Nicht angesprochener Muskel hat keine Füllung")
    func fuellungFehlt() {
        let muskeln = [muskel("pectorals", .primary)]
        #expect(MuskelModell.fuellung(fuer: "quads", in: muskeln) == nil)
    }

    @Test("Unbekannter Schlüssel wirft nicht und behält seine Rollenfarbe")
    func unbekannterSchluessel() {
        let muskeln = [muskel("zzz", .secondary), muskel("pectorals", .primary)]
        #expect(MuskelModell.fuellung(fuer: "zzz", in: muskeln) == Color(hex: 0xA8CC2A))
        #expect(MuskelModell.zeigtModell(muskeln))
        #expect(!MuskelModell.zeigtModell([muskel("zzz", .primary)]))
    }

    // MARK: Darstellbarkeit

    @Test("zeigtModell nur mit mindestens einer Fläche")
    func zeigtModell() {
        #expect(!MuskelModell.zeigtModell([muskel("deep_core", .primary)]))
        #expect(!MuskelModell.zeigtModell([]))
        #expect(MuskelModell.zeigtModell([muskel("pectorals", .primary)]))
        #expect(MuskelModell.zeigtModell([muskel("deep_core", .primary), muskel("pectorals", .secondary)]))
    }

    @Test("Jeder darstellbare Katalogmuskel hat in beiden Modellen eine Fläche")
    func katalogAbgedeckt() throws {
        // Der Katalog liegt nicht im Bundle; der Pfad leitet sich aus dieser
        // Datei ab (apps/ios-member/FitnessMemberTests -> Repo-Wurzel).
        let wurzel = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let daten = try Data(contentsOf: wurzel.appendingPathComponent("catalog/gymtavo.json"))
        struct Katalog: Decodable { struct Muskel: Decodable { let key: String }; let muscles: [Muskel] }
        let katalog = try JSONDecoder().decode(Katalog.self, from: daten)
        let ohneFlaeche: Set = ["deep_core", "hip_flexors", "neck", "pelvic_floor"]

        let geometrie = try #require(MuskelModell.geometrie)
        for modell in [geometrie.maennlich, geometrie.weiblich] {
            let vorhanden = modell.schluessel
            for key in katalog.muscles.map(\.key) where !ohneFlaeche.contains(key) {
                #expect(vorhanden.contains(key), "\(key) fehlt im Modell")
            }
            for key in ohneFlaeche {
                #expect(!vorhanden.contains(key), "\(key) hat unerwartet eine Fläche")
            }
        }
    }

    @Test("Geometrie trägt Lizenz und beide Ansichten")
    func geometrieGeladen() throws {
        let geometrie = try #require(MuskelModell.geometrie)
        #expect(geometrie.lizenz.contains("ELABBASSI Hicham"))
        #expect(geometrie.maennlich.vorne.viewBox.width == 900)
        #expect(geometrie.weiblich.hinten.viewBox.height == 1538)
        #expect(geometrie.maennlich.vorne.muskeln.contains { $0.clip != nil })
    }

    // MARK: Karte

    @Test("VoiceOver-Label nennt Name und Rolle je Muskel")
    func barrierefreiText() {
        let muskeln = [
            muskel("pectorals", .primary, name: "Brust"),
            muskel("triceps", .secondary, name: "Trizeps"),
        ]
        #expect(MuskelKarte.vorlesetext(muskeln) == "Beanspruchte Muskeln: Brust, Hauptmuskel; Trizeps, unterstützend")
    }

    @MainActor
    @Test("Figur zeichnet die Hauptmuskeln sichtbar in der Akzentfarbe")
    func figurRendert() throws {
        let muskeln = [
            muskel("pectorals", .primary, name: "Brust"),
            muskel("triceps", .secondary, name: "Trizeps"),
            muskel("zzz", .secondary, name: "Unbekannt"),
        ]
        for geschlecht in [Geschlecht.maennlich, .weiblich] {
            let renderer = ImageRenderer(
                content: MuskelFigur(muskeln: muskeln, geschlecht: geschlecht).frame(width: 372)
            )
            renderer.scale = 1
            let bild = try #require(renderer.cgImage)
            #expect(bild.width == 372)
            #expect(Self.akzentPixel(in: bild) > 50)
        }
    }

    @MainActor
    @Test("Karte ohne darstellbaren Muskel bleibt leer")
    func karteOhneFlaeche() {
        let leer = ImageRenderer(content: MuskelKarte(muskeln: [muskel("deep_core", .primary)], geschlecht: nil))
        #expect(leer.cgImage == nil)
        let voll = ImageRenderer(
            content: MuskelKarte(muskeln: [muskel("pectorals", .primary, name: "Brust")], geschlecht: nil)
                .frame(width: 372)
        )
        #expect(voll.cgImage != nil)
    }

    /// Zaehlt Pixel nahe #D4FF3F.
    private static func akzentPixel(in bild: CGImage) -> Int {
        let breite = bild.width, hoehe = bild.height
        var puffer = [UInt8](repeating: 0, count: breite * hoehe * 4)
        let kontext = CGContext(
            data: &puffer, width: breite, height: hoehe, bitsPerComponent: 8, bytesPerRow: breite * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        kontext.draw(bild, in: CGRect(x: 0, y: 0, width: breite, height: hoehe))
        var anzahl = 0
        for i in stride(from: 0, to: puffer.count, by: 4)
        where abs(Int(puffer[i]) - 0xD4) < 12 && abs(Int(puffer[i + 1]) - 0xFF) < 12 && abs(Int(puffer[i + 2]) - 0x3F) < 12 {
            anzahl += 1
        }
        return anzahl
    }
}
