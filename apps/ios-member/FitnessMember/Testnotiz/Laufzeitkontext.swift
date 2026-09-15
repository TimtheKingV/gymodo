#if DEBUG
import UIKit

enum Laufzeitkontext {
    /// Bewusst ohne E-Mail, Token und Anzeigenamen (Architekturprinzip 6):
    /// angemeldet ja/nein und das Studio genuegen, um einen Fund einzuordnen.
    @MainActor
    static func laufzeit(netz: NetzwerkMonitor?, katalog: CatalogStore?, session: SessionStore?) -> TestnotizEintrag.Laufzeit {
        TestnotizEintrag.Laufzeit(
            online: netz?.istOnline ?? false,
            pendingWrites: katalog?.pendingWrites.count ?? 0,
            signedIn: session?.session != nil,
            studioId: katalog?.activeStudioId
        )
    }

    @MainActor
    static func sitzungskopf(jetzt: Date, szene: UIWindowScene?) -> TestnotizSitzung.Kopf {
        let info = Bundle.main.infoDictionary ?? [:]
        let bounds = szene?.screen.bounds ?? .zero
        let scale = szene?.screen.scale ?? 0
        return TestnotizSitzung.Kopf(
            id: "",
            startedAt: jetzt,
            app: TestnotizSitzung.App(
                bundleId: Bundle.main.bundleIdentifier ?? "",
                version: info["CFBundleShortVersionString"] as? String ?? "",
                build: info["CFBundleVersion"] as? String ?? "",
                configuration: "Debug"
            ),
            device: TestnotizSitzung.Geraet(
                model: modellkennung(),
                os: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
                screen: TestnotizSitzung.Bildschirm(
                    width: Double(bounds.width),
                    height: Double(bounds.height),
                    scale: Double(scale)
                )
            )
        )
    }

    /// "iPhone14,4" statt "iPhone": nur die Kennung unterscheidet Groesse
    /// und Aussparung. Im Simulator liefert uname "arm64".
    static func modellkennung() -> String {
        if let simuliert = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simuliert }
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { puffer in
            String(decoding: puffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }
}
#endif
