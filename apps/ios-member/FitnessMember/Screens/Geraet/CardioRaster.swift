import SwiftUI

/// Die Knoepfe am Cardio-Geraet statt der Raeder (Testnotiz 14.10., 18:45
/// #7): je Wert des Geraets einer, vorbelegt, ein Tipp oeffnet die
/// Zahleneingabe. Kein Wert ist Pflicht, einer muss gesetzt sein.
struct CardioRaster: View {
    @Bindable var modell: GeraetModel
    @State private var offen: CardioWert?

    private let spalten = [GridItem(.flexible(), spacing: DesignSystem.Spacing.s12),
                           GridItem(.flexible(), spacing: DesignSystem.Spacing.s12)]

    private func anzeige(_ wert: CardioWert) -> String? {
        modell.cardio[wert].map { Zahlformat.cardioWert(wert, $0) }
    }

    var body: some View {
        LazyVGrid(columns: spalten, spacing: DesignSystem.Spacing.s12) {
            ForEach(modell.cardioListe, id: \.self) { wert in
                Button { offen = wert } label: {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                        Text(wert.name.uppercased())
                            .font(DesignSystem.Typography.label)
                            .tracking(1.5)
                            .foregroundStyle(DesignSystem.Color.textFaint)
                        Text(anzeige(wert) ?? "–")
                            .font(.system(size: 28, weight: .black).monospacedDigit())
                            .foregroundStyle(DesignSystem.Color.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                    .padding(DesignSystem.Spacing.s12)
                    .background(DesignSystem.Color.surface,
                                in: RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(wert.name): \(anzeige(wert) ?? "leer")")
                .testnotizElement("geraet.cardio.\(wert.rawValue)", typ: "Button")
            }
        }
        .sheet(item: $offen) { wert in
            CardioWertSheet(wert: wert, start: modell.cardio[wert]) { modell.cardioSetzen(wert, $0) }
                .presentationDetents([.height(320)])
        }
    }
}

extension CardioWert: Identifiable { var id: String { rawValue } }

/// Die Zahleneingabe zu einem Knopf. "Leeren" nimmt den Wert aus dem Satz.
struct CardioWertSheet: View {
    let wert: CardioWert
    let start: Double?
    let beiFertig: (Double?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var teile = (h: 0, m: 0, s: 0)
    @FocusState private var fokus: Bool

    private var ergebnis: Result<Double, CardioEingabe.Fehler> {
        wert == .zeit ? CardioEingabe.zeit(stunden: teile.h, minuten: teile.m, sekunden: teile.s)
                      : CardioEingabe.zahl(text, fuer: wert)
    }

    private var uebernehmbar: Bool {
        if case .success = ergebnis { true } else { false }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
            Text(wert.name).font(DesignSystem.Typography.detailScreentitel)
            if wert == .zeit {
                ZeitFelder(teile: $teile)
            } else {
                TextField("–", text: $text)
                    .keyboardType(wert.ganzzahlig ? .numberPad : .decimalPad)
                    .font(.system(size: 40, weight: .black).monospacedDigit())
                    .focused($fokus)
                    .testnotizElement("geraet.cardio.eingabe", typ: "TextField")
            }
            if case .failure(.ausserhalb(let hinweis)) = ergebnis {
                Text(hinweis).foregroundStyle(DesignSystem.Color.danger)
            }
            HStack(spacing: DesignSystem.Spacing.s12) {
                SecondaryButton(title: "Leeren") { beiFertig(nil); dismiss() }
                PrimaryButton(title: "Übernehmen", isEnabled: uebernehmbar) {
                    if case .success(let zahl) = ergebnis { beiFertig(zahl); dismiss() }
                }
            }
        }
        .padding(20)
        .onAppear {
            if let start {
                if wert == .zeit { teile = CardioEingabe.zeitTeile(Int(start)) }
                else { text = Zahlformat.cardioZahl(wert, start) }
            }
            fokus = true
        }
    }
}

/// Stunden, Minuten, Sekunden als drei Zahlenfelder. Stunden erst, wenn
/// welche da sind oder nach "+ Stunden".
private struct ZeitFelder: View {
    @Binding var teile: (h: Int, m: Int, s: Int)
    @State private var mitStunden = false

    private func feld(_ titel: String, _ wert: Binding<Int>) -> some View {
        TextField("0", text: Binding(
            get: { wert.wrappedValue == 0 ? "" : String(wert.wrappedValue) },
            set: { wert.wrappedValue = Int($0.filter(\.isNumber)) ?? 0 }))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 40, weight: .black).monospacedDigit())
            .frame(minWidth: 64)
            .accessibilityLabel(titel)
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.s8) {
            if mitStunden || teile.h > 0 {
                feld("Stunden", $teile.h)
                Text(":").font(.system(size: 40, weight: .black))
            }
            feld("Minuten", $teile.m)
            Text(":").font(.system(size: 40, weight: .black))
            feld("Sekunden", $teile.s)
            if !(mitStunden || teile.h > 0) {
                Spacer()
                Button("+ Stunden") { mitStunden = true }
                    .font(DesignSystem.Typography.label)
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
        }
    }
}
