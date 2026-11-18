import SwiftUI

/// Der Einstieg in den Training-Tab vor einem Training (Entwurf 3a, E8):
/// die naechste Einheit der Reihe, die uebrigen Einheiten (vorziehbar),
/// offenes Cardio und das freie Training. Die eine Akzentflaeche ist
/// "Training starten".
///
/// Ohne feste Tage (Spec P2): keine Wochentage an den Optionen. Das
/// Cardio-Ziel rechnet die Ansicht mit derselben Wochenrechnung wie Home und
/// Plan-Tab (`PlanKalenderKontext.stand`).
struct TrainingAuswahlView: View {
    @Environment(CatalogStore.self) private var katalog
    @Environment(TrainingsplanAblaufStore.self) private var planAblauf
    @Environment(VerlaufStore.self) private var verlauf
    @Environment(KurseStore.self) private var kurse
    @Environment(CardioChecksStore.self) private var cardio

    let plan: Trainingsplan
    /// Tipp auf die Karte: die Einheit ansehen (E2), nicht starten.
    let beiEinheitOeffnen: (String) -> Void
    /// Die naechste Einheit (oder die eben vorgezogene) im Plan-Einstieg.
    let beiPlanStarten: () -> Void
    /// E10: freies Training auf der Kategorie Cardio.
    let beiCardio: () -> Void
    let beiFrei: () -> Void

    @State private var vorziehen: VorziehenAuftrag?
    /// Setzt das Blatt nach erfolgreichem Vorziehen; der Wechsel in den
    /// Plan-Einstieg folgt erst im onDismiss, sonst verschwaende das Blatt
    /// mit seinem Wirt mitten im Schliessen.
    @State private var startNachSchliessen = false

    var body: some View {
        let jetzt = Date()
        let kalender = planKalender
        let naechster = PlanAnzeige.heute(katalog: katalog, ablauf: planAblauf)?.einheitKey
        let modell = TrainingAuswahl.modell(
            einheiten: plan.einheiten.map(\.key), naechsteEinheitKey: naechster ?? plan.naechsteEinheitKey,
            ziel: PlanKalenderKontext.wochenziel(bootstrap: katalog.bootstrap),
            cardioErledigt: wochenStand(jetzt: jetzt).cardioErledigt)
        let muskeln = HomeZeilen.muskelnJeUebung(katalog.bootstrap)
        let namen = EinheitNamen(plan: plan, muskeln: muskeln)

        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                kopf(jetzt: jetzt, kalender: kalender)
                if let key = modell.naechsteEinheitKey,
                   let einheit = plan.einheiten.first(where: { $0.key == key }) {
                    alsNaechstes(einheit, namen: namen, muskeln: muskeln)
                }
                if !modell.weitere.isEmpty {
                    weitere(modell.weitere, naechster: modell.naechsteEinheitKey, namen: namen)
                }
                freiesTraining
            }
            .padding(.horizontal, 20)
            .padding(.vertical, DesignSystem.Spacing.s16)
        }
        .background(DesignSystem.Color.bg)
        .toolbar(.hidden, for: .navigationBar)
        // Wie PlanKarteBereich: nach "Training beenden" ist der Ablauf leer,
        // bis jemand vorbereitet. Idempotent.
        .onAppear { planAblauf.vorbereiten(bootstrap: katalog.bootstrap) }
        .sheet(item: $vorziehen, onDismiss: {
            guard startNachSchliessen else { return }
            startNachSchliessen = false
            beiPlanStarten()
        }) { auftrag in
            TrainingVorziehenSheet(
                name: namen.name(auftrag.key),
                danach: namen.name(TrainingAuswahl.danach(einheitKey: auftrag.key,
                                                          einheitKeys: plan.einheiten.map(\.key))),
                beiStarten: {
                    guard planAblauf.vorziehen(einheitKey: auftrag.key) else { return false }
                    startNachSchliessen = true
                    vorziehen = nil
                    return true
                },
                beiAbbrechen: { vorziehen = nil })
        }
    }

    // MARK: - Abschnitte

    private func kopf(jetzt: Date, kalender: Calendar) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text(Self.overline(ort: HomeZeilen.ortszeile(ort: katalog.ort, studioName: aktivesStudio?.name),
                               jetzt: jetzt, kalender: kalender))
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
            Text("TRAINING")
                .font(DesignSystem.Typography.screentitel)
                .tracking(-1)
                .foregroundStyle(DesignSystem.Color.text)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func alsNaechstes(_ einheit: TrainingsplanEinheit, namen: EinheitNamen,
                              muskeln: [String: [GeraetMuskel]]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            abschnittTitel("ALS NÄCHSTES")
            EinheitKarte(
                modell: .einheit(einheit, namen: namen, muskeln: muskeln, tag: nil, zustand: .geplant),
                geschlecht: geschlecht,
                beiTipp: { beiEinheitOeffnen(einheit.key) },
                hinweis: "Zeigt die Übungen der Einheit")
            PrimaryButton(title: "Training starten") { beiPlanStarten() }
                .testnotizElement("training.auswahl.start", typ: "PrimaryButton")
        }
    }

    private func weitere(_ optionen: [TrainingAuswahlOption], naechster: String?,
                         namen: EinheitNamen) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            abschnittTitel("AUCH IM PLAN")
            VStack(spacing: 0) {
                ForEach(Array(optionen.enumerated()), id: \.element.id) { nummer, option in
                    if nummer > 0 { Rectangle().fill(DesignSystem.Color.line).frame(height: 1) }
                    zeile(option, naechster: naechster, namen: namen)
                }
            }
            .background(DesignSystem.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        }
    }

    @ViewBuilder
    private func zeile(_ option: TrainingAuswahlOption, naechster: String?, namen: EinheitNamen) -> some View {
        switch option {
        case .einheit(let key):
            let meta = plan.einheiten.first { $0.key == key }.map(EinheitKuerzel.untertitel) ?? ""
            optionZeile(titel: namen.name(key), meta: meta) {
                // Die naechste Einheit startet direkt; jede andere wird vorgezogen (E9).
                if key == naechster { beiPlanStarten() } else { vorziehen = VorziehenAuftrag(key: key) }
            }
        case .cardio(let minuten):
            optionZeile(titel: "Cardio · \(minuten) min",
                        meta: CardioArtName.zeile(katalog.bootstrap?.member.trainingProfile?.cardioArten ?? []),
                        beiStarten: beiCardio)
        }
    }

    private func optionZeile(titel: String, meta: String, beiStarten: @escaping () -> Void) -> some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titel)
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                    .fixedSize(horizontal: false, vertical: true)
                if !meta.isEmpty {
                    Text(meta)
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            Button(action: beiStarten) {
                Text("Starten")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.text)
                    .padding(.horizontal, DesignSystem.Spacing.s16)
                    .frame(minHeight: 36)
                    .background(DesignSystem.Color.surfaceRaised)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(DesignSystem.Color.line, lineWidth: 1))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityLabel("\(titel) starten")
            .testnotizElement("training.auswahl.option", typ: "Button")
        }
        .padding(.horizontal, DesignSystem.Spacing.s16)
        .padding(.vertical, DesignSystem.Spacing.s12)
    }

    private var freiesTraining: some View {
        Button(action: beiFrei) {
            HStack(spacing: DesignSystem.Spacing.s12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Freies Training")
                        .font(DesignSystem.Typography.uebungsname)
                        .foregroundStyle(DesignSystem.Color.text)
                    Text("Geräte und Übungen selbst wählen")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
            .padding(DesignSystem.Spacing.s16)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .stroke(DesignSystem.Color.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityHint("Öffnet die Geräteliste ohne Plan")
        .testnotizElement("training.auswahl.frei", typ: "Button")
    }

    private func abschnittTitel(_ text: String) -> some View {
        Text(text)
            .font(DesignSystem.Typography.label)
            .tracking(1.5)
            .foregroundStyle(DesignSystem.Color.textMuted)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Woche (wie HomeRootView.wochenStand)

    private var aktivesStudio: BootstrapResponse.Studio? {
        katalog.bootstrap?.studios.first { $0.id == katalog.activeStudioId }
    }

    private var planZeitzone: String {
        PlanKalenderKontext.zeitzone(
            bootstrap: katalog.bootstrap, aktivesStudioId: katalog.activeStudioId, wochenZone: kurse.woche?.timezone)
    }

    private var planKalender: Calendar { PlanKalenderKontext.kalender(zeitzone: planZeitzone) }

    private var geschlecht: Geschlecht? {
        katalog.bootstrap?.member.sex.flatMap(Geschlecht.init(rawValue:))
    }

    /// Die laufende Woche wie auf Home: nur fuer das offene Cardio-Ziel.
    private func wochenStand(jetzt: Date) -> PlanWochenStand {
        PlanKalenderKontext.stand(
            bootstrap: katalog.bootstrap,
            wocheStart: KurseWochenBerechnung.montag(enthaelt: jetzt, zeitzone: planZeitzone), heute: jetzt,
            kalender: planKalender,
            heuteEinheitKey: PlanAnzeige.heute(katalog: katalog, ablauf: planAblauf)?.einheitKey,
            sitzungen: verlauf.sessions, cardioChecks: cardio.checks,
            kurse: [], filter: .alle)
    }

    // MARK: - Texte

    // Feste Namen: unabhaengig von Locale-Eigenheiten (wie EinheitKarteModell).
    private static let langNamen = ["SONNTAG", "MONTAG", "DIENSTAG", "MITTWOCH", "DONNERSTAG", "FREITAG", "SAMSTAG"]

    private static func wochentagIndex(_ tag: Date, kalender: Calendar) -> Int {
        (kalender.component(.weekday, from: tag) - 1 + 7) % 7
    }

    /// "<STUDIO> · <WOCHENTAG>"; ohne Ortsnamen nur der Wochentag.
    static func overline(ort: String?, jetzt: Date, kalender: Calendar) -> String {
        let wochentag = langNamen[wochentagIndex(jetzt, kalender: kalender)]
        guard let ort, !ort.isEmpty else { return wochentag }
        return "\(ort.uppercased()) · \(wochentag)"
    }
}

/// Die Einheit, fuer die das Vorziehen-Blatt offen ist.
private struct VorziehenAuftrag: Identifiable {
    let key: String
    var id: String { key }
}
