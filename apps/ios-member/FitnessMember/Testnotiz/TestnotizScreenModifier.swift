import SwiftUI

#if DEBUG
private struct TestnotizScreen: ViewModifier {
    let datei: String
    let kontext: [String: String]
    /// Einmal je Modifier-Identitaet. Ein Token aus body waere bei jedem
    /// Neuaufbau neu, und onDisappear faende sein onAppear nicht mehr.
    @State private var token = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear {
                Testnotiz.shared.stapel.erschienen(ScreenEintrag(token: token, datei: datei, kontext: kontext))
            }
            .onDisappear {
                Testnotiz.shared.stapel.verschwunden(token: token)
            }
            .onChange(of: kontext) { _, neu in
                Testnotiz.shared.stapel.kontextAktualisieren(token: token, kontext: neu)
            }
    }
}

extension View {
    /// An die aeusserste View des Screen-Inhalts -- bei Screens mit eigenem
    /// NavigationStack an die Wurzel INNERHALB des Stacks, sonst verschwindet
    /// beim Push nichts.
    func testnotizScreen(kontext: [String: String] = [:], datei: String = #filePath) -> some View {
        modifier(TestnotizScreen(datei: Quellpfad.relativ(datei), kontext: kontext))
    }
}
#else
extension View {
    /// Release: ohne #filePath, damit kein Pfad des Build-Macs ins Binary kommt.
    @inline(__always)
    func testnotizScreen(kontext: [String: String] = [:]) -> some View { self }
}
#endif
