import SwiftUI

/// Home.dc.html und HomeLeer.dc.html -- ein Screen, zwei Zustaende.
///
/// Der Leerzustand erklaert den naechsten Schritt, statt eine Statistik
/// mit Nullen zu zeigen (designsystem.md SS5). Die eine Null, die hier
/// trotzdem steht, ist die der Serie: sie ist bewusst gesetzt. "Wie
/// lange schon" hat auch ohne Verlauf eine Antwort, und der Streifen
/// haelt damit in jedem Zustand dieselbe Silhouette -- was der Screen
/// beim ersten Training gewinnt, ist die Farbe, nicht ein neuer Block.
/// Die frueheren Kennzahlen ("diese Woche / gesamt / Tage her") sind
/// dafuer weggefallen: der Streifen und seine Fussnote tragen sie
/// vollstaendig (siehe HomeSerieView).
struct HomeRootView: View {
    @Environment(VerlaufStore.self) private var verlauf
    @Environment(CatalogStore.self) private var katalog
    @Environment(NetzwerkMonitor.self) private var netz
    @Environment(\.scenePhase) private var scenePhase
    /// Reicht einen gescannten Geraete-Code an den Training-Tab weiter --
    /// derselbe Weg wie ein Universal Link (siehe MainTabView,
    /// TrainingRootView). Kein eigener Geraete-Oeffnen-Pfad hier: "Erstes
    /// Gerät" ist derselbe Scan wie "Gerät finden" in Training, nur von
    /// Home aus angestossen.
    @Environment(PendingTagStore.self) private var pendingTag

    @State private var pfad: [HomeRoute] = []
    @State private var scannerOffen = false

    private var studioName: String? {
        katalog.bootstrap?.studios.first { $0.id == katalog.activeStudioId }?.name
    }

    var body: some View {
        NavigationStack(path: $pfad) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                    kopf
                    if let hinweis = katalog.studiohinweis { hinweisZeile(hinweis) }
                    if let satz = verlauf.satzUeberDemInhalt { standZeile(satz) }
                    // Ueber beiden Zweigen: der Streifen zeigt auch ohne
                    // Verlauf die gedeckte Flamme mit einer Null. Er ist
                    // damit die eine Stelle, an der der Screen in jedem
                    // Zustand dieselbe Silhouette hat.
                    if let serie = verlauf.summary?.streak {
                        HomeSerieView(
                            stand: serie,
                            gesamt: verlauf.summary?.totalCount ?? 0,
                            lastSessionAt: verlauf.summary?.lastSessionAt,
                            jetzt: Date())
                    }

                    if HomeZeilen.abgeschlossene(verlauf.sessions).isEmpty {
                        leer
                    } else {
                        letzteTrainings
                        fortschritt
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s24)
            }
            .background(DesignSystem.Color.bg)
            .scrollContentBackground(.hidden)
            .refreshable { await neuLaden() }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .sessionDetail(let id):
                    SessionDetailView(sessionId: id)
                case .uebungsfortschritt(let exerciseId):
                    UebungsfortschrittView(exerciseId: exerciseId)
                }
            }
            .sheet(isPresented: $scannerOffen) {
                ScannerSheet(
                    titel: "Erstes Gerät",
                    hinweis: "Halte dein iPhone an den Aufkleber am Gerät.",
                    nebenweg: .nfc(
                        titel: "Oder NFC-Tag scannen",
                        text: "Halt die Oberkante deines iPhones an den Aufkleber."
                    ),
                    beiCode: { code in
                        scannerOffen = false
                        pendingTag.capture(TagLink.token(fromScan: code))
                    }
                )
            }
        }
        .task(id: katalog.activeStudioId) { await neuLaden() }
        // Ein Reconnect-Ausloeser. Ohne ihn blieb "Kein Empfang" (bzw. die
        // veraltete Kennzahl) stehen, bis das Mitglied den Tab verliess
        // und zurueckkam.
        .onChange(of: netz.istOnline) { _, istOnline in
            guard istOnline else { return }
            Task { await neuLaden() }
        }
        // Rueckkehr aus dem Hintergrund. .task(id:) laeuft dabei nicht
        // erneut -- TabView haelt Home am Leben, auch waehrend ein
        // Workout im Training-Tab beendet wird oder das Studio wechselt,
        // und ohne diesen Ausloeser stuenden Sessions, "diese Woche" und
        // die Fortschrittszeilen unveraendert da.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await neuLaden() }
        }
    }
}

private extension HomeRootView {
    /// Der eine Ladeweg des Screens -- alle vier Ausloeser (erster Aufbau,
    /// Ziehen, Reconnect, Rueckkehr aus dem Hintergrund) gehen hier durch,
    /// damit `studioId` nicht an vier Stellen gelesen wird.
    func neuLaden() async {
        await verlauf.laden(studioId: katalog.activeStudioId)
    }

    @ViewBuilder var kopf: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            if let vorname = HomeZeilen.vorname(katalog.bootstrap?.member.displayName) {
                Text("Hallo \(vorname)")
                    .font(DesignSystem.Typography.screentitel)
                    .foregroundStyle(DesignSystem.Color.text)
            }
            if let studioName {
                Text(studioName)
                    .font(DesignSystem.Typography.label)
                    .kerning(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
        }
    }

    func hinweisZeile(_ hinweis: CatalogStore.Studiohinweis) -> some View {
        Text(
            hinweis.beigetreten
                ? "Du gehörst jetzt zu \(hinweis.studioName)."
                : "\(hinweis.studioName) ist jetzt aktiv."
        )
        .font(DesignSystem.Typography.fliesstext)
        .foregroundStyle(DesignSystem.Color.textMuted)
    }

    func standZeile(_ satz: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.s8) {
            if let symbol = verlauf.herkunft.symbol { Image(systemName: symbol) }
            Text(satz)
        }
        .font(DesignSystem.Typography.fliesstext)
        .foregroundStyle(DesignSystem.Color.textMuted)
    }

    var letzteTrainings: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text("LETZTE TRAININGS")
                .font(DesignSystem.Typography.label)
                .kerning(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)

            ForEach(HomeZeilen.abgeschlossene(verlauf.sessions)) { einheit in
                Button {
                    pfad.append(.sessionDetail(id: einheit.id))
                } label: {
                    trainingsZeile(einheit)
                }
                .buttonStyle(PressButtonStyle())
            }
        }
    }

    func trainingsZeile(_ einheit: SessionSummary) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text(Zeitpunkt.parse(einheit.startedAt).map(Zahlformat.wochentagDatum) ?? "")
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.text)

            HStack(spacing: DesignSystem.Spacing.s8) {
                if einheit.completedReason == "auto" {
                    Text("AUTO BEENDET")
                        .font(DesignSystem.Typography.label)
                        .foregroundStyle(DesignSystem.Color.warn)
                        .padding(.horizontal, DesignSystem.Spacing.s8)
                        .padding(.vertical, DesignSystem.Spacing.s4)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.pille)
                                .stroke(DesignSystem.Color.warn, lineWidth: 1))
                }
                Text(HomeZeilen.zeilenText(einheit))
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.s16)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
    }

    var fortschritt: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text("ÜBUNGSFORTSCHRITT")
                .font(DesignSystem.Typography.label)
                .kerning(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)

            ForEach(verlauf.fortschritt) { uebung in
                Button {
                    pfad.append(.uebungsfortschritt(exerciseId: uebung.id))
                } label: {
                    fortschrittsZeile(uebung)
                }
                .buttonStyle(PressButtonStyle())
            }
        }
    }

    func fortschrittsZeile(_ uebung: ExerciseProgress) -> some View {
        HStack {
            Text("\(uebung.machineLabel) · \(uebung.exerciseName)")
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.text)
            Spacer()
            Text(Zahlformat.gewichtMitEinheit(uebung.currentWeightKg))
                .font(DesignSystem.Typography.wertSekundaer)
                .foregroundStyle(DesignSystem.Color.text)
            Text(HomeZeilen.veraenderung(uebung.changeKg))
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .monospacedDigit()
        }
        .padding(DesignSystem.Spacing.s16)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(uebung.machineLabel), \(uebung.exerciseName), \(Zahlformat.gewichtGesprochen(uebung.currentWeightKg))")
    }

    var leer: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
            Text("Hier wird dein Verlauf stehen.")
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.text)
            Text("Noch ist nichts da — das ändert sich mit deinem ersten Satz.")
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.textMuted)

            schritt(1, "iPhone an den Aufkleber halten", "Auf jedem Gerät klebt einer. QR-Code geht genauso.")
            schritt(2, "Einweisung ansehen, Gerät einstellen", "Einmal. Danach stehen deine Werte jedes Mal da.")
            schritt(3, "Sätze sichern", "Meistens reicht ein Antippen. Das Training startet dabei von selbst.")

            PrimaryButton(title: "Erstes Gerät") { scannerOffen = true }

            Text("gymodo misst nichts. Es zeigt, was du bestätigst.")
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.textFaint)
        }
    }

    func schritt(_ nummer: Int, _ titel: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.s12) {
            Text("\(nummer)")
                .font(DesignSystem.Typography.label)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .monospacedDigit()
                .frame(width: 20)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(titel)
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                Text(text)
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
        }
    }
}
