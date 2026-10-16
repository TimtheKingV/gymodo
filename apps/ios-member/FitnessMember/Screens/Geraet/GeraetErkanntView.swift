import SwiftUI

/// "Was machst du heute?" -- die Uebungsliste eines erkannten Geraets.
///
/// Ein Tap auf eine Uebung waehlt sie; es gibt keinen Bestaetigungsknopf
/// (designsystem.md SS8). Darauf folgt der Drawer mit Einweisung und
/// Startwerten ueber dieser Seite (Testnotiz 11.10., #6, #10).
struct GeraetErkanntView: View {
    let modell: GeraetModel
    let beiAuswahl: (String) -> Void

    @AppStorage(Einstellungen.uebungsansichtKey) private var ansichtRoh = Uebungsansicht.muskel.rawValue

    private var ansicht: Binding<Uebungsansicht> {
        Binding(get: { Uebungsansicht(rawValue: ansichtRoh) ?? .muskel },
                set: { ansichtRoh = $0.rawValue })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                kopfzeile
                geraetefoto
                geraetename
                if UebungsGruppierung.bietetSchalterAn(uebungsanzahl: sortierteUebungen.count) {
                    PillenLeiste(werte: Uebungsansicht.allCases, auswahl: ansicht, titel: \.titel)
                }
                uebungsliste
                hinweis
            }
            .padding(.horizontal, 20)
            .padding(.bottom, DesignSystem.Spacing.s32)
        }
        .background(DesignSystem.Color.bg)
        .navigationBarTitleDisplayMode(.inline)
        .testnotizScreen(kontext: ["station": modell.station.schluessel])
    }

    private var kopfzeile: some View {
        HStack {
            Text(ortsangabe)
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textFaint)
            Spacer()
            // Abweichung vom Artboard: dort accent. Die eine Akzentflaeche
            // des Screens ist die aktive Uebungszeile (designsystem.md SS2).
            Label(modell.einstiegsart.beschriftung, systemImage: modell.einstiegsart.symbol)
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    private var ortsangabe: String {
        modell.ortsangabe.uppercased()
    }

    /// Bestaetigt in einer Sekunde, dass man am richtigen Geraet steht --
    /// bei zwei baugleichen Stationen der eigentliche Nutzen. Offline gibt
    /// es keine signierte URL, dann steht hier der Platzhalter.
    private var geraetefoto: some View {
        Geraetefoto(modellId: modell.station.equipmentModelId, url: modell.kontext?.equipmentModel.photoUrl.flatMap(URL.init(string:)), hoehe: 180)
    }

    private var geraetename: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text(modell.station.equipmentModel.name.uppercased())
                .font(DesignSystem.Typography.geraetename)
                .tracking(-0.8)
                .foregroundStyle(DesignSystem.Color.text)
            Text(hersteller)
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    private var hersteller: String {
        [modell.station.equipmentModel.manufacturer, modell.station.locationNote]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var gruppiert: Bool {
        ansicht.wrappedValue == .muskel && UebungsGruppierung.bietetSchalterAn(uebungsanzahl: sortierteUebungen.count)
    }

    private var uebungsliste: some View {
        UebungsAbschnitte(uebungen: sortierteUebungen, gruppiert: gruppiert) { uebung in
            Button { beiAuswahl(uebung.id) } label: {
                zeile(uebung)
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityLabel("\(uebung.name), \(untertitel(uebung))")
            .accessibilityHint("Öffnet das Gerät")
        }
    }

    /// Dieselbe Reihenfolge wie "Weitere Übung" (Testnotiz 14.10., 18:25):
    /// dieses Training, dann Haeufigkeit, dann der Rest. Loest "die zuletzt
    /// genutzte oben" (designsystem.md SS8) ab.
    private var sortierteUebungen: [GeraetUebung] { modell.sortierteUebungen }

    /// Alle Zeilen gleich (Testnotiz 06.10., #3): bis dahin trug die erste
    /// einen Akzentbalken und eine hellere Flaeche. Die erste ist aber nur
    /// eine Vorauswahl -- ohne Historie schlicht die erste Uebung des
    /// Studios --, und ein Balken dort las sich wie "die ist schon dran".
    /// Was die zuletzt genutzte Uebung ausmacht, sagt das Wort "zuletzt" im
    /// Untertitel. Links der Platz fuer das Sinnbild der Uebung.
    private func zeile(_ uebung: GeraetUebung) -> some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            // Das Video der Uebung in Schleife (Testnotiz 11.10., #5); bis
            // es da ist, und ohne Video, das Sinnbild.
            UebungsVideoKachel(exerciseId: uebung.id) {
                Uebungsbild()
            }
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(uebung.name)
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                Text(untertitel(uebung))
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.textFaint)
        }
        .padding(DesignSystem.Spacing.s12)
        .frame(minHeight: 44)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
    }

    /// Drei Zustaende, nicht zwei: die aktive Zeile mit Historie traegt das
    /// Wort "zuletzt", jede andere Zeile mit Historie nicht -- sonst stuende
    /// "zuletzt" auf zwei Zeilen gleichzeitig und waere bedeutungslos. Das
    /// Alter ("vor 8 Tagen") sagt, wie verlaesslich die Zahl noch ist,
    /// bevor man das Geraet danach einstellt.
    private func untertitel(_ uebung: GeraetUebung) -> String {
        guard let belastungText = modell.letzterSatzText(fuer: uebung.id) else {
            return "Noch nie · Ziel \(Zahlformat.korridorMitEinheit(uebung.targetMin, uebung.targetMax, uebung.volumeKind))"
        }
        let alter = altersangabe(fuer: uebung.id)
        if uebung.id == modell.uebungId {
            return ["zuletzt · \(belastungText)", alter].compactMap { $0 }.joined(separator: " ")
        }
        return [belastungText, alter].compactMap { $0 }.joined(separator: " · ")
    }

    /// "heute" statt "vor 0 Tagen" -- Letzteres liest sich wie ein
    /// Rechenfehler. Ohne Historie oder mit einem Datum, das sich nicht
    /// parsen laesst, faellt die Alterangabe ganz weg statt eine falsche
    /// Zahl zu zeigen.
    private func altersangabe(fuer uebungId: String) -> String? {
        guard let tage = modell.letzteNutzungInTagen(fuer: uebungId) else { return nil }
        if tage <= 0 { return "heute" }
        return tage == 1 ? "vor 1 Tag" : "vor \(tage) Tagen"
    }

    private var hinweis: some View {
        Text("Ein Tap wählt die Übung, danach stellst du deine Startwerte ein. Trainierst du hier immer dasselbe, überspringt Gymtavo diese Liste künftig.")
            .font(.system(size: 12))
            .foregroundStyle(DesignSystem.Color.textFaint)
            .lineSpacing(3)
    }
}

/// Bindet das Laden von tagContext an GeraetErkanntView -- getrennt, damit
/// die View selbst nur den Screen beschreibt (wie GeraetScreen/GeraetView
/// es fuer den Geraete-Screen schon vormachen).
///
/// `@State var modell` ist der eigentliche Punkt: TrainingRootView.ziel(_:)
/// ruft `modell(station:exerciseId:token:)` bei JEDER Body-Auswertung neu
/// auf und erzeugt dabei ein frisches GeraetModel. Ohne dieses @State wuerde
/// jede Neuzeichnung ein Modell verwerfen, dessen kontextLaden() gerade erst
/// geladen hat -- SwiftUI uebernimmt den init-Parameter fuer @State nur beim
/// allerersten Aufbau derselben View-Identitaet, jede weitere ignoriert ihn.
struct GeraetErkanntScreen: View {
    @State var modell: GeraetModel
    let beiAuswahl: (String) -> Void

    var body: some View {
        GeraetErkanntView(modell: modell, beiAuswahl: beiAuswahl)
            // Online zeigt das Geraetefoto den eigentlichen Nutzen bei zwei
            // baugleichen Stationen (designsystem.md SS8) -- der Offline-
            // Platzhalter in GeraetErkanntView bleibt unveraendert. Die
            // Trainingsuhr laeuft hier NICHT los: die Einheit beginnt erst
            // mit "Übung starten" im Drawer (Testnotiz 11.10., #11).
            .task { await modell.kontextLaden() }
    }
}
