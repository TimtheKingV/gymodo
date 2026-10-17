import ImageIO
import SwiftUI
import UIKit

/// Geraetefotos auf Vorschaugroesse dekodieren.
///
/// Bewusst nicht AsyncImage: das dekodiert in voller Aufloesung, und die
/// Fotos kommen unverkleinert aus dem Upload (bis 10 MiB, keine
/// Vorschaugroesse am Server).
enum Vorschau {
    /// `kantePixel` ist die Zielgroesse der KURZEN Kante, nicht der langen.
    /// Die Zeile zeigt ein quadratisches 56x56pt-Bild (`.scaledToFill`),
    /// das genau die kurze Kante der Vorlage abbildet: ein reines
    /// `kCGImageSourceThumbnailMaxPixelSize` begrenzt aber die LANGE Kante,
    /// bei einem nicht quadratischen Foto waere die kurze Kante danach
    /// kleiner als kantePixel und `.scaledToFill` streckt sie unscharf hoch.
    static func verkleinert(_ daten: Data, kantePixel: Int) -> CGImage? {
        // ShouldCache false: sonst haelt die Quelle die volle Bitmap trotzdem.
        guard let quelle = CGImageSourceCreateWithData(
            daten as CFData, [kCGImageSourceShouldCache: false] as CFDictionary
        ) else { return nil }
        let optionen: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: langeKantenGroesse(quelle, kantePixel: kantePixel),
        ]
        return CGImageSourceCreateThumbnailAtIndex(quelle, 0, optionen as CFDictionary)
    }

    /// Rechnet die Zielgroesse der KURZEN Kante (kantePixel) in eine
    /// Zielgroesse der LANGEN Kante um, denn nur die kennt
    /// ThumbnailMaxPixelSize: `min(laengste Originalkante, kantePixel *
    /// laengste / kuerzeste)`. Das vergroessert nie (das `min` mit der
    /// Originalkante) und macht die kurze Kante nach der Verkleinerung
    /// genau kantePixel gross. Fehlen die Originalmasse, bleibt kantePixel
    /// die Vorgabe wie bisher (ThumbnailMaxPixelSize begrenzt dann die
    /// lange Kante, das ist besser als gar keine Verkleinerung).
    private static func langeKantenGroesse(_ quelle: CGImageSource, kantePixel: Int) -> Int {
        guard let eigenschaften = CGImageSourceCopyPropertiesAtIndex(quelle, 0, nil) as? [CFString: Any],
              let breite = eigenschaften[kCGImagePropertyPixelWidth] as? Int,
              let hoehe = eigenschaften[kCGImagePropertyPixelHeight] as? Int,
              breite > 0, hoehe > 0
        else { return kantePixel }
        let laengste = Double(max(breite, hoehe))
        let kuerzeste = Double(min(breite, hoehe))
        let ziel = Double(kantePixel) * laengste / kuerzeste
        return Int(min(laengste, ziel).rounded())
    }
}

/// Laedt und merkt sich Vorschaubilder je Modell.
///
/// Schluessel ist das Modell, nicht die URL: die signierte URL traegt einen
/// Token und ist bei jedem Oeffnen der Liste eine andere.
actor VorschauLader {
    private let session: URLSession
    private var fertig: [String: UIImage] = [:]
    /// Laufende Downloads je Modell. Ohne das saehe eine zweite Zeile
    /// desselben Modells den fertig-Cache noch leer (Actor-Reentrancy legt
    /// den ersten Download bei seinem await frei) und stiesse einen
    /// zweiten Download desselben Originalfotos an.
    private var laufend: [String: Task<UIImage?, Never>] = [:]

    // Ephemeral statt .shared: die URL traegt einen Token, der nur 15
    // Minuten gilt und bei jedem Oeffnen der Liste ein anderer ist -- eine
    // im URLCache abgelegte Antwort wuerde nie wieder treffen und dort nur
    // Platz belegen.
    /// Mit Ablage landet jedes Original auf der Platte und ueberlebt den
    /// Neustart (Testnotiz 11.10., #14); vorher lud jeder Start alle Fotos
    /// der Liste neu.
    private let ablage: Medienablage?

    init(session: URLSession = URLSession(configuration: .ephemeral), ablage: Medienablage? = nil) {
        self.session = session
        self.ablage = ablage
    }

    func bild(modellId: String, url: URL, kantePixel: Int) async -> UIImage? {
        if let vorhanden = fertig[modellId] { return vorhanden }
        if let laufenderDownload = laufend[modellId] {
            return await laufenderDownload.value
        }
        // Erzeugen und in `laufend` ablegen passiert hier ohne await
        // dazwischen: eine gleichzeitige zweite Zeile desselben Modells
        // sieht den Eintrag deshalb garantiert, bevor sie selbst einen
        // Download anstossen koennte.
        let download = Task<UIImage?, Never> { [session, ablage] in
            let daten: Data?
            if let ablage {
                // Schluessel ist der Pfad ohne Token: er bleibt ueber
                // Signaturen hinweg derselbe.
                let datei = await ablage.datei(schluessel: modellId,
                                               quelle: Medienquelle(url: url, pfad: url.path))
                daten = datei.flatMap { try? Data(contentsOf: $0) }
            } else if let geladen = try? await session.data(from: url),
                      (geladen.1 as? HTTPURLResponse)?.statusCode == 200 {
                daten = geladen.0
            } else {
                daten = nil
            }
            guard let daten, let verkleinert = Vorschau.verkleinert(daten, kantePixel: kantePixel)
            else { return nil }
            return UIImage(cgImage: verkleinert)
        }
        laufend[modellId] = download
        let bild = await download.value
        laufend[modellId] = nil
        if let bild {
            fertig[modellId] = bild
        }
        // Eine Zeile, die waehrenddessen wegscrollt, storniert den
        // gemeinsamen Download nicht: der Task gehoert dem Modell, nicht
        // der Zeile -- eine andere Zeile desselben Modells oder ein
        // erneuter Besuch braucht das Ergebnis noch, und ein storniertes
        // Ergebnis wuerde beide leer ausgehen lassen.
        return bild
    }
}

/// Der Platz fuer das Sinnbild einer Uebung (Bild oder GIF), links neben
/// ihrem Namen -- in Uebungsliste, Uebungswechsel und Blockliste des
/// Trainings (Testnotiz 06.10., #3, #9, #14).
///
/// Noch ohne Inhalt: eine Uebung hat in der Datenbank kein Bildfeld
/// (`exercises` kennt nur Name und Korridor). Der Rahmen steht trotzdem
/// schon, damit die Namen jetzt buendig untereinander stehen und das Bild
/// spaeter nur eingesetzt werden muss. Gleiche Gestalt wie der
/// Geraete-Platzhalter in GeraeteAuswahlView, nur mit einer Figur statt
/// der Hantel -- die steht dort fuer das Geraet.
struct Uebungsbild: View {
    var kante: CGFloat = 56

    var body: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
            .fill(DesignSystem.Color.surfaceRaised)
            .frame(width: kante, height: kante)
            .overlay {
                Image(systemName: "figure.strengthtraining.functional")
                    .font(.system(size: kante * 0.36, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .stroke(DesignSystem.Color.line, lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}

/// Das grosse Geraetefoto oben auf Geraeteseite und Einweisung, aus der
/// Fotoablage statt per AsyncImage (Testnotiz 11.10., #14).
///
/// Schluessel ist die Modell-ID wie im VorschauLader der Liste: offline
/// (ohne signierte URL) findet die Seite so das Foto, das die Liste schon
/// abgelegt hat. Dekodiert und verkleinert wird abseits des Main-Threads
/// -- die Originale sind bis 10 MB gross, und die Dekodierung beim
/// Zeichnen liess die Seite haengen (Offline-Spec 1b).
struct Geraetefoto: View {
    let modellId: String
    let url: URL?
    let hoehe: CGFloat
    /// Mit Breite ein kleines Bild neben dem Namen (Testnotiz 17.10., #6);
    /// ohne füllt es die Breite wie oben auf der Seite.
    var breite: CGFloat? = nil

    @State private var bild: UIImage?

    /// Kurze Kante in Pixeln: reicht fuer die volle Breite bei 3x.
    private static let kantePixel = 1200

    var body: some View {
        ZStack {
            DesignSystem.Color.surfaceRaised
            if let bild {
                Image(uiImage: bild).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: breite == nil ? 28 : 20))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
        }
        .frame(width: breite, height: hoehe)
        .frame(maxWidth: breite == nil ? .infinity : nil)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityHidden(true)
        // Der Pfad gehoert zur id, nicht die URL: die Signatur wechselt bei
        // jedem Laden des Kontexts, das Foto nicht.
        .task(id: [modellId, url?.path]) {
            if let geladen = await Self.laden(modellId: modellId, url: url,
                                              kantePixel: Self.kantePixel, ablage: .fotos) {
                bild = geladen
            }
        }
    }

    nonisolated static func laden(modellId: String, url: URL?, kantePixel: Int,
                                  ablage: Medienablage) async -> UIImage? {
        let quelle = url.map { Medienquelle(url: $0, pfad: $0.path) }
        guard let datei = await ablage.datei(schluessel: modellId, quelle: quelle) else { return nil }
        let verkleinert = await Task.detached(priority: .userInitiated) { () -> CGImage? in
            guard let daten = try? Data(contentsOf: datei) else { return nil }
            return Vorschau.verkleinert(daten, kantePixel: kantePixel)
        }.value
        return verkleinert.map { UIImage(cgImage: $0) }
    }
}
