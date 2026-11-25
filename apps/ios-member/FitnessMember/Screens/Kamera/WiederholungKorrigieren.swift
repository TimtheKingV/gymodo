import SwiftUI

/// Sheet mit einem Rad 0...max(30, n + 10): die Zahl der Wiederholungen nachtragen.
struct WiederholungKorrigieren: View {
    @State private var wert: Int
    private let obergrenze: Int
    let beiUebernehmen: (Int) -> Void

    init(wiederholungen: Int, beiUebernehmen: @escaping (Int) -> Void) {
        _wert = State(initialValue: wiederholungen)
        obergrenze = max(30, wiederholungen + 10)
        self.beiUebernehmen = beiUebernehmen
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.s16) {
            Text("Wdh. korrigieren")
                .font(.system(size: 19, weight: .heavy))
                .padding(.top, DesignSystem.Spacing.s24)
            Picker("Wiederholungen", selection: $wert) {
                ForEach(0...obergrenze, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            PrimaryButton(title: "Übernehmen") { beiUebernehmen(wert) }
        }
        .padding(.horizontal, DesignSystem.Spacing.s16)
        .padding(.bottom, DesignSystem.Spacing.s16)
        .background(DesignSystem.Color.bg.ignoresSafeArea())
        .foregroundStyle(DesignSystem.Color.text)
        .presentationDetents([.medium])
    }
}
