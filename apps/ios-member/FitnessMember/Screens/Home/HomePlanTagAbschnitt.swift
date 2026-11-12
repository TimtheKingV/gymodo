import SwiftUI

/// Die gebuchten Kurse eines gewaehlten kuenftigen Tages unter dem Streifen
/// (E1, Entwurf 1b). Steht an der Stelle von "Nächste Einheit", solange
/// der Tag gewaehlt ist.
///
/// **Home bleibt Home.** Ein Tipp auf den Tag wechselte frueher in den
/// Plan-Tab, und weil beide Screens oben gleich aussehen, merkte niemand
/// den Wechsel. Jetzt fuehrt nur der Link "Im Plan" dorthin. Seit der Woche
/// ohne feste Tage (Spec P2 §2 #5) traegt ein kuenftiger Tag nur noch
/// gebuchte Kurse -- keine geplanten Einheiten, kein Cardio. Ein Kurs oeffnet
/// sein Detail im Home-Stack. Kein Hinweistext unter den Karten (Tim zu 1b).
struct HomePlanTagAbschnitt: View {
    /// `startOfDay` des Tages im Kalender des Plans.
    let tag: Date
    /// Die Kurs-Karten des Tages aus `PlanWochenStand.karten`.
    let kurse: [CourseWeekSession]
    let kalender: Calendar
    /// Tipp auf einen Kurs: die sessionId, der Aufrufer pusht `HomeRoute.kursDetail`.
    let beiKurs: (String) -> Void
    /// "Im Plan": in den Plan-Tab auf genau diesen Tag.
    let beiPlanZeigen: (PlanSprung) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            kopf
            ForEach(kurse, id: \.sessionId) { kurs in
                zeile(kurs)
            }
        }
        .testnotizElement("home.plantag", typ: "Section")
    }

    /// "MITTWOCH, 11. NOV · GEPLANT" -- derselbe Tagestext wie im Plan-Tab
    /// (`PlanRootView.tagKurz`).
    nonisolated static func kopfText(_ tag: Date, kalender: Calendar) -> String {
        "\(PlanRootView.tagKurz(tag, kalender: kalender).uppercased()) · GEPLANT"
    }

    /// Die gebuchten, nicht abgesagten Kurse eines Tages aus den Wochenkarten,
    /// nach Beginn -- dieselben, die der Streifen als Marke zeigt.
    nonisolated static func kurse(am tag: Date, karten: [WochenKarte], kalender: Calendar) -> [CourseWeekSession] {
        karten.compactMap { karte -> CourseWeekSession? in
            guard case .kurs(let kurs) = karte.art,
                  let start = Zeitpunkt.parse(kurs.startsAt),
                  kalender.isDate(start, inSameDayAs: tag) else { return nil }
            return kurs
        }
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

    private func zeile(_ kurs: CourseWeekSession) -> some View {
        let start = Zeitpunkt.parse(kurs.startsAt) ?? tag
        let karte = WochenKarte(
            id: "kurs-\(kurs.sessionId)", art: .kurs(kurs), erledigtAm: nil,
            quelle: .keine, istNaechste: false, minuten: kurs.durationMin)
        return PlanWochenKarte(
            kachel: .kurs(
                wochentag: PlanWochenKarten.wochentagKachel(start, kalender: kalender),
                tag: kalender.component(.day, from: start), begonnen: false),
            titel: kurs.name,
            untertitel: PlanWochenKarten.untertitel(karte, einheiten: [], kalender: kalender),
            rechts: .keins,
            beiTipp: { beiKurs(kurs.sessionId) }, tippHinweis: "Zeigt den Kurs")
    }
}
