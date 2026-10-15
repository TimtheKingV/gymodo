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
                        // Zahl gross, Einheit klein daneben, auch leer (Testnotiz 15.10., #4).
                        let teile = Zahlformat.cardioTeile(wert, modell.cardio[wert])
                        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.s4) {
                            Text(teile.zahl)
                                .font(.system(size: 28, weight: .black).monospacedDigit())
                                .foregroundStyle(DesignSystem.Color.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            if !teile.einheit.isEmpty {
                                Text(teile.einheit)
                                    .font(DesignSystem.Typography.uebungsname)
                                    .foregroundStyle(DesignSystem.Color.textMuted)
                            }
                        }
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
                .presentationDetents([.height(340)])
        }
    }
}

extension CardioWert: Identifiable { var id: String { rawValue } }

/// Die Felder, zwischen denen der Cursor im Eingabeblatt springt
/// (Testnotiz 15.10., #2 #3).
private enum CardioFeld: Hashable { case einzel, h, m, s, km, meter }

/// Die Zahleneingabe zu einem Knopf. "Leeren" nimmt den Wert aus dem Satz.
///
/// Jedes Feld traegt seine Einheit ueber der Zahl, eine einzelne Eingabe
/// steht zentriert (Testnotiz 15.10., #1 #3 #4). Im Feld mit dem Cursor
/// steht kein grauer Platzhalter, in den anderen eine 0 (#2).
struct CardioWertSheet: View {
    let wert: CardioWert
    let start: Double?
    let beiFertig: (Double?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    /// Texte statt Zahlen: eine getippte 0 bleibt stehen, ein leeres Feld
    /// ist leer. Stunden, Minuten, Sekunden bzw. Kilometer, Meter.
    @State private var felder: [CardioFeld: String] = [:]
    @FocusState private var fokus: CardioFeld?

    private func zahl(_ feld: CardioFeld) -> Int { Int(felder[feld] ?? "") ?? 0 }
    private var teile: (h: Int, m: Int, s: Int) { (zahl(.h), zahl(.m), zahl(.s)) }

    private var ergebnis: Result<Double, CardioEingabe.Fehler> {
        switch wert {
        case .zeit: CardioEingabe.zeit(stunden: zahl(.h), minuten: zahl(.m), sekunden: zahl(.s))
        case .strecke: CardioEingabe.strecke(kilometer: zahl(.km), meter: zahl(.meter))
        default: CardioEingabe.zahl(text, fuer: wert)
        }
    }

    private var uebernehmbar: Bool {
        if case .success = ergebnis { true } else { false }
    }

    /// Was unter dem Feld steht. Ein frisch geoeffnetes, leeres Zeitblatt
    /// bleibt ruhig (alle drei Teile 0); eine Zeit mit Minuten oder Sekunden
    /// ueber 59 bekommt ihren Grund.
    static func hinweis(wert: CardioWert, ergebnis: Result<Double, CardioEingabe.Fehler>,
                        teile: (h: Int, m: Int, s: Int)) -> String? {
        guard case .failure(let fehler) = ergebnis else { return nil }
        switch fehler {
        case .ausserhalb(let text):
            if wert == .zeit, teile == (0, 0, 0) { return nil }
            return text
        case .keineZahl:
            switch wert {
            case .zeit: return "Minuten und Sekunden bis 59."
            case .strecke: return "Meter bis 999 – für mehr „km“."
            default: return nil
            }
        case .leer:
            return nil
        }
    }

    /// Fuer die Strecke gilt "0 / 0" wie bei der Zeit als ruhig leer.
    private var hinweis: String? {
        if wert == .strecke, zahl(.km) == 0, zahl(.meter) == 0 { return nil }
        return Self.hinweis(wert: wert, ergebnis: ergebnis, teile: teile)
    }

    /// Ein Eingabefeld mit der Einheit darueber.
    private func feld(_ id: CardioFeld, einheit: String, maxZiffern: Int? = nil) -> some View {
        VStack(spacing: DesignSystem.Spacing.s4) {
            Text(einheit)
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.textMuted)
            TextField(fokus == id ? "" : "0", text: Binding(
                get: { id == .einzel ? text : (felder[id] ?? "") },
                set: { neu in
                    if id == .einzel { text = neu; return }
                    let ziffern = String(neu.filter(\.isNumber).prefix(maxZiffern ?? 6))
                    felder[id] = ziffern
                    weiter(von: id, text: ziffern)
                }))
                .keyboardType(id == .einzel && !wert.ganzzahlig ? .decimalPad : .numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 40, weight: .black).monospacedDigit())
                .focused($fokus, equals: id)
                .accessibilityLabel(einheit)
                .testnotizElement(id == .einzel ? "geraet.cardio.eingabe" : "geraet.cardio.eingabe.\(einheit)",
                                  typ: "TextField")
        }
        .frame(maxWidth: .infinity)
    }

    /// Cursor-Sprung der Zeit (Testnotiz 15.10., #2); die Regel steht in
    /// `CardioEingabe.springt`.
    private func weiter(von id: CardioFeld, text: String) {
        let zeitfeld: CardioEingabe.ZeitFeld
        switch id {
        case .h: zeitfeld = .stunden
        case .m: zeitfeld = .minuten
        default: return
        }
        guard wert == .zeit, CardioEingabe.springt(von: zeitfeld, text: text) else { return }
        fokus = zeitfeld == .stunden ? .m : .s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
            Text(wert.name).font(DesignSystem.Typography.detailScreentitel)
            HStack(alignment: .bottom, spacing: DesignSystem.Spacing.s12) {
                switch wert {
                case .zeit:
                    feld(.h, einheit: "Stunden", maxZiffern: 2)
                    feld(.m, einheit: "Minuten", maxZiffern: 2)
                    feld(.s, einheit: "Sekunden", maxZiffern: 2)
                case .strecke:
                    feld(.km, einheit: "km", maxZiffern: 3)
                    feld(.meter, einheit: "m", maxZiffern: 3)
                default:
                    feld(.einzel, einheit: wert.einheit)
                }
            }
            if let hinweis {
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
                switch wert {
                case .zeit:
                    let t = CardioEingabe.zeitTeile(Int(start))
                    felder = [.h: t.h == 0 ? "" : "\(t.h)", .m: t.m == 0 ? "" : "\(t.m)", .s: t.s == 0 ? "" : "\(t.s)"]
                case .strecke:
                    let t = CardioEingabe.streckeTeile(Int(start))
                    felder = [.km: t.km == 0 ? "" : "\(t.km)", .meter: t.m == 0 ? "" : "\(t.m)"]
                default: text = Zahlformat.cardioZahl(wert, start)
                }
            }
            fokus = wert == .zeit ? .h : wert == .strecke ? .km : .einzel
        }
    }
}
