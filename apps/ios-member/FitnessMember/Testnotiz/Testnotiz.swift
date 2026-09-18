import SwiftUI

#if DEBUG
import Observation

/// Der eine Ort, an dem das Modul lebt. Ein Singleton, weil das Fenster
/// eines ist: eine Szene, ein Knopf darueber.
@MainActor
@Observable
final class Testnotiz {
    static let shared = Testnotiz()

    enum Modus: Equatable {
        case ruhe, menue, ausschnitt, element, notiz, sitzung
    }

    /// Was zwischen Knopf-Tipp und Sichern entsteht. Das Foto kommt beim
    /// Tipp auf den Knopf: danach aendert sich die App nicht mehr, weil das
    /// Fenster ab dann alle Beruehrungen faengt.
    struct Entwurf {
        var zeitpunkt: Date
        var vollbild: UIImage
        var screen: TestnotizEintrag.Screen?
        var art: TestnotizEintrag.Art = .note
        var ausschnitt: UIImage?
        var ausschnittsrahmen: TestnotizEintrag.Ausschnittsrahmen?
        var element: TestnotizEintrag.Element?
    }

    var modus: Modus = .ruhe
    /// Bildschirmrahmen des Knopfs. Ausserhalb davon laesst das Fenster in
    /// Ruhe jede Beruehrung zur App durch.
    var knopfRahmen: CGRect = .zero
    var stapel = TestnotizScreenStapel()
    var register = TestnotizElementRegister()
    var entwurf: Entwurf?
    private(set) var eintragsanzahl = 0
    private(set) var letzterFehler: String?
    /// Waehrend der Element-Suche zeigt das Overlay noch Picker und
    /// Abbrechen; ein zweiter Tipp darf keine zweite Suche starten.
    private(set) var suchtElement = false

    /// Tests legen die Sitzungen in tmp ab, statt in die Dateien-App.
    @ObservationIgnored var ablageWurzel: URL = URL.documentsDirectory.appendingPathComponent("Testnotizen")

    @ObservationIgnored private(set) var ablage: TestnotizAblage?
    @ObservationIgnored private(set) var fenster: TestnotizFenster?
    @ObservationIgnored private(set) weak var netz: NetzwerkMonitor?
    @ObservationIgnored private(set) weak var katalog: CatalogStore?
    @ObservationIgnored private(set) weak var session: SessionStore?

    /// Idempotent: RootView kann mehrfach in ein Fenster wandern
    /// (Session-Wechsel), das Overlay-Fenster darf es nur einmal geben.
    func installieren(in szene: UIWindowScene, netz: NetzwerkMonitor, katalog: CatalogStore, session: SessionStore) {
        self.netz = netz
        self.katalog = katalog
        self.session = session
        AXSchalter.aufraeumen()
        guard fenster == nil else { return }
        let neu = TestnotizFenster(windowScene: szene)
        let host = UIHostingController(rootView: TestnotizOberflaeche())
        host.view.backgroundColor = .clear
        neu.rootViewController = host
        neu.isHidden = false
        fenster = neu
    }

    func knopfGetippt() {
        guard let fenster, let szene = fenster.windowScene else { return }
        let screen = stapel.aktueller.map {
            TestnotizEintrag.Screen(name: $0.name, file: $0.datei, stack: stapel.pfad, context: $0.kontext)
        }
        entwurf = Entwurf(
            zeitpunkt: Date(),
            vollbild: Bildschirmfoto.aufnehmen(szene: szene, ohne: fenster),
            screen: screen
        )
        modus = .menue
    }

    func zurRuhe() {
        entwurf = nil
        suchtElement = false
        modus = .ruhe
    }

    /// Wie ausschnittGewaehlt(_:), nur ohne Ziehen: das ganze Vollbild als
    /// Rechteck. Fuer Meldungen, bei denen die ganze Seite zaehlt, nicht ein
    /// Ausschnitt davon.
    func seiteGewaehlt() {
        guard let entwurf else {
            zurRuhe()
            return
        }
        ausschnittGewaehlt(CGRect(origin: .zero, size: entwurf.vollbild.size))
    }

    func ausschnittGewaehlt(_ punkte: CGRect) {
        guard var neu = entwurf, let geschnitten = Ausschnitt.schneiden(neu.vollbild, punkte: punkte) else {
            zurRuhe()
            return
        }
        neu.art = .crop
        neu.ausschnitt = geschnitten.bild
        neu.ausschnittsrahmen = geschnitten.rahmen
        entwurf = neu
        modus = .notiz
    }

    func elementGewaehlt(_ punkt: CGPoint) async {
        // Getrennt vom Guard darunter: ein Tipp waehrend der Suche soll sie
        // nicht ueber zurRuhe() abbrechen, sondern nur verpuffen.
        guard !suchtElement, modus == .element else { return }
        guard var neu = entwurf, let fenster, let szene = fenster.windowScene else {
            zurRuhe()
            return
        }
        suchtElement = true
        let kandidat = await AccessibilityBaum.element(an: punkt, szene: szene, ohne: fenster)
        suchtElement = false
        // In der Pause kann Abbrechen oder ein neuer Knopf-Tipp den Entwurf ersetzt haben; der gehoert dann nicht mehr dieser Suche.
        guard modus == .element, entwurf?.zeitpunkt == neu.zeitpunkt else { return }
        neu.art = .element
        neu.element = kandidat.map { register.element(aus: $0) }
        entwurf = neu
        modus = .notiz
    }

    func nurNotiz() {
        entwurf?.art = .note
        modus = .notiz
    }

    func neueSitzung() {
        ablage = nil
        eintragsanzahl = 0
    }

    /// Das Blatt ist sofort zu; geschrieben wird danach. Wer testet, soll
    /// nicht auf PNG-Kodierung und Protokoll warten.
    func sichern(notiz: String?, audio: URL?) async {
        guard let entwurf else {
            zurRuhe()
            return
        }
        zurRuhe()
        let laufzeit = Laufzeitkontext.laufzeit(netz: netz, katalog: katalog, session: session)
        let protokoll = await TestnotizProtokoll.lesenImHintergrund(seit: 300, bis: entwurf.zeitpunkt)
        let eintrag = TestnotizEintrag(
            id: UUID(), index: 0, createdAt: entwurf.zeitpunkt, kind: entwurf.art,
            screen: entwurf.screen, screenshot: "", crop: nil, cropRect: entwurf.ausschnittsrahmen,
            element: entwurf.element, note: notiz, audio: nil, transcript: nil,
            runtime: laufzeit, log: protokoll
        )
        do {
            let ablage = try ablageHolen(jetzt: entwurf.zeitpunkt)
            let gesichert = try await ablage.schreiben(
                eintrag,
                voll: entwurf.vollbild.pngData() ?? Data(),
                ausschnitt: entwurf.ausschnitt?.pngData(),
                audio: audio
            )
            // Erst ein gelungener Eintrag loescht die alte Meldung -- sonst loeschte der naechste Knopf-Tipp sie, bevor das Menue sie zeigt.
            letzterFehler = nil
            let anzahl = await ablage.anzahl
            // "Neue Sitzung" in der Pause hat den Zaehler schon auf 0 gesetzt; die alte Ablage darf ihn nicht zurueckdrehen.
            if self.ablage === ablage { eintragsanzahl = anzahl }
            if let name = gesichert.audio {
                let datei = ablage.ordner.appendingPathComponent(name)
                let index = gesichert.index
                Task {
                    guard let text = await Transkription.transkribieren(datei) else { return }
                    try? await ablage.transkriptNachtragen(index: index, text: text)
                }
            }
        } catch {
            letzterFehler = "Nicht gesichert: \(error.localizedDescription)"
        }
    }

    private func ablageHolen(jetzt: Date) throws -> TestnotizAblage {
        if let ablage { return ablage }
        let neu = try TestnotizAblage(wurzel: ablageWurzel, kopf: Laufzeitkontext.sitzungskopf(jetzt: jetzt, szene: fenster?.windowScene))
        // Screenshots und Sprachnotizen sind Arbeitsmaterial, kein Nutzerdatum; im Backup belegten sie nur Platz. Scheitert es, wird trotzdem gesichert.
        var werte = URLResourceValues()
        werte.isExcludedFromBackup = true
        var wurzel = ablageWurzel
        try? wurzel.setResourceValues(werte)
        ablage = neu
        return neu
    }
}

/// Meldet das erste Fenster, in das RootView gelangt. didMoveToWindow statt
/// updateUIView: beim ersten Update haengt die View noch in keinem Fenster,
/// und ein weiteres Update ist nicht zugesichert.
private final class InstallationsAnker: UIView {
    var beiFenster: ((UIWindowScene) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let szene = window?.windowScene { beiFenster?(szene) }
    }
}

private struct TestnotizInstallation: UIViewRepresentable {
    let netz: NetzwerkMonitor
    let katalog: CatalogStore
    let session: SessionStore

    func makeUIView(context: Context) -> InstallationsAnker {
        let anker = InstallationsAnker()
        anker.isUserInteractionEnabled = false
        anker.beiFenster = { [netz, katalog, session] szene in
            Testnotiz.shared.installieren(in: szene, netz: netz, katalog: katalog, session: session)
        }
        return anker
    }

    func updateUIView(_ uiView: InstallationsAnker, context: Context) {}
}

extension View {
    func testnotizInstallieren(netz: NetzwerkMonitor, katalog: CatalogStore, session: SessionStore) -> some View {
        background(TestnotizInstallation(netz: netz, katalog: katalog, session: session))
    }
}
#else
extension View {
    /// Release: kein Fenster, kein Knopf.
    @inline(__always)
    func testnotizInstallieren(netz: NetzwerkMonitor, katalog: CatalogStore, session: SessionStore) -> some View { self }
}
#endif
