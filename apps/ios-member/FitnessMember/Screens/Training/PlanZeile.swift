import SwiftUI
import UIKit

/// Was eine Zeile des Plans zeigt -- unabhaengig davon, wo sie steht
/// (Vorschau im Onboarding 1.4, Plankarte 2.1/2.2 in Task 11). Reine Werte,
/// damit die Ableitung ohne View testbar bleibt.
struct PlanZeilenModell: Equatable, Identifiable {
    /// Der Positionsschluessel (`positionen[].key`).
    let id: String
    let name: String
    /// "3 × 8–12", "20 Min" -- was der Aufrufer darunter zeigt (Task 11
    /// haengt Reserve, "Optional: ..." oder "Heute: ..." an).
    let untertitel: String
    /// Fuer das Uebungsvideo in der Kachel.
    let exerciseId: String
    /// Das Geraetemodell, dessen Foto als Platzhalter unter dem Video steht;
    /// nil = kein Foto (kein aktives Geraet mit dieser Uebung im Studio).
    let vorschaubildModell: String?
    /// Der Ablaufstatus rechts (Plankarte 2.1/2.2); nil = keine Marke, so in
    /// der Vorschau 1.4, wo noch nichts trainiert ist.
    var status: PlanMomentaufnahme.Status? = nil
    /// "Zusätzlich gemacht" (2.2): erledigt mit Haken, aber nicht
    /// durchgestrichen -- die Uebung stand nie auf dem Plan.
    var zusatz = false
}

extension PlanZeilenModell {
    /// Die Zeile einer Planposition, Name und Geraet aus dem Bootstrap.
    /// Das Foto kommt vom Geraet der Position oder, ist es stillgelegt oder
    /// entfernt, von einem anderen aktiven Geraet mit derselben Uebung
    /// (`PlanAnzeige.bildmaschine`).
    static func aus(_ position: TrainingsplanPosition, studioId: String,
                    bootstrap: BootstrapResponse?) -> PlanZeilenModell {
        let maschine = PlanAnzeige.bildmaschine(exerciseId: position.exerciseId, machineId: position.machineId,
                                                studioId: studioId, bootstrap: bootstrap)
        return PlanZeilenModell(
            id: position.key,
            name: uebungsname(exerciseId: position.exerciseId, maschine: maschine, bootstrap: bootstrap),
            untertitel: vorgabe(position),
            exerciseId: position.exerciseId,
            vorschaubildModell: maschine?.equipmentModel.id)
    }

    /// "3 × 8–12" (Entwurf 1.4); Cardio "20 Min"; ohne Wiederholungsbereich
    /// "3 Sätze". Halbgeviertstrich und Malzeichen wie im Entwurf.
    static func vorgabe(_ position: TrainingsplanPosition) -> String {
        if let dauer = position.dauerMin { return "\(dauer) Min" }
        if let von = position.wdhVon, let bis = position.wdhBis {
            return von == bis ? "\(position.saetze) × \(von)" : "\(position.saetze) × \(von)–\(bis)"
        }
        return position.saetze == 1 ? "1 Satz" : "\(position.saetze) Sätze"
    }

    /// Erst das Geraet der Position, dann der Studiokatalog: eine Uebung,
    /// deren Geraet (noch) nicht im Bootstrap steht, behaelt ihren Namen.
    /// Nicht privat: die Plankarte loest Ersatz- und Zusatzuebungen genauso auf.
    static func uebungsname(exerciseId: String, maschine: BootstrapResponse.Machine?,
                                    bootstrap: BootstrapResponse?) -> String {
        if let name = maschine?.exercises.first(where: { $0.id == exerciseId })?.name { return name }
        for maschine in bootstrap?.machines ?? [] {
            if let name = maschine.exercises.first(where: { $0.id == exerciseId })?.name { return name }
        }
        for typ in bootstrap?.catalog?.equipmentTypes ?? [] {
            if let name = typ.exercises.first(where: { $0.id == exerciseId })?.name { return name }
        }
        return "Übung"
    }
}

/// Eine Planzeile: Vorschaubild links (56 x 56, Video ueber dem Geraetefoto
/// wie in der Geraeteliste), Name und Vorgabe, rechts optional die
/// Statusmarke (Entwurf 2.x-Legende). Ohne Status keine Marke -- so in der
/// Vorschau 1.4, wo noch nichts trainiert ist. Der Status kommt aus dem
/// Modell; `status` hier ueberschreibt ihn (Aufrufer von Task 10).
///
/// Kein eigener Hintergrund und keine Trennlinie: der Behaelter (Karte)
/// zeichnet die Linien zwischen den Zeilen, wie `.pos + .pos` im Entwurf.
struct PlanZeile: View {
    let modell: PlanZeilenModell
    var status: PlanMomentaufnahme.Status?
    /// Das dekodierte Geraetefoto (`VorschauLader`), vom Aufrufer geladen --
    /// er kennt die signierten URLs und haelt den Lader ueber die Zeilen.
    var foto: UIImage?

    private var wirksamerStatus: PlanMomentaufnahme.Status? { status ?? modell.status }

    var body: some View {
        let status = wirksamerStatus
        let abgehakt = status == .erledigt && !modell.zusatz
        HStack(spacing: DesignSystem.Spacing.s12) {
            UebungsVideoKachel(exerciseId: modell.exerciseId) {
                PlanZeilenFoto(foto: foto)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(modell.name)
                    .font(.system(size: 16, weight: .bold))
                    // Erledigt durchgestrichen, optional gedaempft (`.pos.dim`
                    // im Entwurf 2.2): beide sind fuer heute nicht mehr noetig,
                    // optional bleibt aber antippbar und lesbar.
                    .foregroundStyle(abgehakt || status == .optional
                                     ? DesignSystem.Color.textMuted : DesignSystem.Color.text)
                    .strikethrough(abgehakt, color: DesignSystem.Color.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
                Text(modell.untertitel)
                    .font(.system(size: 12.5))
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let status {
                PlanStatusMarke(status: status)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.s12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voLabel)
    }

    /// "<Übung>, <Status>, <Vorgabe>" (Task 11, VoiceOver); ohne Status nur
    /// Name und Vorgabe.
    private var voLabel: String {
        guard let status = wirksamerStatus else { return "\(modell.name), \(modell.untertitel)" }
        return "\(modell.name), \(PlanStatusMarke.gesprochen(status)), \(modell.untertitel)"
    }
}

/// Der Platzhalter unter dem Video -- dieselbe Gestalt wie in der
/// Geraeteliste (`GeraeteAuswahlView.foto`): Hantel in `textFaint`, darueber
/// das Foto, sobald es da ist.
private struct PlanZeilenFoto: View {
    let foto: UIImage?

    var body: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
            .fill(DesignSystem.Color.surfaceRaised)
            .frame(width: 56, height: 56)
            .overlay {
                Image(systemName: "dumbbell")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
            .overlay {
                if let foto {
                    Image(uiImage: foto)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
                }
            }
    }
}

/// Die Marke rechts (Legende der Entwuerfe 2.x): offen Kreis, erledigt
/// Haken, optional gestrichelter Kreis, getauscht Doppelpfeil. Grau und weiss, nie
/// Akzent -- die Akzentflaeche des Screens bleibt "Gerät scannen".
struct PlanStatusMarke: View {
    let status: PlanMomentaufnahme.Status

    var body: some View {
        ZStack {
            switch status {
            case .offen:
                Circle().stroke(DesignSystem.Color.textFaint, lineWidth: 1.5)
            case .erledigt:
                Circle().fill(DesignSystem.Color.surfaceRaised)
                Circle().stroke(DesignSystem.Color.text, lineWidth: 1.5)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(DesignSystem.Color.text)
            case .optional:
                Circle().stroke(DesignSystem.Color.textFaint, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                Text("opt")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            case .getauscht:
                Circle().stroke(DesignSystem.Color.textMuted, lineWidth: 1.5)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
        }
        .frame(width: 26, height: 26)
        .accessibilityHidden(true)
    }

    static func gesprochen(_ status: PlanMomentaufnahme.Status) -> String {
        switch status {
        case .offen: "offen"
        case .erledigt: "erledigt"
        case .optional: "optional"
        case .getauscht: "heute getauscht"
        }
    }
}

#Preview {
    let zeilen = [
        PlanZeilenModell(id: "A0", name: "Beinpresse", untertitel: "3 × 8–12", exerciseId: "e1", vorschaubildModell: nil),
        PlanZeilenModell(id: "A1", name: "Rudern an der Maschine", untertitel: "3 × 8–12", exerciseId: "e2", vorschaubildModell: nil),
    ]
    VStack(spacing: 0) {
        PlanZeile(modell: zeilen[0])
        Rectangle().fill(DesignSystem.Color.line).frame(height: 1)
        PlanZeile(modell: zeilen[1], status: .erledigt)
    }
    .padding(.horizontal, 14)
    .background(DesignSystem.Color.surface)
    .padding()
    .background(DesignSystem.Color.bg)
    .environment(UebungsVideoVorrat())
}
