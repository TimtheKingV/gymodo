import SwiftUI

struct ContentView: View {
    let token: String?

    var body: some View {
        VStack(spacing: 16) {
            if let token {
                Text("Tag erkannt")
                    .font(.headline)
                Text(token)
                    .font(.system(.body, design: .monospaced))
                    .accessibilityIdentifier("tag-token")
            } else {
                Text("Noch kein Tag gescannt")
                    .accessibilityIdentifier("tag-empty")
            }
        }
        .padding()
    }
}
