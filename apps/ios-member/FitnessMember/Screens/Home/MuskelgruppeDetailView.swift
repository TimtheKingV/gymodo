import SwiftUI

/// Detail einer Muskelgruppe (Entwurf C): Figur mit nur dieser Gruppe,
/// Gesamtfortschritt und Status, ein ruhiger Hinweis, wenn ein Teilmuskel
/// zu kurz kommt, darunter die Teilmuskeln.
///
/// Kein Button "Passende Übungen ansehen": die Uebungsliste nach Muskel
/// gibt es nur am Geraet, Home hat keinen Einstieg dorthin.
struct MuskelgruppeDetailView: View {
    let gruppe: MuskelHauptgruppe
    let auswertung: MuskelAuswertung
    /// Muskelschluessel -> Name aus dem Katalog.
    let namen: [String: String]
    let geschlecht: Geschlecht?

    private var h: Haeufigkeit { auswertung.haeufigkeit }

    /// Fuer Schluessel, die der Katalog (noch) nicht nennt.
    nonisolated static let vorgabeNamen: [String: String] = [
        "pectorals": "Brust", "serratus_anterior": "Vorderer Sägemuskel",
        "lats": "Latissimus", "upper_back": "Oberer Rücken", "erectors": "Rückenstrecker",
        "deltoid_anterior": "Vordere Schulter", "deltoid_lateral": "Seitliche Schulter",
        "deltoid_posterior": "Hintere Schulter", "rotator_cuff": "Rotatorenmanschette",
        "biceps": "Bizeps", "triceps": "Trizeps", "forearms": "Unterarme",
        "quads": "Oberschenkel vorne", "hamstrings": "Oberschenkel hinten", "glutes": "Gesäß",
        "adductors": "Oberschenkel innen", "abductors": "Seitliche Hüfte", "calves": "Waden",
        "tibialis": "Schienbeinmuskel", "fibularis": "Wadenbeinmuskel",
        "abs": "Gerader Bauchmuskel", "obliques": "Seitliche Bauchmuskeln",
    ]

    private var alleNamen: [String: String] {
        Self.vorgabeNamen.merging(namen) { _, katalog in katalog }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                Text(gruppe.titel)
                    .font(DesignSystem.Typography.detailScreentitel)
                    .foregroundStyle(DesignSystem.Color.text)
                    .accessibilityAddTraits(.isHeader)
                kopf
                if h.istAuswertbar, let hinweis = MuskelHinweise.gruppenhinweis(gruppe: gruppe, in: h, namen: alleNamen) {
                    hinweisKarte(hinweis)
                }
                if !h.istAuswertbar {
                    Text(MuskelHinweise.startsatz(h))
                        .font(DesignSystem.Typography.fliesstext)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                muskelListe
            }
            .padding(.horizontal, 20)
            .padding(.vertical, DesignSystem.Spacing.s24)
        }
        .background(DesignSystem.Color.bg)
        .scrollContentBackground(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .testnotizScreen()
    }

    // MARK: Kopf

    private var figur: some View {
        MuskelFigur(
            farben: MuskelFarben.farben(gruppe: gruppe, h: h, nurGruppe: true),
            geschlecht: geschlecht,
            ansichten: gruppe.detailAnsichten)
    }

    @ViewBuilder private var kopf: some View {
        MuskelKartenRahmen {
            if gruppe.detailAnsichten.count == 1 {
                HStack(alignment: .center, spacing: DesignSystem.Spacing.s16) {
                    figur.frame(maxWidth: 150)
                    gesamt
                    Spacer(minLength: 0)
                }
            } else {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                    figur
                    gesamt
                }
            }
        }
    }

    private var gesamt: some View {
        let wert = MuskelFortschritt.anzeige(auswertung.fortschritt.jeGruppe[gruppe])
        let status = Ausgewogenheit.status(gruppe: gruppe, in: h)
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            MuskelKartenTitel(text: "Gesamtfortschritt")
            FortschrittsText(wert: wert, font: .system(size: 40, weight: .black))
            Text("Höchstlast, 3 Monate")
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textFaint)
            if let chip = MuskelStatusText.chip(status) {
                statusChip(chip, status: status)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Gesamtfortschritt \(FortschrittsText.gesprochen(wert)), \(MuskelStatusText.gesprochen(status))")
    }

    private func statusChip(_ text: String, status: MuskelStatus) -> some View {
        HStack(spacing: 6) {
            Circle().fill(MuskelFarben.farbe(status)).frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.text)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 28)
        .background(DesignSystem.Color.surfaceRaised)
        .clipShape(Capsule())
    }

    private func hinweisKarte(_ text: String) -> some View {
        MuskelKartenRahmen {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                MuskelKartenTitel(text: "Hinweis")
                Text(text)
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Teilmuskeln

    private var muskelListe: some View {
        let schluessel = gruppe.muskelSchluessel
        let groesste = schluessel.filter { !Ausgewogenheit.seltene.contains($0) }
            .map { h.jeMuskel[$0] ?? 0 }.max() ?? 0
        return MuskelKartenRahmen(innen: 0) {
            VStack(spacing: 0) {
                ForEach(Array(schluessel.enumerated()), id: \.element) { index, muskel in
                    if index > 0 {
                        Rectangle().fill(DesignSystem.Color.line).frame(height: 1)
                    }
                    muskelZeile(muskel, groesste: groesste)
                }
            }
        }
    }

    private func muskelZeile(_ muskel: String, groesste: Int) -> some View {
        let name = alleNamen[muskel] ?? muskel
        let wert = MuskelFortschritt.anzeige(auswertung.fortschritt.jeMuskel[muskel])
        let status = Ausgewogenheit.status(muskel: muskel, gruppe: gruppe, in: h)
        let selten = Ausgewogenheit.seltene.contains(muskel)
        let brauchtTrainings = FortschrittsText.brauchtTrainings(wert, auswertbar: h.istAuswertbar, selten: selten)
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.s12) {
                Text(name)
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.text)
                Spacer(minLength: DesignSystem.Spacing.s8)
                if brauchtTrainings {
                    FortschrittsText.BrauchtTrainings()
                }
                FortschrittsText(wert: wert, font: .system(size: 15, weight: .bold))
            }
            if selten {
                Text("kaum Übungen")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            } else if h.istAuswertbar {
                HaeufigkeitsBalken(
                    anteil: MuskelgruppenUebersichtView.anteil(h.jeMuskel[muskel] ?? 0, von: groesste),
                    status: status,
                    zaehl: h.jeMuskel[muskel] ?? 0)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.s16)
        .padding(.vertical, DesignSystem.Spacing.s12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(name), Fortschritt \(FortschrittsText.gesprochen(wert))\(brauchtTrainings ? ", \(FortschrittsText.brauchtTrainingsText)" : ""), \(MuskelStatusText.gesprochen(selten ? .kaumUebungen : status))")
    }
}

#Preview("Detail Rücken, mit Daten") {
    NavigationStack {
        MuskelgruppeDetailView(gruppe: .ruecken, auswertung: MuskelVorschau.gefuellt, namen: [:], geschlecht: .maennlich)
    }
}

#Preview("Detail Beine, mit Daten") {
    NavigationStack {
        MuskelgruppeDetailView(gruppe: .beine, auswertung: MuskelVorschau.gefuellt, namen: [:], geschlecht: .weiblich)
    }
}

#Preview("Detail Rücken, zu wenig Training") {
    NavigationStack {
        MuskelgruppeDetailView(gruppe: .ruecken, auswertung: MuskelVorschau.leer, namen: [:], geschlecht: .maennlich)
    }
}
