import SwiftUI

/// Entwurf 3.3 "Schalter an, bestätigt": der Kandidat, der Schalter (an)
/// mit dem, was sich aendert, und "Übernehmen" als die eine Akzentflaeche.
/// Ein Fehler bleibt im Sheet stehen, samt "Erneut versuchen"; nichts
/// schliesst als Erfolg, was keiner war.
struct PlanTauschBestaetigung: View {
    let sitzung: PlanTauschSitzung
    let kandidat: TauschKandidat
    let beiFertig: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text(kandidat.name.uppercased())
                .font(.system(size: 20, weight: .black))
                .tracking(-0.4)
                .foregroundStyle(DesignSystem.Color.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if sitzung.grund == nil {
                PlanTauschSchalter(sitzung: sitzung, hinweis: PlanTausch.bestaetigungsHinweis(
                    einheitKey: sitzung.auftrag.einheitKey, uebung: kandidat.name))
            } else {
                // Aus "Übung gefällt mir nicht": die Dauer steht fest.
                Text(PlanTausch.bestaetigungsHinweis(einheitKey: sitzung.auftrag.einheitKey, uebung: kandidat.name))
                    .font(.system(size: 14))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let fehler = sitzung.fehler {
                InlineBanner(tone: .danger, message: PlanTausch.fehlerText(fehler))
            }
            PrimaryButton(title: sitzung.fehler == nil ? "Übernehmen" : "Erneut versuchen",
                          isLoading: sitzung.schreibtGerade) {
                if await sitzung.uebernehmen() { beiFertig() }
            }
            .padding(.top, DesignSystem.Spacing.s4)
            .accessibilityHint("Ändert deinen Plan dauerhaft")
            // Der Server nimmt die Uebung nicht: heute geht sie trotzdem.
            if sitzung.grund != nil, sitzung.fehler != nil {
                SecondaryButton(title: "Nur heute") {
                    if sitzung.nurHeuteTauschen() { beiFertig() }
                }
                .accessibilityHint("Tauscht nur für heute, dein Plan bleibt")
            }
            PlanLeiserKnopf(titel: "Abbrechen", aktiv: !sitzung.schreibtGerade) { sitzung.abbrechen() }
        }
        .padding(.horizontal, 18)
        .padding(.top, 28)
        .padding(.bottom, DesignSystem.Spacing.s8)
    }
}

/// "Dauerhaft im Plan ändern" mit eigenem Schalter (Entwurf `.switch`):
/// ein System-Toggle waere mit Akzent gefuellt -- eine zweite Akzentflaeche.
/// Offline laesst er sich nicht einschalten ("Braucht Verbindung"), wohl
/// aber aus.
struct PlanTauschSchalter: View {
    let sitzung: PlanTauschSitzung
    let hinweis: String

    var body: some View {
        let an = sitzung.dauerhaft
        let gesperrt = !an && !sitzung.dauerhaftMoeglich
        Button {
            sitzung.dauerhaftSetzen(!an)
        } label: {
            HStack(spacing: DesignSystem.Spacing.s12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dauerhaft im Plan ändern")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(gesperrt ? DesignSystem.Color.textMuted : DesignSystem.Color.text)
                    Text(hinweis)
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                    if gesperrt {
                        // Nie stumm gesperrt (designsystem.md SS5).
                        Text("Braucht Verbindung")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignSystem.Color.textMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                PlanSchalterGrafik(an: an)
                    .opacity(gesperrt ? 0.5 : 1)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        // Auch waehrend "Übernehmen" schreibt, wie "Abbrechen": der Tausch
        // geht so aus, wie er bestaetigt wurde.
        .disabled(gesperrt || sitzung.schreibtGerade)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dauerhaft im Plan ändern")
        .accessibilityValue(an ? "An" : "Aus")
        .accessibilityHint(gesperrt ? "Braucht Verbindung. \(hinweis)" : hinweis)
        .accessibilityAddTraits(.isToggle)
    }
}

/// Der Schalter selbst: aus grau, an mit Akzent-UMRISS und weissem Knopf.
private struct PlanSchalterGrafik: View {
    let an: Bool

    var body: some View {
        Capsule()
            .fill(DesignSystem.Color.surfaceRaised)
            .overlay(Capsule().stroke(an ? DesignSystem.Color.accent : DesignSystem.Color.line, lineWidth: 1))
            .frame(width: 46, height: 28)
            .overlay(alignment: an ? .trailing : .leading) {
                Circle()
                    .fill(an ? DesignSystem.Color.text : DesignSystem.Color.textMuted)
                    .frame(width: 20, height: 20)
                    .padding(.horizontal, 4)
            }
            .animation(DesignSystem.Motion.press, value: an)
            .accessibilityHidden(true)
    }
}
