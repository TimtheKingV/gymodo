import Charts
import SwiftUI

/// Home.dc.html, HomeNachholen.dc.html, HomeZielErreicht.dc.html -- der
/// Block "Deine Ziele" zwischen dem Kalender (`HomeSerieView`) und dem
/// Uebungsfortschritt. Drei Zustaende, siehe `HomeZiele.Zustand` (Spec
/// 5.3, Brief Entscheidung 1).
struct HomeZieleView: View {
    let member: BootstrapResponse.Member
    let messwerte: [Messwert]
    let erreichtesZielgewicht: VerlaufStore.ErreichtesZielgewicht?
    /// Vom Aufrufer, wie `HomeSerieView.jetzt` -- kein eigener Zeitpunkt
    /// im View, damit eine Vorschau reproduzierbar bleibt.
    let jetzt: Date
    let apiClient: APIClient
    /// Tippen auf die Karte oeffnet den Gewichtsverlauf (`GewichtsverlaufView`
    /// ueber `HomeRoute.gewichtsverlauf`, Aufgabe 9).
    let beiKarteTap: () -> Void
    /// Die Nachholkarte oeffnet den Onboarding-Flow als Sheet; danach
    /// muss Home Bootstrap (neue Ziele) und Verlauf (neuer Messwert) neu
    /// laden, weil beides ausserhalb dieses Views lebt.
    let beiOnboardingAbgeschlossen: () -> Void
    /// "Eintragen" oeffnet das Sheet, das `HomeRootView` haelt (Aufgabe 9).
    /// "Neues Ziel setzen" (Aufgabe 10) gibt es als Sheet noch nicht (R23)
    /// -- die Zeile, deren Callback hier `nil` ist, rendert nicht.
    let beiEintragen: (() -> Void)?
    let beiNeuemZiel: (() -> Void)?

    @State private var onboardingOffen = false

    private var zustand: HomeZiele.Zustand {
        HomeZiele.zustand(
            member: member, messwerte: messwerte,
            erreichtesZielgewicht: erreichtesZielgewicht, jetzt: jetzt)
    }

    var body: some View {
        // .nurEintragen ohne beiEintragen zeigt GAR NICHTS -- auch nicht
        // das Label "DEINE ZIELE" darueber (R23): eine Ueberschrift ohne
        // Inhalt waere ein Versprechen ohne Gegenwert. Aufgabe 9 macht die
        // Zeile sichtbar, indem sie den Callback setzt.
        if zeigtSichUeberhaupt {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
                Text("DEINE ZIELE")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)

                inhalt
            }
            .sheet(isPresented: $onboardingOffen) {
                OnboardingFlow(apiClient: apiClient, alsSheet: true) {
                    onboardingOffen = false
                    beiOnboardingAbgeschlossen()
                }
            }
        }
    }

    private var zeigtSichUeberhaupt: Bool {
        if case .nurEintragen = zustand, beiEintragen == nil { return false }
        return true
    }

    @ViewBuilder
    private var inhalt: some View {
        switch zustand {
        case .nachholen:
            nachholkarte
        case .nurEintragen:
            if let beiEintragen {
                eintragenZeile(titel: "Gewicht eintragen", aktion: beiEintragen)
            }
        case .karte(let karte):
            gewichtskarte(karte)
        }
    }
}

// MARK: - Nachholen

private extension HomeZieleView {
    /// HomeNachholen.dc.html -- die eine Karte, wenn beim Onboarding
    /// "Später" gewaehlt wurde (oder es noch nie lief). Derselbe Flow wie
    /// beim Gate, nur als Sheet statt als Wurzel (`alsSheet: true`).
    var nachholkarte: some View {
        Card {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    Text("Ziele festlegen")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DesignSystem.Color.text)
                    Text("Wochenziel, Gewicht, Richtung — dauert eine Minute. Nur du siehst das.")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                SecondaryButton(title: "Loslegen") { onboardingOffen = true }
            }
            .padding(DesignSystem.Spacing.s16)
        }
    }

    /// Die schmale Zeile fuer `.nurEintragen` UND fuer "Eintragen" in der
    /// Gewichtskarte -- derselbe Zeilenbau, ein anderer Titel.
    func eintragenZeile(titel: String, aktion: @escaping () -> Void) -> some View {
        Card {
            Button(action: aktion) {
                HStack(spacing: DesignSystem.Spacing.s12) {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.text)
                    Text(titel)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DesignSystem.Color.text)
                    Spacer(minLength: 0)
                }
                .padding(DesignSystem.Spacing.s16)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressButtonStyle())
        }
    }
}

// MARK: - Die Gewichtskarte

private extension HomeZieleView {
    /// "Gewicht · Abnehmen", oder nur "Gewicht" ohne gesetztes
    /// Trainingsziel -- die Richtung ist eine Absicht des Mitglieds, keine
    /// Bewertung der Plattform (Spec Abschnitt 6).
    var eyebrow: String {
        guard let ziel = member.trainingGoal, let richtung = Trainingsrichtung(rawValue: ziel) else {
            return "GEWICHT"
        }
        return "Gewicht · \(richtung.wort)".uppercased()
    }

    func gewichtskarte(_ karte: HomeZiele.Gewichtskarte) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: beiKarteTap) {
                    VStack(alignment: .leading, spacing: 0) {
                        kopfzeile(karte)
                        trennlinie
                        if let erreichtText = karte.erreichtText {
                            erreichtZeile(erreichtText)
                        } else {
                            statZellen(karte)
                        }
                    }
                }
                .buttonStyle(PressButtonStyle())

                // Beide Aktionszeilen sind Sheets, die es erst in Aufgabe
                // 9/10 gibt (R23) -- ohne Callback bleibt die Zeile weg,
                // statt auf nichts zu zeigen.
                if karte.erreichtText != nil, let beiNeuemZiel {
                    trennlinie
                    aktionsZeile(titel: "Neues Ziel setzen", symbol: "chevron.right", aktion: beiNeuemZiel)
                }
                if let beiEintragen {
                    trennlinie
                    aktionsZeile(titel: "Eintragen", symbol: "plus", aktion: beiEintragen)
                }
            }
        }
    }

    var trennlinie: some View {
        Rectangle().fill(DesignSystem.Color.line).frame(height: 1)
    }

    func kopfzeile(_ karte: HomeZiele.Gewichtskarte) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.s12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow)
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(DesignSystem.Color.textFaint)
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text(Zahlformat.gewicht(karte.wert))
                        .font(.system(size: 26, weight: .black).monospacedDigit())
                        .foregroundStyle(DesignSystem.Color.text)
                    Text("kg")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                    Text(karte.datumText)
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                        .monospacedDigit()
                        .padding(.leading, 2)
                }
            }
            Spacer(minLength: DesignSystem.Spacing.s8)
            miniKurve(karte)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.textFaint)
        }
        .padding(DesignSystem.Spacing.s16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(eyebrow), \(Zahlformat.gewichtGesprochen(karte.wert)), \(karte.datumText)")
    }

    /// Swift Charts, wie `UebungsfortschrittView` -- dieselbe eine
    /// Diagrammfarbe (`accent`, designsystem.md SS13), keine Achsen: die
    /// Karte hat den Zahlenblock schon fuer die genauen Werte, die Kurve
    /// ist hier nur die Form. Der vollstaendige Verlauf mit Rohwerten und
    /// Achsen kommt in Aufgabe 9 (Gewichtsverlauf).
    func miniKurve(_ karte: HomeZiele.Gewichtskarte) -> some View {
        Chart {
            if let zielwert = karte.zielwert {
                RuleMark(y: .value("Ziel", zielwert))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
            ForEach(Array(karte.kurve.enumerated()), id: \.offset) { index, wert in
                LineMark(x: .value("Punkt", index), y: .value("Gewicht", wert))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(DesignSystem.Color.accent)
            }
            if let letzterIndex = karte.kurve.indices.last {
                PointMark(
                    x: .value("Punkt", letzterIndex), y: .value("Gewicht", karte.kurve[letzterIndex])
                )
                .symbolSize(48)
                .foregroundStyle(DesignSystem.Color.accent)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: kurvenBereich(karte))
        .frame(width: 120, height: 44)
        // Der Zahlenblock daneben traegt die Aussage schon vollstaendig;
        // die Kurve ist eine dekorative Zusammenfassung, keine zweite
        // Informationsquelle (designsystem.md SS13: die Rohwerte stehen
        // im vollstaendigen Verlauf, Aufgabe 9).
        .accessibilityHidden(true)
    }

    /// Der Zielwert MUSS im Bereich liegen -- sonst faellt die
    /// gestrichelte Linie aus dem sichtbaren Rahmen und wirkt wie ein
    /// fehlendes Ziel statt wie ein weit entferntes.
    func kurvenBereich(_ karte: HomeZiele.Gewichtskarte) -> ClosedRange<Double> {
        var werte = karte.kurve
        if let zielwert = karte.zielwert { werte.append(zielwert) }
        guard let minimum = werte.min(), let maximum = werte.max() else { return 0...1 }
        guard minimum != maximum else { return (minimum - 1)...(maximum + 1) }
        let puffer = (maximum - minimum) * 0.15
        return (minimum - puffer)...(maximum + puffer)
    }

    /// Ohne Zielgewicht nur eine Zelle -- keine leere zweite Spalte
    /// (designsystem.md SS5: keine Statistik mit Nullen).
    func statZellen(_ karte: HomeZiele.Gewichtskarte) -> some View {
        HStack(spacing: 0) {
            zelle(wert: karte.differenzText, beschriftung: karte.seitText)
            if let abstandText = karte.abstandText, let zielText = karte.zielText {
                Rectangle().fill(DesignSystem.Color.line).frame(width: 1)
                zelle(wert: abstandText, beschriftung: zielText)
            }
        }
    }

    func zelle(wert: String, beschriftung: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(wert)
                .font(.system(size: 17, weight: .black).monospacedDigit())
                .foregroundStyle(DesignSystem.Color.text)
            Text(beschriftung)
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Color.textFaint)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.s16)
    }

    /// "Zielgewicht erreicht · 78,0 kg am 3. November" -- eine Zeile mit
    /// Haken, kein Konfetti (Reviewer-Constraint, designsystem.md SS6: nur
    /// Zustandswechsel bekommen Bewegung, keine Belohnung).
    func erreichtZeile(_ text: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DesignSystem.Color.accent)
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.text)
                .monospacedDigit()
            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Spacing.s16)
    }

    func aktionsZeile(titel: String, symbol: String, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            HStack(spacing: DesignSystem.Spacing.s12) {
                if symbol == "plus" {
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.text)
                }
                Text(titel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.text)
                Spacer(minLength: 0)
                if symbol == "chevron.right" {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                }
            }
            .padding(DesignSystem.Spacing.s16)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
    }
}

// MARK: - Vorschau

#Preview("Nachholen") {
    HomeZieleView(
        member: BootstrapResponse.Member(displayName: nil),
        messwerte: [], erreichtesZielgewicht: nil, jetzt: Date(),
        apiClient: APIClient(baseURL: URL(string: "https://preview.invalid")!, tokenProvider: { nil }),
        beiKarteTap: {}, beiOnboardingAbgeschlossen: {},
        beiEintragen: nil, beiNeuemZiel: nil)
    .padding(.horizontal, 20)
    .padding(.vertical, DesignSystem.Spacing.s24)
    .background(DesignSystem.Color.bg)
}

#Preview("Karte mit Ziel") {
    HomeZieleView(
        member: BootstrapResponse.Member(
            displayName: nil, trainingGoal: "lose_weight",
            goals: Ziele(
                weeklyDays: nil,
                targetWeight: Ziel(
                    id: "z", kind: "target_weight", targetValue: 78, createdAt: "2026-08-01T00:00:00Z"))),
        messwerte: [
            Messwert(measuredOn: "2026-08-01", weightKg: 84.5),
            Messwert(measuredOn: "2026-09-08", weightKg: 82.5),
        ],
        erreichtesZielgewicht: nil,
        jetzt: Date(timeIntervalSince1970: 1_788_955_200),
        apiClient: APIClient(baseURL: URL(string: "https://preview.invalid")!, tokenProvider: { nil }),
        beiKarteTap: {}, beiOnboardingAbgeschlossen: {},
        beiEintragen: {}, beiNeuemZiel: {})
    .padding(.horizontal, 20)
    .padding(.vertical, DesignSystem.Spacing.s24)
    .background(DesignSystem.Color.bg)
}

#Preview("Ziel erreicht") {
    HomeZieleView(
        member: BootstrapResponse.Member(displayName: nil, trainingGoal: "lose_weight"),
        messwerte: [Messwert(measuredOn: "2026-09-09", weightKg: 78)],
        erreichtesZielgewicht: VerlaufStore.ErreichtesZielgewicht(
            weightKg: 78, measuredOn: "2026-11-03"),
        jetzt: Date(timeIntervalSince1970: 1_788_955_200),
        apiClient: APIClient(baseURL: URL(string: "https://preview.invalid")!, tokenProvider: { nil }),
        beiKarteTap: {}, beiOnboardingAbgeschlossen: {},
        beiEintragen: {}, beiNeuemZiel: {})
    .padding(.horizontal, 20)
    .padding(.vertical, DesignSystem.Spacing.s24)
    .background(DesignSystem.Color.bg)
}
