import SwiftUI

/// Die Plantermine eines gewaehlten kuenftigen Tages unter dem Streifen
/// (E1, Entwurf 1b). Steht an der Stelle von "Nächste Einheit", solange
/// der Tag gewaehlt ist.
///
/// **Home bleibt Home.** Ein Tipp auf den Tag wechselte frueher in den
/// Plan-Tab, und weil beide Screens oben gleich aussehen, merkte niemand
/// den Wechsel. Jetzt fuehrt nur der Link "Im Plan" dorthin. Die
/// Einheitenkarte oeffnet die Einheit im Home-Stack (E2); gestartet wird
/// hier nichts -- am kuenftigen Tag gibt es keinen Start, und Vorziehen
/// geht ueber die Einheit selbst. Kein Hinweistext unter der Karte (Tim
/// zu 1b).
struct HomePlanTagAbschnitt: View {
    /// `startOfDay` des Tages im Kalender des Plans.
    let tag: Date
    let termine: [PlanTermin]
    let plan: Trainingsplan
    let muskeln: [String: [GeraetMuskel]]
    let geschlecht: Geschlecht?
    let kalender: Calendar
    /// Die Cardio-Arten aus dem Trainingsprofil -- `PlanKalender.termine`
    /// laesst sie leer, wie im Plan-Tab reicht sie der Aufrufer nach.
    var cardioArten: [String] = []
    /// Die eigenen Kursbuchungen (`GespeicherteBuchungen.termine`): ein Kurs
    /// des Plans oeffnet so sein Detail im Home-Stack (`beiKurs`).
    var eigeneKurse: [GespeicherterTermin] = []
    /// Tipp auf einen Kurs mit gefundener Buchung: die sessionId, der
    /// Aufrufer pusht `HomeRoute.kursDetail`.
    var beiKurs: (String) -> Void = { _ in }
    /// Tipp auf eine Einheitenkarte: der Aufrufer pusht `HomeRoute.einheit`.
    let beiEinheit: (String) -> Void
    /// "Im Plan", Cardio und ein Kurs ohne eigene Buchung: in den Plan-Tab
    /// auf genau diesen Tag.
    let beiPlanZeigen: (PlanSprung) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            kopf
            ForEach(Array(termine.enumerated()), id: \.offset) { _, termin in
                zeile(termin)
            }
        }
        .testnotizElement("home.plantag", typ: "Section")
    }

    /// "MITTWOCH, 11. NOV · GEPLANT" -- derselbe Tagestext wie "Nächste
    /// Einheit" und "Als nächstes" im Plan-Tab (`PlanRootView.tagKurz`).
    nonisolated static func kopfText(_ tag: Date, kalender: Calendar) -> String {
        "\(PlanRootView.tagKurz(tag, kalender: kalender).uppercased()) · GEPLANT"
    }

    /// Die eigene Buchung zu einem Kurs des Plans: gleicher Beginn, bei
    /// mehreren der gleiche Name. Das Modell (`PlanTermin.kurs`) traegt keine
    /// sessionId. nil = keine eindeutige Buchung, dann geht es in den Plan.
    /// `nonisolated`: reine Rechnung, auch ausserhalb des Main Actors (Tests).
    nonisolated static func kursSessionId(titel: String, beginn: Date, eigene: [GespeicherterTermin]) -> String? {
        let gleichzeitig = eigene.filter { Zeitpunkt.parse($0.startsAt) == beginn }
        if let genau = gleichzeitig.first(where: { $0.name == titel }) { return genau.sessionId }
        return gleichzeitig.count == 1 ? gleichzeitig[0].sessionId : nil
    }

    private var kopf: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(Self.kopfText(tag, kalender: kalender))
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: DesignSystem.Spacing.s8)
            Button { beiPlanZeigen(.tag(tag)) } label: {
                HStack(spacing: DesignSystem.Spacing.s4) {
                    Text("Im Plan")
                        .font(.system(size: 13, weight: .bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(DesignSystem.Color.accent)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityLabel("Im Plan")
            .accessibilityHint("Öffnet den Tag im Plan")
            .testnotizElement("home.plantag.imPlan", typ: "Button")
        }
    }

    @ViewBuilder
    private func zeile(_ termin: PlanTermin) -> some View {
        switch termin {
        case .einheit(let key, let zustand):
            if let einheit = plan.einheiten.first(where: { $0.key == key }) {
                EinheitKarte(
                    modell: .einheit(
                        einheit, namen: EinheitNamen(plan: plan, muskeln: muskeln), muskeln: muskeln,
                        tag: nil, zustand: zustand),
                    geschlecht: geschlecht, kalender: kalender,
                    beiTipp: { beiEinheit(key) },
                    hinweis: "Zeigt die Übungen der Einheit")
            }
        case .kurs(let titel, let beginn, _, _):
            let sessionId = Self.kursSessionId(titel: titel, beginn: beginn, eigene: eigeneKurse)
            Button {
                if let sessionId { beiKurs(sessionId) } else { beiPlanZeigen(.tag(tag)) }
            } label: {
                PlanTerminZeile(
                    kaestchen: AnyView(PlanKursKaestchen()), titel: titel,
                    tag: KursZeit.uhrzeit(beginn, zeitzone: kalender.timeZone.identifier))
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityHint(sessionId != nil ? "Zeigt den Kurs" : "Öffnet den Tag im Plan")
        case .cardio:
            Button { beiPlanZeigen(.tag(tag)) } label: {
                PlanTerminZeile(kaestchen: AnyView(PlanCardioKaestchen()), titel: "Cardio", tag: CardioArtName.zeile(cardioArten))
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityHint("Öffnet den Tag im Plan")
        }
    }
}
