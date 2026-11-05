import SwiftUI
import UIKit

/// Entwurf 3.2 "Andere Übung": die Kandidaten des Bausteins, je Zeile
/// Vorschaubild links und "Wählen" rechts, darunter der Schalter
/// "Dauerhaft im Plan ändern". Ohne Schalter tauscht "Wählen" sofort nur
/// fuer heute (auch offline), mit Schalter folgt die Bestaetigung (3.3).
///
/// Keine Akzentflaeche: "Wählen" ist gefuellt weiss, nicht Akzent, und der
/// Schalter hat nur einen Akzent-Umriss.
struct PlanTauschListe: View {
    let sitzung: PlanTauschSitzung
    let bilder: [String: UIImage]
    let beiFertig: () -> Void

    private var auftrag: PlanTauschAuftrag { sitzung.auftrag }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    Text("Statt \(auftrag.name)".uppercased())
                        .font(.system(size: 20, weight: .black))
                        .tracking(-0.4)
                        .foregroundStyle(DesignSystem.Color.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(BausteinName.text(auftrag.position.baustein)), passend zu deinem Studio")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                VStack(spacing: 0) {
                    ForEach(Array(auftrag.kandidaten.enumerated()), id: \.element.id) { index, kandidat in
                        if index > 0 {
                            Rectangle().fill(DesignSystem.Color.line).frame(height: 1)
                        }
                        zeile(kandidat)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 28)
            .padding(.bottom, DesignSystem.Spacing.s16)
        }
        .scrollBounceBehavior(.basedOnSize)
        // Unten fest: der Schalter gilt fuer das naechste "Wählen" und muss
        // auch bei langer Liste vorher zu sehen sein.
        .safeAreaInset(edge: .bottom) {
            // Mit einem Grund (Entfernen) steht die Dauer schon fest.
            if sitzung.grund == nil {
                PlanTauschSchalter(sitzung: sitzung, hinweis: PlanTausch.dauerhaftHinweis(einheitKey: auftrag.einheitKey))
                    .padding(.horizontal, 18)
                    .padding(.vertical, DesignSystem.Spacing.s12)
                    .background(DesignSystem.Color.surface)
                    .overlay(alignment: .top) {
                        Rectangle().fill(DesignSystem.Color.line).frame(height: 1)
                    }
            }
        }
    }

    private func zeile(_ kandidat: TauschKandidat) -> some View {
        let gewaehlt = sitzung.gewaehlt == kandidat
        return Button {
            if sitzung.waehlen(kandidat) { beiFertig() }
        } label: {
            HStack(spacing: DesignSystem.Spacing.s12) {
                UebungsVideoKachel(exerciseId: kandidat.exerciseId) {
                    PlanZeilenFoto(foto: kandidat.vorschaubildModell.flatMap { bilder[$0] })
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(kandidat.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DesignSystem.Color.text)
                        .fixedSize(horizontal: false, vertical: true)
                    if !kandidat.untertitel.isEmpty {
                        Text(kandidat.untertitel)
                            .font(.system(size: 12.5))
                            .foregroundStyle(DesignSystem.Color.textFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                PlanWaehlenChip(an: gewaehlt)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([kandidat.name, kandidat.untertitel].filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityHint(sitzung.dauerhaft ? "Wählen, danach bestätigen" : "Wählen, gilt nur heute")
        .accessibilityAddTraits(gewaehlt ? [.isButton, .isSelected] : .isButton)
    }
}

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
            PlanTauschSchalter(sitzung: sitzung, hinweis: PlanTausch.bestaetigungsHinweis(
                einheitKey: sitzung.auftrag.einheitKey, uebung: kandidat.name))
            if let fehler = sitzung.fehler {
                InlineBanner(tone: .danger, message: PlanTausch.fehlerText(fehler))
            }
            PrimaryButton(title: sitzung.fehler == nil ? "Übernehmen" : "Erneut versuchen",
                          isLoading: sitzung.schreibtGerade) {
                if await sitzung.uebernehmen() { beiFertig() }
            }
            .padding(.top, DesignSystem.Spacing.s4)
            .accessibilityHint("Ändert deinen Plan dauerhaft")
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

/// "Wählen" (Entwurf `.chip`): Umriss, gewaehlt gefuellt weiss -- nie nur
/// ein Umriss als Auswahl, und nie Akzent.
private struct PlanWaehlenChip: View {
    let an: Bool

    var body: some View {
        Text("Wählen")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(an ? DesignSystem.Color.onAccent : DesignSystem.Color.textMuted)
            .padding(.horizontal, DesignSystem.Spacing.s16)
            .frame(minHeight: 44)
            .background(Capsule().fill(an ? DesignSystem.Color.text : .clear))
            .overlay(Capsule().stroke(an ? DesignSystem.Color.text : DesignSystem.Color.line, lineWidth: 1))
            .accessibilityHidden(true)
    }
}
