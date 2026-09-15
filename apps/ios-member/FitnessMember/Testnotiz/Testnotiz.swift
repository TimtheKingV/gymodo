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
        case ruhe, menue
    }

    var modus: Modus = .ruhe
    /// Bildschirmrahmen des Knopfs. Ausserhalb davon laesst das Fenster in
    /// Ruhe jede Beruehrung zur App durch.
    var knopfRahmen: CGRect = .zero
    var stapel = TestnotizScreenStapel()

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
        guard fenster == nil else { return }
        let neu = TestnotizFenster(windowScene: szene)
        let host = UIHostingController(rootView: TestnotizOberflaeche())
        host.view.backgroundColor = .clear
        neu.rootViewController = host
        neu.isHidden = false
        fenster = neu
    }

    func knopfGetippt() {
        modus = .menue
    }

    func zurRuhe() {
        modus = .ruhe
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
