import SwiftUI

/// Sechs sichtbare Kaestchen, dahinter ein fast unsichtbares TextField als
/// Ziffernblock-Eingabeziel -- Standardmuster fuer Code-Eingaben auf iOS.
struct CodeDigitsView: View {
    @Binding var entry: CodeEntry
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            HStack(spacing: 9) {
                ForEach(0..<CodeEntry.length, id: \.self) { index in
                    let characters = Array(entry.digits)
                    let digit = index < characters.count ? String(characters[index]) : ""
                    Text(digit)
                        .font(.system(size: 28, weight: .black).monospacedDigit())
                        .frame(maxWidth: .infinity)
                        .frame(height: 66)
                        .background(DesignSystem.Color.surface)
                        // clipShape VOR overlay: umgekehrt schneidet die
                        // Maske die aeussere Haelfte der Kontur weg -- hier
                        // besonders sichtbar, weil das aktive Kaestchen
                        // eine 1,5pt-Akzentkontur traegt und damit nur noch
                        // eine halbe uebrig bliebe (Vorlage: InlineBanner).
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                        .overlay(
                            RoundedRectangle(cornerRadius: 13)
                                .stroke(
                                    index == characters.count ? DesignSystem.Color.accent : DesignSystem.Color.line,
                                    lineWidth: index == characters.count ? 1.5 : 1
                                )
                        )
                }
            }
            TextField("", text: Binding(
                get: { entry.digits },
                set: { entry = CodeEntry(digits: $0) }
            ))
            .keyboardType(.numberPad)
            .focused($isFocused)
            .opacity(0.02)
            .accessibilityLabel("Bestätigungscode")
        }
        .onAppear { isFocused = true }
        .onTapGesture { isFocused = true }
    }
}

#Preview {
    CodeDigitsView(entry: .constant(CodeEntry(digits: "419")))
        .padding()
        .background(DesignSystem.Color.bg)
}
