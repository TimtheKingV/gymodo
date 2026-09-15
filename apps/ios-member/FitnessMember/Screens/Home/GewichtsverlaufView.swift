import Charts
import SwiftUI

/// Die reinen Ableitungen des Gewichtsverlaufs -- getrennt vom View, damit
/// sie ohne SwiftUI pruefbar bleiben (wie `HomeZiele`/`HomeZeilen`).
enum GewichtsverlaufHilfen {
    /// "Ziel 78,0 kg · noch 4,5" -- wortwoertlich aus Gewichtsverlauf.dc.html:
    /// die zweite Zahl traegt bewusst KEIN "kg" mehr, die Einheit steht
    /// schon bei der ersten. `nil` ohne aktives Zielgewicht (SS5: keine
    /// Statistik mit erfundenen Nullen).
    static func kopfZielText(zielwert: Double?, aktuell: Double) -> String? {
        guard let zielwert else { return nil }
        return "Ziel \(Zahlformat.gewicht(zielwert)) kg · noch \(Zahlformat.gewicht(abs(aktuell - zielwert)))"
    }

    /// "SEIT 1. AUGUST" -- immer der ERSTE je eingetragene Messwert,
    /// unabhaengig vom `Fortschrittsfenster`-Umschalter: dieselbe
    /// Festlegung wie `HomeZiele.Gewichtskarte.differenzText`.
    static func seitText(_ erstesDatum: String) -> String? {
        guard let tag = Zeitpunkt.parse("\(erstesDatum)T12:00:00Z") else { return nil }
        return "seit \(Zahlformat.tagMonat(tag))"
    }

    /// Der Vorgaenger eines Messwerts in der VOLLSTAENDIGEN, aufsteigend
    /// sortierten Liste -- nicht im gerade sichtbaren Fenster: sonst
    /// spraenge die Differenz an der Fenstergrenze auf den falschen
    /// Vergleichstag um, obwohl derselbe Eintrag gemeint ist.
    static func vorheriger(_ alle: [Messwert], vor messwert: Messwert) -> Messwert? {
        guard let index = alle.firstIndex(of: messwert), index > 0 else { return nil }
        return alle[index - 1]
    }

    /// "\(Tag)T12:00:00Z" -- Mittag UTC statt Mitternacht, wie
    /// `UebungsfortschrittView.diagramm`: derselbe Trick vermeidet, dass
    /// das Parsen an einer Tagesgrenze in eine falsche Zeitzone faellt.
    static func datum(_ measuredOn: String) -> Date {
        Zeitpunkt.parse("\(measuredOn)T12:00:00Z") ?? Date()
    }

    static func datumKurz(_ measuredOn: String) -> String {
        Zahlformat.tagMonatKurz(datum(measuredOn))
    }
}

/// Gewichtsverlauf.dc.html -- nach dem Vorbild von `UebungsfortschrittView`
/// (Brief Step 3): eine Kurve, Achse nicht bei null, Zeitraum-Umschalter,
/// Rohwerte darunter. Anders als dort zusaetzlich eine gestrichelte
/// Ziellinie (`RuleMark`) und Zeilen, die man antippen (bearbeiten) und
/// wegwischen (loeschen) kann.
struct GewichtsverlaufView: View {
    let apiClient: APIClient

    @Environment(VerlaufStore.self) private var verlauf
    @Environment(CatalogStore.self) private var katalog
    @State private var fenster: Fortschrittsfenster = .dreiMonate
    @State private var bearbeitenMesswert: Messwert?
    @State private var bearbeitenOffen = false
    /// Loeschen ist NICHT optimistisch (Ruling): misslingt der
    /// Server-Aufruf, bleibt die Zeile stehen und dieser Satz erscheint
    /// UEBER der Liste (designsystem.md SS5: was falsch ist und was gilt).
    @State private var loeschFehler: String?

    private var zielwert: Double? { katalog.bootstrap?.member.goals.targetWeight?.targetValue }

    var body: some View {
        Group {
            if let erster = verlauf.messwerte.first, let letzter = verlauf.messwerte.last {
                inhalt(erster: erster, letzter: letzter)
            } else {
                leer
            }
        }
        .background(DesignSystem.Color.bg)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $bearbeitenOffen) {
            GewichtEintragenSheet(
                vorgabe: bearbeitenMesswert?.weightKg,
                tag: bearbeitenMesswert?.measuredOn ?? GewichtEintragenHilfen.heute(),
                letzterMesswert: verlauf.messwerte.last,
                speichern: { body in await verlauf.gewichtSpeichern(body, katalogNeuLaden: { await katalog.load() }) })
        }
    }

    private var leer: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text("Noch kein Gewicht eingetragen.")
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.text)
            Text("Der Verlauf beginnt mit deinem ersten Eintrag auf Home.")
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
        .padding(.horizontal, 20)
        .padding(.top, DesignSystem.Spacing.s48)
    }

    private func inhalt(erster: Messwert, letzter: Messwert) -> some View {
        let sichtbar = fenster.punkte(verlauf.messwerte, jetzt: Date())

        return List {
            Group {
                GewichtsverlaufKopf(erster: erster, letzter: letzter, zielwert: zielwert)
                umschalter
                GewichtsverlaufDiagrammKarte(punkte: sichtbar, zielwert: zielwert)
                    .padding(.horizontal, 20)
                    .padding(.top, DesignSystem.Spacing.s24)
                GewichtsverlaufRohwerteKopf()
                if let loeschFehler {
                    InlineBanner(tone: .danger, message: loeschFehler)
                        .padding(.horizontal, 20)
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(DesignSystem.Color.bg)

            ForEach(sichtbar.reversed(), id: \.measuredOn) { messwert in
                let vorheriger = GewichtsverlaufHilfen.vorheriger(verlauf.messwerte, vor: messwert)
                let diffKg = vorheriger.map { messwert.weightKg - $0.weightKg }

                Button {
                    bearbeitenMesswert = messwert
                    bearbeitenOffen = true
                } label: {
                    GewichtsverlaufZeile(
                        messwert: messwert,
                        diffText: diffKg.map(HomeZiele.differenzText),
                        unveraendert: diffKg.map { (($0 * 10).rounded() / 10) == 0 } ?? true)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowBackground(DesignSystem.Color.surface)
                // Der native Trennstrich traegt sonst Systemgrau statt des
                // Design-Tokens -- dieselbe Linie wie die Karten im Rest
                // der App (designsystem.md SS2).
                .listRowSeparatorTint(DesignSystem.Color.line)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await loeschen(messwert) }
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 44)
    }

    /// Der Akzent markiert den aktiven Wert -- die eine Akzentflaeche
    /// dieses Screens (SS2), wie in `UebungsfortschrittView`.
    private var umschalter: some View {
        HStack(spacing: DesignSystem.Spacing.s8) {
            ForEach(Fortschrittsfenster.allCases) { wahl in
                Button(wahl.titel) { fenster = wahl }
                    .font(DesignSystem.Typography.label)
                    .padding(.horizontal, DesignSystem.Spacing.s16)
                    .frame(height: 44)
                    .background(wahl == fenster ? DesignSystem.Color.accent : DesignSystem.Color.surface)
                    .foregroundStyle(wahl == fenster ? DesignSystem.Color.onAccent : DesignSystem.Color.textMuted)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.pille))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, DesignSystem.Spacing.s16)
    }
}

// MARK: - Kopf (eigener Typ: steht ausserhalb jeder List/ScrollView und
// laesst sich deshalb einzeln rendern -- Sichtpruefung Task 9)

struct GewichtsverlaufKopf: View {
    let erster: Messwert
    let letzter: Messwert
    let zielwert: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text("GEWICHT")
                .font(DesignSystem.Typography.detailScreentitel)
                .foregroundStyle(DesignSystem.Color.text)
            if let zielText = GewichtsverlaufHilfen.kopfZielText(zielwert: zielwert, aktuell: letzter.weightKg) {
                Text(zielText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .monospacedDigit()
            }

            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.s16) {
                Text(Zahlformat.gewichtMitEinheit(letzter.weightKg))
                    .font(DesignSystem.Typography.wertHeld)
                    .foregroundStyle(DesignSystem.Color.text)

                VStack(alignment: .leading, spacing: 2) {
                    Text(HomeZiele.differenzText(letzter.weightKg - erster.weightKg))
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(DesignSystem.Color.accent)
                        .monospacedDigit()
                    if let seitText = GewichtsverlaufHilfen.seitText(erster.measuredOn) {
                        // Die Zeile traegt in Gewichtsverlauf.dc.html die
                        // ".eyebrow"-Klasse (color: #9BA3AF) mit nur der
                        // Schriftgroesse ueberschrieben -- textMuted, nicht
                        // textFaint (Sichtpruefung, zweite Runde).
                        Text(seitText.uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.2)
                            .foregroundStyle(DesignSystem.Color.textMuted)
                    }
                }
            }
            .padding(.top, DesignSystem.Spacing.s4)
        }
        .padding(.horizontal, 20)
        .padding(.top, DesignSystem.Spacing.s16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Gewicht, \(Zahlformat.gewichtGesprochen(letzter.weightKg)), Veränderung \(HomeZiele.differenzText(letzter.weightKg - erster.weightKg))")
    }
}

// MARK: - Diagramm (eigener Typ, siehe Kopf oben)

struct GewichtsverlaufDiagrammKarte: View {
    let punkte: [Messwert]
    let zielwert: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            diagramm
            Text("Dein Eintrag je Tag · kg · keine Glättung")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.textFaint)
        }
        .padding(DesignSystem.Spacing.s16)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
    }

    private var diagramm: some View {
        Chart {
            // Gestrichelte Ziellinie in text-faint -- Text traegt
            // Textfarben, nie die Serienfarbe (designsystem.md SS13).
            if let zielwert {
                RuleMark(y: .value("Ziel", zielwert))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("ZIEL \(Zahlformat.gewicht(zielwert))")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(DesignSystem.Color.textFaint)
                    }
            }

            ForEach(punkte, id: \.measuredOn) { punkt in
                LineMark(
                    x: .value("Datum", GewichtsverlaufHilfen.datum(punkt.measuredOn)),
                    y: .value("Gewicht", punkt.weightKg)
                )
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(DesignSystem.Color.accent)

                // Messpunkte >= 8pt (SS13) -- 64 entspricht derselben
                // Punktgroesse wie in UebungsfortschrittView.
                PointMark(
                    x: .value("Datum", GewichtsverlaufHilfen.datum(punkt.measuredOn)),
                    y: .value("Gewicht", punkt.weightKg)
                )
                .symbolSize(64)
                .foregroundStyle(DesignSystem.Color.accent)
                // Direkte Beschriftung nur an Anfang und Ende (SS13).
                .annotation(position: .top) {
                    if punkt.measuredOn == punkte.first?.measuredOn
                        || punkt.measuredOn == punkte.last?.measuredOn {
                        Text(Zahlformat.gewicht(punkt.weightKg))
                            .font(DesignSystem.Typography.fliesstext)
                            .foregroundStyle(DesignSystem.Color.textMuted)
                            .monospacedDigit()
                    }
                }
            }
        }
        // Das Ziel MUSS im Bereich stecken (Brief Step 3) -- sonst faellt
        // die gestrichelte Linie aus der sichtbaren Achse.
        .chartYScale(
            domain: Fortschrittsfenster.achsenbereich(punkte.map(\.weightKg) + (zielwert.map { [$0] } ?? []))
        )
        .chartXAxis {
            AxisMarks {
                AxisGridLine().foregroundStyle(DesignSystem.Color.line)
                AxisValueLabel(
                    format: .dateTime.day().month(.abbreviated).locale(Locale(identifier: "de_DE"))
                )
                .foregroundStyle(DesignSystem.Color.textFaint)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(DesignSystem.Color.line)
                AxisValueLabel()
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
        }
        .frame(height: 200)
        .accessibilityLabel("Gewichtsverlauf")
        .accessibilityChartDescriptor(GewichtsverlaufChartDescriptor(punkte: punkte, zielwert: zielwert))
    }
}

// MARK: - Rohwerte (eigene Typen, siehe Kopf oben)

/// "ZULETZT" links, "Antippen ändert, Wischen löscht" rechts, beides in
/// text-faint -- die Geste steht sichtbar da, statt stumm zu bleiben
/// (designsystem.md SS5, Brief Step 3).
struct GewichtsverlaufRohwerteKopf: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("ZULETZT")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
            Spacer(minLength: DesignSystem.Spacing.s16)
            Text("Antippen ändert, Wischen löscht")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Color.textFaint)
        }
        .padding(.horizontal, 20)
        .padding(.top, DesignSystem.Spacing.s24)
        .padding(.bottom, DesignSystem.Spacing.s8)
    }
}

/// Eine Rohwertzeile -- Datum, Gewicht, Differenz zum Vortag. Nimmt die
/// Differenz FERTIG BERECHNET entgegen (statt selbst in der vollstaendigen
/// Messwertliste nachzuschlagen): so bleibt der Typ ohne `VerlaufStore`
/// instanziierbar, sowohl in der echten Liste als auch in einer
/// Sichtpruefung als schlichter `VStack` (Task 9, Sichtpruefung).
struct GewichtsverlaufZeile: View {
    let messwert: Messwert
    let diffText: String?
    let unveraendert: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            // color: #5C636E in Gewichtsverlauf.dc.html -- textFaint, nicht
            // textMuted (Sichtpruefung, zweite Runde).
            Text(GewichtsverlaufHilfen.datumKurz(messwert.measuredOn))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DesignSystem.Color.textFaint)
                .monospacedDigit()
                .frame(width: 62, alignment: .leading)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(Zahlformat.gewicht(messwert.weightKg))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.text)
                    .monospacedDigit()
                Text("kg")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let diffText {
                Text(diffText)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(unveraendert ? DesignSystem.Color.textFaint : DesignSystem.Color.accent)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, DesignSystem.Spacing.s12)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        // Die Zeile ist zugleich die Wertetabelle, die VoiceOver als
        // Alternative zum Diagramm braucht (designsystem.md SS12) -- ein
        // Element statt dreier unzusammenhaengender Fetzen.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            diffText.map {
                "\(Zahlformat.wochentagDatum(GewichtsverlaufHilfen.datum(messwert.measuredOn))), \(Zahlformat.gewichtGesprochen(messwert.weightKg)), Veränderung \($0)"
            }
                ?? "\(Zahlformat.wochentagDatum(GewichtsverlaufHilfen.datum(messwert.measuredOn))), \(Zahlformat.gewichtGesprochen(messwert.weightKg))")
        .accessibilityHint("Antippen ändert, Wischen löscht")
    }
}

// MARK: - Schreiben

private extension GewichtsverlaufView {
    /// Ruling: Loeschen ist NICHT optimistisch -- erst der Server, dann
    /// erst `messwertEntfernen`. Misslingt der Aufruf, bleibt die Zeile
    /// stehen und der Fehler steht ueber der Liste, statt eine Zeile
    /// verschwinden zu lassen, die serverseitig noch existiert.
    func loeschen(_ messwert: Messwert) async {
        do throws(APIError) {
            try await apiClient.deleteMeasurement(measuredOn: messwert.measuredOn)
            verlauf.messwertEntfernen(measuredOn: messwert.measuredOn)
            loeschFehler = nil
        } catch {
            guard error != .offline else {
                loeschFehler = "Keine Verbindung. Der Eintrag wurde nicht gelöscht."
                return
            }
            loeschFehler = error.servertext
        }
    }
}

// MARK: - VoiceOver: Audio Graph / Wertetabelle (designsystem.md SS12)

/// Die Rohwerteliste unter dem Diagramm ist bereits die Wertetabelle
/// (SS12) -- dieser Descriptor traegt zusaetzlich das Diagramm selbst in
/// VoiceOvers Audio-Graph-Funktion, mit denselben Werten.
private struct GewichtsverlaufChartDescriptor: AXChartDescriptorRepresentable {
    let punkte: [Messwert]
    let zielwert: Double?

    func makeChartDescriptor() -> AXChartDescriptor {
        let werte = punkte.map(\.weightKg) + (zielwert.map { [$0] } ?? [])
        let bereich = Fortschrittsfenster.achsenbereich(werte)

        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Datum",
            categoryOrder: punkte.map(\.measuredOn)
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Gewicht in Kilogramm",
            range: bereich,
            gridlinePositions: []
        ) { Zahlformat.gewichtMitEinheit($0) }

        let serie = AXDataSeriesDescriptor(
            name: "Gewicht",
            isContinuous: false,
            dataPoints: punkte.map { AXDataPoint(x: $0.measuredOn, y: $0.weightKg) }
        )

        return AXChartDescriptor(
            title: "Gewichtsverlauf",
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [serie]
        )
    }

    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {
        descriptor.series = makeChartDescriptor().series
    }
}
