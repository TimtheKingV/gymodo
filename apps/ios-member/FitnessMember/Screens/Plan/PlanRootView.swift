import SwiftUI

/// Der Tab "Plan" (Leinwand 2a, 2f, 2g, 2i): die Woche mit Einheiten, festen
/// Kursen und Cardio-Tagen. Ohne aktiven Plan zeigt er die Kurse wie bisher
/// und darueber die Karte "Plan einrichten" (Ruling).
///
/// Die App rechnet am Plan nichts (F15): Raster, Folge und Kraft-Tage kommen
/// vom Server; hier wird nur zugeordnet (`PlanWoche`, `PlanTabZustand`).
struct PlanRootView: View {
    let apiClient: APIClient
    let beiKurs: (String) -> Void
    let beiEinheit: (String) -> Void
    let beiTrainingStarten: () -> Void
    /// Ein Tag, den Home zeigen will ("Als nächstes" auf einen Cardio- oder
    /// Kurstag, Leinwand 2d). Wird beim Uebernehmen geleert, damit derselbe
    /// Tag ein zweites Mal ankommt.
    @Binding var tagWunsch: Date?

    @Environment(CatalogStore.self) private var katalog
    @Environment(KurseStore.self) private var kurse
    @Environment(TrainingsplanAblaufStore.self) private var planAblauf
    @Environment(NetzwerkMonitor.self) private var netz
    @Environment(CardioChecksStore.self) private var cardio
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var zustand = PlanTabZustand()
    /// Gespeichert, aber der Bootstrap kam nicht nach.
    @State private var speicherHinweis: String?
    @State private var einplanenOffen = false
    @State private var planFlowUmfang: OnboardingUmfang?
    @State private var beitretenOffen = false

    var body: some View {
        Group {
            if let plan = PlanAnzeige.plan(bootstrap: katalog.bootstrap) {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    planInhalt(plan: plan, jetzt: context.date)
                }
            } else {
                ohnePlan
            }
        }
        .sheet(isPresented: Binding(get: { planFlowUmfang != nil }, set: { if !$0 { planFlowUmfang = nil } })) {
            OnboardingFlow(apiClient: apiClient, alsSheet: true, umfang: planFlowUmfang ?? .nurPlan) {
                planFlowUmfang = nil
            }
        }
        .task(id: tagWunsch) {
            guard let tagWunsch else { return }
            zustand.gewaehlterTag = tagWunsch
            self.tagWunsch = nil
        }
        .sheet(isPresented: $beitretenOffen) {
            NavigationStack {
                StudioBeitretenView(loader: apiClient) { beitretenOffen = false }
            }
        }
    }

    // MARK: - Ohne Plan

    /// Kurse wie bisher, die Karte darueber nur, solange sie gilt
    /// (`PlanEinrichten.zeigtKarte`, dieselbe Regel wie auf Home).
    private var ohnePlan: some View {
        let karte: AnyView? = katalog.bootstrap.flatMap { b in
            PlanEinrichten.zeigtKarte(member: b.member)
                ? AnyView(PlanEinrichtenKarte { planFlowUmfang = PlanEinrichten.umfang(member: b.member) })
                : nil
        }
        return KurseWochenView(beiAuswahl: beiKurs, loader: apiClient, titel: "PLAN", zusatz: karte)
    }

    // MARK: - Abgeleitetes

    private var studios: [String] {
        KurseStudios.reihenfolge(
            alle: katalog.bootstrap?.studios.map(\.id) ?? [], aktiv: katalog.activeStudioId)
    }

    private var hatStudio: Bool { !studios.isEmpty }

    /// Wie `KurseWochenView.zeitzoneFuerAnfrage`; ohne Studio die des Geraets.
    private var zeitzone: String {
        kurse.woche?.timezone
            ?? studios.first.flatMap { erstes in katalog.bootstrap?.studios.first { $0.id == erstes }?.timezone }
            ?? TimeZone.current.identifier
    }

    private var kalender: Calendar {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: zeitzone) ?? .current
        k.locale = Locale(identifier: "de_DE")
        return k
    }

    private var profil: TrainingsplanProfil? { katalog.bootstrap?.member.trainingProfile }

    private func raster(_ plan: Trainingsplan) -> [Rasterplatz] {
        PlanTabZustand.anzeigeRaster(
            planRaster: plan.wochenraster, einheiten: plan.einheiten.map(\.key), profil: profil)
    }

    private var sitzungen: [CourseWeekSession] { hatStudio ? (kurse.woche?.sessions ?? []) : [] }

    // MARK: - Mit Plan

    private func planInhalt(plan: Trainingsplan, jetzt: Date) -> some View {
        let kalender = kalender
        let raster = raster(plan)
        let montage = KurseWochenBerechnung.wochenMontage(ab: jetzt, zeitzone: zeitzone)
        let wochenIndex = montage.lastIndex { m in zustand.gewaehlterTag.map { $0 >= m } ?? false } ?? 0
        let wochentage = KurseWochenBerechnung.wochentage(
            abMontag: montage.indices.contains(wochenIndex) ? montage[wochenIndex]
                : KurseWochenBerechnung.montag(enthaelt: jetzt, zeitzone: zeitzone),
            jetzt: jetzt, zeitzone: zeitzone)
        let tage = wochentage.map(\.datum)
        let tag = zustand.geltenderTag(tage: tage, heute: jetzt, kalender: kalender)
        let tagId = wochentage.first { kalender.isDate($0.datum, inSameDayAs: tag) }?.id ?? ""

        let hatKurse = !sitzungen.isEmpty
        let hatCardio = raster.contains { $0.art == .cardio }
        let sichtbar = PlanWoche.sichtbareFilter(hatPlan: true, hatKurse: hatKurse, hatCardio: hatCardio)
        let filter = zustand.geltenderFilter(sichtbar: sichtbar)

        // Alle wischbaren Tage auf einmal: "Als nächstes" darf in die naechste Woche reichen.
        let alleTage = montage.flatMap { m in
            KurseWochenBerechnung.wochentage(abMontag: m, jetzt: jetzt, zeitzone: zeitzone).map(\.datum)
        }
        let termine = PlanWoche.termine(
            tage: alleTage.isEmpty ? tage : alleTage, kalender: kalender, raster: raster, kurse: sitzungen,
            cardioErledigt: cardio.erledigt, einheitenErledigt: [], filter: filter)
        let herkunft = KurseHerkunft.bilden(
            ladeZustand: kurse.ladeZustand, wocheStand: kurse.wocheStand, jetzt: jetzt)

        return ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                kopf(plan)
                if !sichtbar.isEmpty { filterLeiste(sichtbar, filter: filter) }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
                    Text(PlanTabZustand.wochenTitel(tage: tage, kalender: kalender))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DesignSystem.Color.text)
                    KurseWochenstreifen(
                        montage: montage, index: wochenIndex, jetzt: jetzt, zeitzone: zeitzone,
                        gewaehlterTagId: tagId, hoehe: 72,
                        beiWochenwahl: { index in
                            guard montage.indices.contains(index) else { return }
                            let neu = KurseWochenBerechnung.wochentage(
                                abMontag: montage[index], jetzt: jetzt, zeitzone: zeitzone).map(\.datum)
                            zustand.gewaehlterTag = PlanTabZustand.vorauswahl(tage: neu, heute: jetzt, kalender: kalender)
                        },
                        beiTagwahl: { zustand.gewaehlterTag = $0.datum },
                        label: { t in tagLabel(t, termine: termine[kalender.startOfDay(for: t.datum)] ?? []) },
                        marke: { t in marken(termine[kalender.startOfDay(for: t.datum)] ?? []) })
                    if hatKurse || hatCardio { legende(hatKurse: hatKurse, hatCardio: hatCardio) }
                }

                PlanTagListe(
                    ueberschrift: wochentage.first { $0.id == tagId }
                        .map { KurseWochenInhalt.tagesueberschrift($0, zeitzone: zeitzone) } ?? "",
                    istHeute: kalender.isDate(tag, inSameDayAs: jetzt),
                    darfAbhaken: tag <= kalender.startOfDay(for: jetzt),
                    eintraege: eintraege(termine[tag] ?? [], plan: plan, tagId: tagId),
                    naechsteEinheitKey: PlanAnzeige.heute(katalog: katalog, ablauf: planAblauf)?.einheitKey,
                    alsNaechstes: PlanTabZustand.alsNaechstes(termine: termine, nach: tag, anzahl: 2)
                        .compactMap { n in
                            let id = Self.tagId(n.tag, kalender: kalender)
                            return eintraege([n.termin], plan: plan, tagId: id).first
                                .map { (tag: Self.tagKurz(n.tag, kalender: kalender), eintrag: $0) }
                        },
                    kursZeile: { termin in
                        KursTerminZeile(
                            termin: termin, jetzt: jetzt, herkunft: herkunft,
                            zeitzone: kurse.zeitzone(fuer: termin.sessionId) ?? zeitzone,
                            trainerUndRaum: KursTerminZeile.trainerUndRaum(
                                termin, studioName: studios.count > 1 ? { studioName($0) } : nil),
                            beiAuswahl: beiKurs)
                    },
                    beiEinheit: beiEinheit,
                    beiStart: beiTrainingStarten,
                    beiCardio: { erledigt in await cardioSetzen(tagId: tagId, erledigt: erledigt) })
                // Neuer Tag, neue Liste: Lauf- und Fehlerzustand der Cardio-Karte
                // gehoeren zum Tag, an dem getippt wurde.
                .id(tagId)

                if !hatStudio { kurseOhneStudio }

                if let speicherHinweis {
                    InlineBanner(tone: .muted, message: speicherHinweis)
                }
                if let profil {
                    SecondaryButton(title: hatStudio ? "Einheit oder Kurs einplanen" : "Einheit einplanen") {
                        einplanenOffen = true
                    }
                    .sheet(isPresented: $einplanenOffen) {
                        PlanEinplanenSheet(
                            profil: profil, raster: raster, einheiten: plan.einheiten.map(\.key),
                            hatKurse: hatStudio,
                            speichern: { neu in await profilSpeichern(neu) })
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, DesignSystem.Spacing.s24)
            .padding(.bottom, DesignSystem.Spacing.s32)
            .animation(reduceMotion ? nil : DesignSystem.Motion.oeffnen, value: zustand)
        }
        .background(DesignSystem.Color.bg)
        .refreshable { await neuLaden() }
        .task(id: studios) { await neuLaden() }
        .onChange(of: netz.istOnline) { _, online in
            guard online else { return }
            Task { await neuLaden() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await neuLaden() }
        }
        .testnotizScreen()
    }

    // MARK: - Laden

    private func neuLaden() async {
        await kurse.ladenAbDieserWoche(studioIds: studios, zeitzone: zeitzone)
        await cardioLaden()
    }

    private func cardioLaden() async {
        let montage = KurseWochenBerechnung.wochenMontage(ab: Date(), zeitzone: zeitzone)
        guard let erster = montage.first, let letzter = montage.last,
              let sonntag = kalender.date(byAdding: .day, value: 6, to: letzter) else { return }
        await cardio.laden(
            von: Self.tagId(erster, kalender: kalender), bis: Self.tagId(sonntag, kalender: kalender),
            apiClient: apiClient)
    }

    private func cardioSetzen(tagId: String, erledigt: Bool) async -> String? {
        await cardio.setzen(tagId: tagId, erledigt: erledigt, apiClient: apiClient)
    }

    /// Schreibt die Tage ins Profil und laedt den Bootstrap neu -- der zeigt
    /// sie danach (`anzeigeRaster`). Der Plan bleibt dabei unveraendert (F14).
    private func profilSpeichern(_ neu: TrainingsplanProfil) async -> String? {
        do throws(APIError) {
            _ = try await apiClient.putTrainingProfile(neu)
        } catch {
            return error.servertext
        }
        await katalog.load()
        // Das Sheet schliesst trotzdem: gespeichert ist gespeichert. Nur die
        // Woche zeigt bis zum naechsten Laden noch die alten Tage.
        speicherHinweis = katalog.letzterLadefehler == nil
            ? nil : "Gespeichert – wird beim nächsten Laden angezeigt."
        return nil
    }

    // MARK: - Teile

    private func kopf(_ plan: Trainingsplan) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("PLAN")
                .font(DesignSystem.Typography.screentitel)
                .tracking(-0.8)
                .foregroundStyle(DesignSystem.Color.text)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Text(plan.einheiten.count == 1
                 ? "EINE EINHEIT"
                 : "EINHEITEN " + plan.einheiten.map { EinheitKuerzel.text($0.key) }.joined(separator: " · "))
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    private func filterLeiste(_ sichtbar: [PlanFilter], filter: PlanFilter) -> some View {
        HStack(spacing: DesignSystem.Spacing.s8) {
            ForEach(sichtbar, id: \.self) { f in
                Button { zustand.gewaehlterFilter = f } label: {
                    Chip(text: f.titel, isActive: f == filter, innenabstand: DesignSystem.Spacing.s16)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minHeight: 44)
                }
                .buttonStyle(PressButtonStyle())
                .accessibilityLabel("Filter \(f.titel)")
                .accessibilityAddTraits(f == filter ? .isSelected : [])
            }
        }
    }

    private struct MarkenEintrag: Hashable {
        let art: PlanTagMarke.Art
        let gedeckt: Bool
        init(_ art: PlanTagMarke.Art, _ gedeckt: Bool) { self.art = art; self.gedeckt = gedeckt }
    }

    private func arten(_ termine: [PlanTermin]) -> [MarkenEintrag] {
        var ergebnis: [MarkenEintrag] = []
        for termin in termine {
            switch termin {
            case .einheit(_, let erledigt):
                if !ergebnis.contains(where: { $0.art == .einheit }) { ergebnis.append(MarkenEintrag(.einheit, erledigt)) }
            case .kurs:
                if !ergebnis.contains(where: { $0.art == .kurs }) { ergebnis.append(MarkenEintrag(.kurs, false)) }
            case .cardio(_, let erledigt):
                if !ergebnis.contains(where: { $0.art == .cardio }) { ergebnis.append(MarkenEintrag(.cardio, erledigt)) }
            }
        }
        return ergebnis
    }

    /// Bleibt auch leer 8pt hoch, sonst sprunge der Streifen beim Wischen.
    private func marken(_ termine: [PlanTermin]) -> some View {
        HStack(spacing: 3) {
            ForEach(arten(termine), id: \.art) { eintrag in
                PlanTagMarke(art: eintrag.art, gedeckt: eintrag.gedeckt)
            }
        }
        .frame(height: 8)
    }

    private func tagLabel(_ tag: KurseWochentag, termine: [PlanTermin]) -> String {
        var teile = ["\(tag.wochentagVoll), \(tag.tagesnummer)."]
        if tag.istHeute { teile.append("Heute.") }
        let namen = arten(termine).map { eintrag -> String in
            switch eintrag.art {
            case .einheit: eintrag.gedeckt ? "Einheit erledigt" : "Einheit"
            case .kurs: "Kurs"
            case .cardio: eintrag.gedeckt ? "Cardio erledigt" : "Cardio"
            }
        }
        teile.append(namen.isEmpty ? "Nichts geplant." : namen.joined(separator: ", ") + ".")
        return teile.joined(separator: " ")
    }

    private func legende(hatKurse: Bool, hatCardio: Bool) -> some View {
        HStack(spacing: DesignSystem.Spacing.s16) {
            legendeEintrag(.einheit, "Einheit")
            if hatKurse { legendeEintrag(.kurs, "Kurs") }
            if hatCardio { legendeEintrag(.cardio, "Cardio") }
        }
        .accessibilityHidden(true)
    }

    private func legendeEintrag(_ art: PlanTagMarke.Art, _ text: String) -> some View {
        HStack(spacing: 6) {
            PlanTagMarke(art: art)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    /// Leinwand 2g: ohne Studio keine Kurse, aber der Weg dorthin.
    private var kurseOhneStudio: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Kurse im Plan")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.text)
                    .accessibilityAddTraits(.isHeader)
                Text("Sobald du einem Studio zugeordnet bist, erscheinen hier die Kurse, und du kannst sie in deinen Plan legen.")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                SecondaryButton(title: "Studio wählen") { beitretenOffen = true }
            }
            .padding(DesignSystem.Spacing.s16)
        }
    }

    // MARK: - Hilfen

    private func studioName(_ id: String) -> String {
        katalog.bootstrap?.studios.first { $0.id == id }?.name ?? ""
    }

    /// Ordnet die Termine des Modells ihren vollen Daten zu. Ein Kurs wird
    /// ueber Tag, Name und Beginn gefunden (das Modell traegt keine sessionId).
    private func eintraege(_ termine: [PlanTermin], plan: Trainingsplan, tagId: String) -> [PlanTagEintrag] {
        termine.compactMap { termin in
            switch termin {
            case .einheit(let key, let erledigt):
                return plan.einheiten.first { $0.key == key }.map { .einheit($0, erledigt: erledigt) }
            case .kurs(let titel, let beginn, _):
                return sitzungen.first {
                    $0.localDay == tagId && $0.name == titel && Zeitpunkt.parse($0.startsAt) == beginn
                }.map { .kurs($0) }
            case .cardio(_, let erledigt):
                return .cardio(arten: profil?.cardioArten ?? [], erledigt: erledigt)
            }
        }
    }

    static func tagId(_ tag: Date, kalender: Calendar) -> String {
        let c = kalender.dateComponents([.year, .month, .day], from: tag)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// "Freitag, 30. Okt" -- Monat ohne Punkt wie im Wochentitel.
    static func tagKurz(_ tag: Date, kalender: Calendar) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeZone = kalender.timeZone
        f.dateFormat = "EEEE"
        let wochentag = f.string(from: tag)
        f.dateFormat = "LLL"
        let monat = f.string(from: tag).replacingOccurrences(of: ".", with: "")
        return "\(wochentag), \(kalender.component(.day, from: tag)). \(monat)"
    }
}
