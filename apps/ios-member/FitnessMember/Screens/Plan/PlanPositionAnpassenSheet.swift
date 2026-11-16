import SwiftUI
import UIKit

/// Blatt "Uebung anpassen" (P4, Testnotiz 10.11. #7): Saetze, Wdh, Pause bzw. Dauer einer
/// Position, dazu Tauschen und Entfernen. Reserve und Aufwaermsatz legt der Plan fest.
/// Ohne Aenderung gibt "Uebernehmen" die Ausgangswerte zurueck, damit nichts als geaendert gilt.
struct PlanPositionAnpassenSheet: View {
    let modell: UebungskarteModell
    let foto: UIImage?
    let position: EntwurfsPosition
    let darfEntfernen: Bool
    let beiUebernehmen: (_ saetze: Int, _ wdhVon: Int?, _ wdhBis: Int?, _ pauseSek: Int, _ dauerMin: Int?) -> Void
    let beiTauschen: () -> Void
    let beiEntfernen: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var saetze: Int
    @State private var wdhVon: Int
    @State private var wdhBis: Int
    @State private var pauseSek: Int
    @State private var dauerMin: Int

    init(
        modell: UebungskarteModell, foto: UIImage? = nil, position: EntwurfsPosition, darfEntfernen: Bool,
        beiUebernehmen: @escaping (_ saetze: Int, _ wdhVon: Int?, _ wdhBis: Int?, _ pauseSek: Int, _ dauerMin: Int?) -> Void,
        beiTauschen: @escaping () -> Void, beiEntfernen: @escaping () -> Void
    ) {
        self.modell = modell
        self.foto = foto
        self.position = position
        self.darfEntfernen = darfEntfernen
        self.beiUebernehmen = beiUebernehmen
        self.beiTauschen = beiTauschen
        self.beiEntfernen = beiEntfernen
        _saetze = State(initialValue: position.saetze)
        let von = position.wdhVon ?? 8
        _wdhVon = State(initialValue: von)
        _wdhBis = State(initialValue: max(position.wdhBis ?? von, von))
        _pauseSek = State(initialValue: position.pauseSek)
        _dauerMin = State(initialValue: position.dauerMin ?? 20)
    }

    private var istCardio: Bool { position.art.istCardio }
    private var offen: Bool { position.werteOffen }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                kopf
                Text("IM PLAN")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                werte
                Text(offen ? "Werte setzt der Plan beim Speichern." : "Reserve und Aufwärmsatz legt der Plan fest.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                VStack(spacing: DesignSystem.Spacing.s12) {
                    Button {
                        beiTauschen()
                    } label: {
                        Label("Übung tauschen", systemImage: "arrow.left.arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .foregroundStyle(DesignSystem.Color.text)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                            .stroke(DesignSystem.Color.line, lineWidth: 1))
                    .buttonStyle(PressButtonStyle())
                    if darfEntfernen {
                        DangerOutlineButton(title: "Aus der Einheit entfernen") { beiEntfernen() }
                    }
                    PrimaryButton(title: "Übernehmen") { uebernehmen() }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.s16)
            .padding(.top, DesignSystem.Spacing.s24)
            .padding(.bottom, DesignSystem.Spacing.s16)
        }
        .background(DesignSystem.Color.surface)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func uebernehmen() {
        // Ohne bekannte Werte gibt es nichts zu uebernehmen: nur schliessen.
        if offen {
            dismiss()
            return
        }
        if istCardio {
            beiUebernehmen(position.saetze, nil, nil, position.pauseSek, dauerMin)
        } else {
            beiUebernehmen(saetze, wdhVon, wdhBis, pauseSek, nil)
        }
        dismiss()
    }

    private var kopf: some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            UebungsVideoKachel(exerciseId: modell.exerciseId) {
                PlanZeilenFoto(foto: foto)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(modell.name)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(DesignSystem.Color.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Übung anpassen")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            Spacer(minLength: 0)
        }
    }

    private var werte: some View {
        VStack(spacing: 0) {
            if istCardio {
                zeile("Dauer") {
                    menue(
                        wert: $dauerMin, optionen: PlanWerteAuswahl.dauerStufen(aktuell: dauerMin),
                        text: { "\($0) min" })
                }
            } else {
                zeile("Sätze") { stepper }
                trenner
                zeile("Wiederholungen") {
                    HStack(spacing: 8) {
                        Text("von").font(.system(size: 12)).foregroundStyle(DesignSystem.Color.textFaint)
                        menue(
                            wert: Binding(
                                get: { wdhVon },
                                set: {
                                    wdhVon = $0
                                    if wdhBis < $0 { wdhBis = $0 }
                                }),
                            optionen: Array(PlanWerteAuswahl.wdhBereich), text: { "\($0)" })
                        Text("bis").font(.system(size: 12)).foregroundStyle(DesignSystem.Color.textFaint)
                        menue(
                            wert: $wdhBis, optionen: Array(PlanWerteAuswahl.wdhBisBereich(von: wdhVon)),
                            text: { "\($0)" })
                    }
                }
                trenner
                zeile("Pause") {
                    menue(
                        wert: $pauseSek, optionen: PlanWerteAuswahl.pausenStufen(aktuell: pauseSek),
                        text: { "\($0) s" })
                }
            }
        }
        .disabled(offen)
        .opacity(offen ? 0.5 : 1)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(DesignSystem.Color.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var trenner: some View {
        Rectangle().fill(DesignSystem.Color.line).frame(height: 1)
    }

    private func zeile<Inhalt: View>(_ titel: String, @ViewBuilder inhalt: () -> Inhalt) -> some View {
        HStack {
            Text(titel)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.text)
            Spacer(minLength: 8)
            inhalt()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 60)
    }

    private var stepper: some View {
        HStack(spacing: 6) {
            taste("minus", aktiv: saetze > PlanWerteAuswahl.saetzeBereich.lowerBound, beschriftung: "Weniger Sätze") {
                saetze -= 1
            }
            Text("\(saetze)")
                .font(DesignSystem.Typography.wertSekundaer)
                .foregroundStyle(DesignSystem.Color.text)
                .frame(minWidth: 36)
            taste("plus", aktiv: saetze < PlanWerteAuswahl.saetzeBereich.upperBound, beschriftung: "Mehr Sätze") {
                saetze += 1
            }
        }
    }

    private func taste(_ symbol: String, aktiv: Bool, beschriftung: String, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .frame(width: 44, height: 44)
                .background(DesignSystem.Color.surfaceRaised)
                .foregroundStyle(aktiv ? DesignSystem.Color.text : DesignSystem.Color.textFaint)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
        }
        .buttonStyle(PressButtonStyle())
        .disabled(!aktiv)
        .accessibilityLabel(beschriftung)
    }

    private func menue(wert: Binding<Int>, optionen: [Int], text: @escaping (Int) -> String) -> some View {
        Picker("", selection: wert) {
            ForEach(optionen, id: \.self) { Text(text($0)).tag($0) }
        }
        .pickerStyle(.menu)
        .tint(DesignSystem.Color.text)
        .labelsHidden()
        .frame(minHeight: 44)
        .fixedSize()
    }
}
