import SwiftUI

/// Der wischbare Wochenstreifen -- herausgeloest aus `KurseWochenView`, damit
/// der Plan-Tab denselben Streifen mit eigener Markierung unter den Tagen zeigt.
///
/// Ein ECHTER Paging-Container, keine selbstgebaute DragGesture: mit der
/// Wochenleiste sind die Pfeile weggefallen, und damit der antippbare Zwilling
/// der Wischgeste. `TabView(.page)` bringt den Dreifinger-Wisch mit; die beiden
/// benannten Aktionen machen den Wochenwechsel zusaetzlich ueber den Rotor
/// erreichbar -- und ueber Schaltersteuerung.
struct KurseWochenstreifen<Marke: View>: View {
    /// Die Montage der wischbaren Wochen (`KurseWochenBerechnung.wochenMontage`).
    let montage: [Date]
    let index: Int
    let jetzt: Date
    let zeitzone: String
    let gewaehlterTagId: String
    /// Feste Hoehe: 12pt Buchstabe, 6pt Abstand, 40pt Kreis, 6pt Abstand,
    /// dann die Marke. Eine TabView hat keine Eigenhoehe, ohne diese Angabe
    /// fuellte sie den ganzen ScrollView.
    var hoehe: CGFloat = 69
    let beiWochenwahl: (Int) -> Void
    let beiTagwahl: (KurseWochentag) -> Void
    /// Das VoiceOver-Label des Tages -- die Marke selbst ist Verzierung.
    let label: (KurseWochentag) -> String
    @ViewBuilder let marke: (KurseWochentag) -> Marke

    var body: some View {
        TabView(selection: Binding(get: { index }, set: { beiWochenwahl($0) })) {
            ForEach(Array(montage.enumerated()), id: \.offset) { seite, montag in
                tagesboxen(KurseWochenBerechnung.wochentage(abMontag: montag, jetzt: jetzt, zeitzone: zeitzone))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .tag(seite)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: hoehe)
        .accessibilityAction(named: "Nächste Woche") {
            beiWochenwahl(min(index + 1, montage.count - 1))
        }
        .accessibilityAction(named: "Vorherige Woche") {
            beiWochenwahl(max(index - 1, 0))
        }
    }

    private func tagesboxen(_ tage: [KurseWochentag]) -> some View {
        HStack(spacing: DesignSystem.Spacing.s4) {
            ForEach(tage) { tag in
                let ausgewaehlt = tag.id == gewaehlterTagId
                Button {
                    beiTagwahl(tag)
                } label: {
                    VStack(spacing: 6) {
                        // Der Buchstabe steht UEBER der Zelle, nicht darin:
                        // dieselbe Anordnung wie im Home-Kalender, und die
                        // Zelle bleibt dadurch ein Kreis statt eines Kastens
                        // mit zwei Zeilen.
                        Text(tag.buchstabe)
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.2)
                            .foregroundStyle(
                                ausgewaehlt
                                    ? DesignSystem.Color.text : DesignSystem.Color.textFaint)

                        // Dieselbe Zelle wie im Home-Kalender -- der
                        // Kursplan kennt keine trainierten Tage und keine
                        // Nachbarmonate, beides bleibt deshalb aus.
                        Kalenderzelle(
                            inhalt: .zahl(tag.tagesnummer),
                            istGewaehlt: ausgewaehlt,
                            istHeute: tag.istHeute,
                            trainiert: false,
                            gedeckt: false)

                        marke(tag)
                            .accessibilityHidden(true)
                    }
                    // Die Trefferflaeche ist die ganze Spalte, nicht der
                    // Kreis: 40 pt allein blieben unter den 44 aus
                    // designsystem.md SS4.
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressButtonStyle())
                .accessibilityLabel(label(tag))
                .accessibilityAddTraits(ausgewaehlt ? .isSelected : [])
            }
        }
    }
}

extension KurseWochenBerechnung {
    /// Das eine Anfragefenster des Wochenplans: Montag dieser Woche bis
    /// "jetzt plus 14 Tage" (Spec 5.1, siehe `fensterEnde`). Kurse-Screen
    /// und Plan-Tab laden dasselbe, sonst beschnitten sie sich den Cache.
    static func ladefenster(jetzt: Date, zeitzone: String) -> (von: Date, bis: Date) {
        (montag(enthaelt: jetzt, zeitzone: zeitzone), fensterEnde(ab: jetzt, zeitzone: zeitzone))
    }
}

extension KurseStore {
    /// Der eine Ladeweg des Wochenplans fuer alle Ausloeser (erster Aufbau,
    /// Ziehen, Reconnect, Rueckkehr aus dem Hintergrund) -- in Kurse-Screen
    /// und Plan-Tab gleich.
    func ladenAbDieserWoche(studioIds: [String], zeitzone: String, jetzt: Date = Date()) async {
        guard !studioIds.isEmpty else { return }
        let fenster = KurseWochenBerechnung.ladefenster(jetzt: jetzt, zeitzone: zeitzone)
        await laden(studioIds: studioIds, von: fenster.von, bis: fenster.bis)
    }
}
