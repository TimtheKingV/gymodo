import SwiftUI

/// Der Tab "Plan" (Spec P2 §3, Leinwand "Gewählt · Kalender B + Karten A"):
/// die Woche als Liste von Haken. Oben der Wochenstreifen mit dem, was
/// geleistet ist (und gebuchten Kursen), darunter "DIESE WOCHE" -- erledigte
/// und offene Kraft- und Cardio-Karten ohne Tag --, dann "KURSE" und
/// "Woche anpassen". Kein "verpasst", kein Uebertrag: Montag beginnt neu.
/// Ohne aktiven Plan zeigt er die Kurse wie bisher und darueber die Karte
/// "Plan einrichten" (Ruling), dazu Cardio-Karten, wenn ein Cardio-Ziel steht.
///
/// Gerechnet wird in `PlanWochenRechnung` (ueber `PlanKalenderKontext.stand`,
/// dieselbe Rechnung wie auf Home); hier wird nur gezeichnet.
struct PlanRootView: View {
    let apiClient: APIClient
    let beiKurs: (String) -> Void
    let beiEinheit: (String) -> Void
    /// Session-Id eines vergangenen Trainings -> Training-Detail im Plan-Stack.
    let beiTraining: (String) -> Void
    let beiTrainingStarten: () -> Void
    /// Ein Tag, den Home zeigen will (ein Tag der Streak-Woche, "Nächste Einheit"
    /// als Kurs oder Cardio, Spec 1.1). Wird beim Uebernehmen geleert, damit derselbe
    /// Tag ein zweites Mal ankommt.
    @Binding var tagWunsch: Date?

    @Environment(CatalogStore.self) private var katalog
    @Environment(KurseStore.self) private var kurse
    @Environment(TrainingsplanAblaufStore.self) private var planAblauf
    @Environment(NetzwerkMonitor.self) private var netz
    @Environment(CardioChecksStore.self) private var cardio
    @Environment(VerlaufStore.self) private var verlauf
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var zustand = PlanTabZustand()
    /// Gespeichert, aber der Bootstrap kam nicht nach.
    @State private var speicherHinweis: String?
    @State private var einplanenOffen = false
    @State private var planFlowUmfang: OnboardingUmfang?
    @State private var beitretenOffen = false
    /// Der Tag des Streifens, dessen Blatt offen ist.
    @State private var blattTag: Date?

    var body: some View {
        Group {
            if let plan = PlanAnzeige.plan(bootstrap: katalog.bootstrap) {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    planInhalt(plan: plan, jetzt: context.date)
                }
            } else {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    ohnePlan(jetzt: context.date)
                }
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
            zustand.ansicht = .woche
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
    /// (`PlanEinrichten.zeigtKarte`, dieselbe Regel wie auf Home). Steht ein
    /// Cardio-Ziel, kommen die Cardio-Karten der Woche dazu (Spec P2 §3).
    private func ohnePlan(jetzt: Date) -> some View {
        let kontext = kartenKontext(plan: nil, jetzt: jetzt)
        let cardioKarten = PlanKalenderKontext.wochenziel(bootstrap: katalog.bootstrap).cardio > 0
            ? PlanKalenderKontext.stand(
                bootstrap: katalog.bootstrap,
                wocheStart: KurseWochenBerechnung.montag(enthaelt: jetzt, zeitzone: zeitzone), heute: jetzt,
                kalender: kalender, heuteEinheitKey: nil, sitzungen: verlauf.sessions,
                cardioChecks: cardio.checks, kurse: [], filter: .cardio).karten
            : []
        let einrichten = katalog.bootstrap.map { PlanEinrichten.zeigtKarte(member: $0.member) } ?? false
        let zusatz: AnyView? = einrichten || !cardioKarten.isEmpty
            ? AnyView(VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                if einrichten, let b = katalog.bootstrap {
                    PlanEinrichtenKarte { planFlowUmfang = PlanEinrichten.umfang(member: b.member) }
                }
                if !cardioKarten.isEmpty {
                    abschnitt("DIESE WOCHE", karten: cardioKarten, kontext: kontext)
                }
            })
            : nil
        return KurseWochenView(beiAuswahl: beiKurs, loader: apiClient, titel: "PLAN", zusatz: zusatz)
            .task(id: studios) { await cardioLaden() }
    }

    // MARK: - Abgeleitetes

    private var studios: [String] {
        KurseStudios.reihenfolge(
            alle: katalog.bootstrap?.studios.map(\.id) ?? [], aktiv: katalog.activeStudioId)
    }

    private var hatStudio: Bool { !studios.isEmpty }

    /// Wie `KurseWochenView.zeitzoneFuerAnfrage`; ohne Studio die des Geraets.
    private var zeitzone: String {
        PlanKalenderKontext.zeitzone(
            bootstrap: katalog.bootstrap, aktivesStudioId: katalog.activeStudioId, wochenZone: kurse.woche?.timezone)
    }

    private var kalender: Calendar { PlanKalenderKontext.kalender(zeitzone: zeitzone) }

    private var profil: TrainingsplanProfil? { katalog.bootstrap?.member.trainingProfile }

    /// Wie weit der Streifen zurueckreicht: bis zum Planbeginn, gedeckelt in
    /// `wochenMontage`.
    private var zurueckBis: Date? {
        PlanAnzeige.plan(bootstrap: katalog.bootstrap)?.beginn.flatMap(Zeitpunkt.parse)
    }

    private var sitzungen: [CourseWeekSession] { hatStudio ? (kurse.woche?.sessions ?? []) : [] }

    // MARK: - Mit Plan

    private func planInhalt(plan: Trainingsplan, jetzt: Date) -> some View {
        let kalender = kalender
        let beginn = plan.beginn.flatMap(Zeitpunkt.parse)
        let montage = KurseWochenBerechnung.wochenMontage(ab: jetzt, zeitzone: zeitzone, zurueckBis: beginn)
        let wochenIndex = PlanTabZustand.wochenIndex(montage: montage, tag: zustand.gewaehlterTag, heute: jetzt)
        let montag = montage.indices.contains(wochenIndex) ? montage[wochenIndex]
            : KurseWochenBerechnung.montag(enthaelt: jetzt, zeitzone: zeitzone)
        let tage = KurseWochenBerechnung.wochentage(abMontag: montag, jetzt: jetzt, zeitzone: zeitzone).map(\.datum)
        let tag = zustand.geltenderTag(tage: tage, heute: jetzt, kalender: kalender)

        let ziel = PlanKalenderKontext.wochenziel(bootstrap: katalog.bootstrap)
        let hatKurse = !sitzungen.isEmpty
        let hatCardio = ziel.cardio > 0 || !cardio.checks.isEmpty
        let sichtbar = PlanWoche.sichtbareFilter(hatPlan: true, hatKurse: hatKurse, hatCardio: hatCardio)
        let filter = zustand.geltenderFilter(sichtbar: sichtbar)
        let heuteKey = PlanAnzeige.heute(katalog: katalog, ablauf: planAblauf)?.einheitKey
        let stand: (Date) -> PlanWochenStand = { m in
            PlanKalenderKontext.stand(
                bootstrap: katalog.bootstrap, wocheStart: m, heute: jetzt, kalender: kalender,
                heuteEinheitKey: heuteKey, sitzungen: verlauf.sessions, cardioChecks: cardio.checks,
                kurse: sitzungen, filter: filter)
        }
        let woche = stand(montag)
        let kontext = kartenKontext(plan: plan, jetzt: jetzt)

        return ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                kopf
                if !sichtbar.isEmpty { filterLeiste(sichtbar, filter: filter) }

                switch zustand.ansicht {
                case .woche:
                    wochenAnsicht(
                        woche: woche, montage: montage, wochenIndex: wochenIndex, tage: tage, ziel: ziel,
                        jetzt: jetzt, kontext: kontext)
                case .monat:
                    monatsAnsicht(
                        montage: montage, tag: tag, stand: stand, hatKurse: hatKurse, hatCardio: hatCardio,
                        jetzt: jetzt, kontext: kontext)
                }

                if !hatStudio { kurseOhneStudio }

                if let speicherHinweis {
                    InlineBanner(tone: .muted, message: speicherHinweis)
                }
                if let profil {
                    SecondaryButton(title: "Woche anpassen") { einplanenOffen = true }
                        .sheet(isPresented: $einplanenOffen) {
                            WocheAnpassenSheet(
                                ziel: ziel, profil: profil,
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
        .sheet(isPresented: Binding(get: { blattTag != nil }, set: { if !$0 { blattTag = nil } })) {
            if let blattTag {
                PlanTagBlatt(ueberschrift: Self.tagKurz(blattTag, kalender: kalender)) {
                    ForEach(Self.karten(am: blattTag, in: woche.karten, kalender: kalender)) { karte in
                        karteAnsicht(karte, kontext: kontext, vorTipp: { self.blattTag = nil })
                    }
                }
            }
        }
        .testnotizScreen()
    }

    // MARK: - Woche

    @ViewBuilder
    private func wochenAnsicht(
        woche: PlanWochenStand, montage: [Date], wochenIndex: Int, tage: [Date], ziel: Wochenziel,
        jetzt: Date, kontext: KartenKontext
    ) -> some View {
        let kalender = kontext.kalender
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text(PlanTabZustand.wochenTitel(tage: tage, kalender: kalender))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(DesignSystem.Color.text)
            KurseWochenstreifen(
                montage: montage, index: wochenIndex, jetzt: jetzt, zeitzone: zeitzone,
                // Der Buchstabe ueber heute steht hell -- ausgewaehlt ist kein Tag.
                gewaehlterTagId: kontext.heuteId, hoehe: 64,
                zelle: { t in
                    AnyView(PlanTagZelle(
                        nummer: t.tagesnummer, marken: woche.marken[kalender.startOfDay(for: t.datum)] ?? [],
                        istHeute: t.istHeute))
                },
                beiWochenwahl: { index in
                    guard montage.indices.contains(index) else { return }
                    let neu = KurseWochenBerechnung.wochentage(
                        abMontag: montage[index], jetzt: jetzt, zeitzone: zeitzone).map(\.datum)
                    zustand.gewaehlterTag = PlanTabZustand.vorauswahl(tage: neu, heute: jetzt, kalender: kalender)
                },
                beiTagwahl: { t in
                    // Nur ein Tag mit Inhalt oeffnet ein Blatt.
                    guard !(woche.marken[kalender.startOfDay(for: t.datum)] ?? []).isEmpty else { return }
                    blattTag = kalender.startOfDay(for: t.datum)
                },
                label: { t in
                    PlanTagZelle.label(
                        wochentag: t.wochentagVoll, nummer: t.tagesnummer, istHeute: t.istHeute,
                        marken: woche.marken[kalender.startOfDay(for: t.datum)] ?? [])
                },
                marke: { _ in EmptyView() })
        }

        let ohneKurse = woche.karten.filter { !Self.istKurs($0) }
        let kursKarten = woche.karten.filter(Self.istKurs)
        switch woche.phase {
        case .laufend, .vergangen:
            if !ohneKurse.isEmpty {
                abschnitt(woche.phase == .laufend ? "DIESE WOCHE" : "ERLEDIGT", karten: ohneKurse, kontext: kontext)
            }
        case .kuenftig:
            Text(PlanWochenKarten.ausblick(ziel))
                .font(.system(size: 15))
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
        if !kursKarten.isEmpty {
            abschnitt("KURSE", karten: kursKarten, kontext: kontext)
        }
    }

    // MARK: - Monat

    @ViewBuilder
    private func monatsAnsicht(
        montage: [Date], tag: Date, stand: (Date) -> PlanWochenStand, hatKurse: Bool, hatCardio: Bool,
        jetzt: Date, kontext: KartenKontext
    ) -> some View {
        let kalender = kontext.kalender
        // Nur die wischbaren Wochen, die den Monat beruehren: dahinter haette
        // die Woche keine Seite.
        let monat = kalender.dateInterval(of: .month, for: tag)
        let wochen = montage.filter { m in
            guard let monat else { return false }
            let ende = kalender.date(byAdding: .day, value: 7, to: m) ?? m
            return ende > monat.start && m < monat.end
        }.map(stand)
        let marken = wochen.reduce(into: [Date: [TagMarke]]()) { $0.merge($1.marken) { a, _ in a } }
        let karten = wochen.flatMap(\.karten)
        let erster = montage.first.map { kalender.startOfDay(for: $0) } ?? kalender.startOfDay(for: jetzt)
        let letzter = montage.last.flatMap { kalender.date(byAdding: .day, value: 7, to: $0) } ?? jetzt

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            PlanMonatsgitter(
                monat: tag, kalender: kalender, heute: jetzt,
                marken: { d in marken[d] ?? [] },
                gewaehlt: tag,
                waehlbar: { d in d >= erster && d < letzter },
                label: { d in
                    PlanTagZelle.label(
                        wochentag: Self.wochentagVoll(d, kalender: kalender),
                        nummer: kalender.component(.day, from: d),
                        istHeute: kalender.isDate(d, inSameDayAs: jetzt), marken: marken[d] ?? [])
                },
                beiTag: { d in zustand.gewaehlterTag = d })
            legende(hatKurse: hatKurse, hatCardio: hatCardio)
        }

        let amTag = Self.karten(am: tag, in: karten, kalender: kalender)
        VStack(alignment: .leading, spacing: 10) {
            Text(Self.tagKurz(tag, kalender: kalender).uppercased())
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .accessibilityAddTraits(.isHeader)
            if amTag.isEmpty {
                Text("Nichts eingetragen.")
                    .font(.system(size: 15))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            } else {
                ForEach(amTag) { karte in karteAnsicht(karte, kontext: kontext) }
            }
        }
    }

    // MARK: - Karten

    /// Was jede Karte zum Zeichnen braucht, einmal je Durchlauf gerechnet.
    struct KartenKontext {
        let einheiten: [TrainingsplanEinheit]
        let erledigt: [ErledigteEinheit]
        let namen: EinheitNamen
        let muskeln: [String: [GeraetMuskel]]
        let geschlecht: Geschlecht?
        let kalender: Calendar
        let heuteId: String
    }

    private func kartenKontext(plan: Trainingsplan?, jetzt: Date) -> KartenKontext {
        let muskeln = HomeZeilen.muskelnJeUebung(katalog.bootstrap)
        return KartenKontext(
            einheiten: plan?.einheiten ?? [], erledigt: plan?.erledigt ?? [],
            namen: plan.map { EinheitNamen(plan: $0, muskeln: muskeln) } ?? EinheitNamen(bootstrap: nil),
            muskeln: muskeln,
            geschlecht: katalog.bootstrap?.member.sex.flatMap(Geschlecht.init(rawValue:)),
            kalender: kalender, heuteId: Self.tagId(jetzt, kalender: kalender))
    }

    private func abschnitt(_ titel: String, karten: [WochenKarte], kontext: KartenKontext) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titel)
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .accessibilityAddTraits(.isHeader)
            ForEach(karten) { karte in karteAnsicht(karte, kontext: kontext) }
        }
    }

    /// Eine Wochenkarte mit ihrem Tipp: erledigtes Training -> Training-Detail,
    /// offene Kraft -> Einheit, Kurs -> Kursdetail; Cardio offen -> "Abhaken"
    /// (Handhaken fuer heute), von Hand abgehakt -> "Rückgängig". `vorTipp`
    /// schliesst ein Blatt, bevor es weitergeht.
    private func karteAnsicht(
        _ karte: WochenKarte, kontext: KartenKontext, vorTipp: @escaping () -> Void = {}
    ) -> some View {
        let untertitel = { (herkunft: PlanWochenKarten.CardioHerkunft?, kal: Calendar) in
            PlanWochenKarten.untertitel(karte, einheiten: kontext.einheiten, kalender: kal, herkunft: herkunft)
        }
        let titel = PlanWochenKarten.titel(karte, namen: kontext.namen)
        let sitzungId: String? = if case .sitzung(let id) = karte.quelle { id } else { nil }
        let zumTraining: (() -> Void)? = sitzungId.map { id in { vorTipp(); beiTraining(id) } }

        switch karte.art {
        case .kraft(let key):
            let einheit = key.flatMap { k in kontext.einheiten.first { $0.key == k } }
            let kachel: PlanWochenKarte.Kachel = einheit.map {
                .muskeln(TrainingsProfil.berechne(einheit: $0, muskeln: kontext.muskeln).stufen)
            } ?? .hantel
            if karte.erledigtAm != nil {
                return PlanWochenKarte(
                    kachel: kachel, titel: titel, untertitel: untertitel(nil, kontext.kalender), rechts: .haken,
                    geschlecht: kontext.geschlecht, beiTipp: zumTraining, tippHinweis: "Zeigt das Training")
            }
            return PlanWochenKarte(
                kachel: kachel, kopf: karte.istNaechste ? "ALS NÄCHSTES" : nil, titel: titel,
                untertitel: untertitel(nil, kontext.kalender), rechts: .offen, hervorgehoben: karte.istNaechste,
                geschlecht: kontext.geschlecht,
                beiTipp: key.map { k in { vorTipp(); beiEinheit(k) } },
                tippHinweis: "Zeigt die Übungen der Einheit")
        case .cardio:
            switch karte.quelle {
            case .sitzung(let id):
                let herkunft = PlanWochenKarten.herkunft(
                    sitzungId: id, sitzungen: verlauf.sessions, erledigt: kontext.erledigt)
                return PlanWochenKarte(
                    kachel: .cardio, titel: titel, untertitel: untertitel(herkunft, kontext.kalender),
                    rechts: .haken, beiTipp: zumTraining, tippHinweis: "Zeigt das Training")
            case .hand(let checkId):
                return PlanWochenKarte(
                    kachel: .cardio, titel: titel, untertitel: untertitel(nil, kontext.kalender),
                    rechts: .knopf(titel: "Rückgängig", hinweis: "Nimmt das Abhaken zurück") {
                        await cardio.zuruecknehmen(id: checkId, apiClient: apiClient)
                    })
            case .keine:
                return PlanWochenKarte(
                    kachel: .cardio, titel: titel, untertitel: untertitel(nil, kontext.kalender),
                    rechts: .knopf(titel: "Abhaken", hinweis: "Hakt Cardio für heute ab") {
                        await cardio.abhaken(tagId: kontext.heuteId, apiClient: apiClient)
                    })
            }
        case .kurs(let kurs):
            // Die Uhrzeit in der Zeitzone des Kursstudios.
            let kursKalender = kurse.zeitzone(fuer: kurs.sessionId)
                .map(PlanKalenderKontext.kalender(zeitzone:)) ?? kontext.kalender
            let start = Zeitpunkt.parse(kurs.startsAt) ?? Date()
            return PlanWochenKarte(
                kachel: .kurs(
                    wochentag: PlanWochenKarten.wochentagKachel(start, kalender: kursKalender),
                    tag: kursKalender.component(.day, from: start), begonnen: karte.erledigtAm != nil),
                titel: titel, untertitel: untertitel(nil, kursKalender), rechts: .keins,
                beiTipp: { vorTipp(); beiKurs(kurs.sessionId) }, tippHinweis: "Zeigt den Kurs")
        }
    }

    // MARK: - Laden

    private func neuLaden() async {
        await kurse.ladenAbDieserWoche(studioIds: studios, zeitzone: zeitzone)
        await cardioLaden()
    }

    private func cardioLaden() async {
        let montage = KurseWochenBerechnung.wochenMontage(ab: Date(), zeitzone: zeitzone, zurueckBis: zurueckBis)
        guard let erster = montage.first, let letzter = montage.last,
              let sonntag = kalender.date(byAdding: .day, value: 6, to: letzter) else { return }
        await cardio.laden(
            von: Self.tagId(erster, kalender: kalender), bis: Self.tagId(sonntag, kalender: kalender),
            apiClient: apiClient)
    }

    /// Schreibt das Profil und laedt den Bootstrap neu. Der Plan bleibt dabei
    /// unveraendert (F14).
    private func profilSpeichern(_ neu: TrainingsplanProfil) async -> String? {
        do throws(APIError) {
            _ = try await apiClient.putTrainingProfile(neu)
        } catch {
            return error.servertext
        }
        await katalog.load()
        // Das Sheet schliesst trotzdem: gespeichert ist gespeichert. Nur die
        // Woche zeigt bis zum naechsten Laden noch den alten Stand.
        speicherHinweis = katalog.letzterLadefehler == nil
            ? nil : "Gespeichert – wird beim nächsten Laden angezeigt."
        return nil
    }

    // MARK: - Teile

    /// Rechts der Umschalter Woche/Monat.
    private var kopf: some View {
        HStack(alignment: .center) {
            Text("PLAN")
                .font(DesignSystem.Typography.screentitel)
                .tracking(-0.8)
                .foregroundStyle(DesignSystem.Color.text)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            SegmentSchalter(werte: PlanAnsicht.allCases, auswahl: $zustand.ansicht, titel: \.titel)
                .frame(width: 168)
                .accessibilityLabel("Ansicht")
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

    /// Legende des Monats: Kraft / Kurs / Cardio -- kein "verpasst".
    private func legende(hatKurse: Bool, hatCardio: Bool) -> some View {
        HStack(spacing: DesignSystem.Spacing.s16) {
            legendeEintrag(.kraft, "Kraft")
            if hatKurse { legendeEintrag(.kurs, "Kurs") }
            if hatCardio { legendeEintrag(.cardio, "Cardio") }
        }
        .accessibilityHidden(true)
    }

    private func legendeEintrag(_ marke: TagMarke, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: PlanTagZelle.symbol(marke) ?? "circle")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.text)
                .frame(width: 20, height: 20)
                .overlay(Circle().strokeBorder(DesignSystem.Color.accent, lineWidth: 1.5))
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
                Text("Sobald du einem Studio zugeordnet bist, erscheinen hier die Kurse, die du buchst.")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                SecondaryButton(title: "Studio wählen") { beitretenOffen = true }
            }
            .padding(DesignSystem.Spacing.s16)
        }
    }

    // MARK: - Hilfen

    static func istKurs(_ karte: WochenKarte) -> Bool {
        if case .kurs = karte.art { return true }
        return false
    }

    /// Die erledigten Karten und Kurse eines Tages; offene Karten haben keinen Tag.
    static func karten(am tag: Date, in karten: [WochenKarte], kalender: Calendar) -> [WochenKarte] {
        karten.filter { karte in
            let datum: Date? = if case .kurs(let kurs) = karte.art { Zeitpunkt.parse(kurs.startsAt) } else { karte.erledigtAm }
            return datum.map { kalender.isDate($0, inSameDayAs: tag) } ?? false
        }
    }

    /// "Montag" -- fuer VoiceOver im Monatsgitter.
    static func wochentagVoll(_ tag: Date, kalender: Calendar) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeZone = kalender.timeZone
        f.dateFormat = "EEEE"
        return f.string(from: tag)
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
