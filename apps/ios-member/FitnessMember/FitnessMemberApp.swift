import SwiftUI

@main
struct FitnessMemberApp: App {
    @State private var token: String?

    var body: some Scene {
        WindowGroup {
            ContentView(token: token)
                .onOpenURL { url in
                    // Ungueltige Links werden still verworfen; der Screen
                    // bleibt im leeren Zustand.
                    if let parsed = TagLink.token(from: url) {
                        token = parsed
                    }
                }
        }
    }
}
