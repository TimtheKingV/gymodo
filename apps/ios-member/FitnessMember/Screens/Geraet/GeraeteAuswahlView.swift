import SwiftUI

/// „Gerät wählen" -- der Weg zum Geraet ohne Aufkleber (Blatt 02-04).
///
/// Rechnet vollstaendig auf dem Prefetch: kein Netz, kein Ladezustand,
/// keine Fehlerzustaende. Die Regeln stehen in `GeraeteAuswahl`, hier
/// steht nur, wie sie aussehen.
struct GeraeteAuswahlView: View {
    @Environment(CatalogStore.self) private var katalog

    let beiAuswahl: (String) -> Void

    @State private var suchtext = ""
    /// Nur fuer diesen Screen, nicht `katalog.activeStudioId`: sonst
    /// wechselte eine Suche stillschweigend das aktive Studio, und das
    /// Mitglied faende danach auf Home ein anderes vor. Bleibt nil, bis das
    /// Mitglied ueber "Auch in ... suchen" ausdruecklich wechselt --
    /// `aktivesStudioId` unten liefert bis dahin katalog.activeStudioId.
    @State private var studioId: String?
    @FocusState private var feldAktiv: Bool

    /// Abgeleitet statt in `.task` nachtraeglich befuellt: `.task` laeuft
    /// erst NACH dem ersten body-Durchlauf, und der Screen zeigte fuer
    /// diesen einen Frame faelschlich den leeren Zustand ("kein Geraet
    /// eingetragen"), bevor katalog.activeStudioId ankam.
    private var aktivesStudioId: String? {
        studioId ?? katalog.activeStudioId
    }

    var body: some View {
        VStack(spacing: 0) {
            kopf
            suchfeld
            inhalt
        }
        .background(DesignSystem.Color.bg)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Kopf

    private var kopf: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            Text("GERÄT WÄHLEN")
                .font(DesignSystem.Typography.screentitel)
                .tracking(-1)
                .foregroundStyle(DesignSystem.Color.text)
            Text(untertitel)
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, DesignSystem.Spacing.s16)
    }

    private var untertitel: String {
        let anzahl = maschinenImStudio.count
        let name = katalog.bootstrap?.studios.first { $0.id == aktivesStudioId }?.name
        guard let name else { return "Alle \(anzahl) Geräte — auch die ohne Aufkleber." }
        return "Alle \(anzahl) Geräte in \(name) — auch die ohne Aufkleber."
    }

    private var maschinenImStudio: [BootstrapResponse.Machine] {
        katalog.bootstrap?.machines.filter { $0.studioId == aktivesStudioId } ?? []
    }

    // MARK: - Suchfeld

    /// Ein eigenes Feld, nicht `.searchable`: die Systemsuchleiste setzt
    /// sich unter den Navigationstitel, und das Feld gehoert hier in den
    /// Inhalt -- es ist die Hauptaktion des Screens.
    private var suchfeld: some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(feldAktiv ? DesignSystem.Color.accent : DesignSystem.Color.textFaint)
            TextField("", text: $suchtext, prompt: Text("Gerät, Übung oder Platz")
                .foregroundColor(DesignSystem.Color.textFaint))
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Color.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($feldAktiv)
                .submitLabel(.search)
            if !suchtext.isEmpty {
                Button {
                    suchtext = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                .frame(width: 44, height: 44)
                .accessibilityLabel("Suche löschen")
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.s16)
        .frame(height: 52)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                .stroke(feldAktiv ? DesignSystem.Color.accent : DesignSystem.Color.line,
                        lineWidth: feldAktiv ? 1.5 : 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, DesignSystem.Spacing.s16)
    }

    // MARK: - Inhalt

    private var gruppen: GeraeteAuswahl.Gruppen {
        guard let bootstrap = katalog.bootstrap else {
            return GeraeteAuswahl.Gruppen(zuletzt: [], alle: [])
        }
        return GeraeteAuswahl.gruppen(bootstrap: bootstrap, studioId: aktivesStudioId, suchtext: suchtext)
    }

    @ViewBuilder
    private var inhalt: some View {
        let g = gruppen
        if g.zuletzt.isEmpty && g.alle.isEmpty {
            leerZustand
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
                    if !g.zuletzt.isEmpty {
                        gruppe("ZULETZT BEI DIR", g.zuletzt)
                    }
                    if !g.alle.isEmpty {
                        gruppe(suchtext.isEmpty ? "ALLE GERÄTE · A–Z" : "\(g.alle.count) TREFFER", g.alle)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s24)
            }
        }
    }

    private func gruppe(_ titel: String, _ eintraege: [GeraeteAuswahl.Eintrag]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            Text(titel)
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
            ForEach(eintraege) { eintrag in
                if eintrag.gesperrt {
                    zeile(eintrag).opacity(0.55)
                } else {
                    Button { beiAuswahl(eintrag.machineId) } label: { zeile(eintrag) }
                        .buttonStyle(PressButtonStyle())
                }
            }
        }
    }

    private func zeile(_ eintrag: GeraeteAuswahl.Eintrag) -> some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(eintrag.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.text)
                Text(eintrag.ortsangabe)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                if let uebung = eintrag.trefferUebung {
                    Text("Übung · \(uebung)")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                if let zuletzt = eintrag.zuletzt {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(DesignSystem.Color.accent)
                            .frame(width: 5, height: 5)
                            .accessibilityHidden(true)
                        Text(zuletztText(zuletzt))
                            .font(.system(size: 12, weight: .bold).monospacedDigit())
                            .foregroundStyle(DesignSystem.Color.accent)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if eintrag.gesperrt {
                Marke(text: "GESPERRT", farbe: DesignSystem.Color.warn)
            } else if eintrag.nichtScannbar {
                // Nicht "ohne Aufkleber": leere tokenHashes heissen "kein
                // AKTIVER Tag", und ein abgeschalteter klebt weiter am
                // Geraet. Die Marke sagt, was die App weiss.
                Marke(text: "NICHT SCANNBAR", farbe: DesignSystem.Color.textFaint)
            }

            if !eintrag.gesperrt {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
        }
        .padding(DesignSystem.Spacing.s16)
        .frame(minHeight: 64)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func zuletztText(_ zuletzt: GeraeteAuswahl.Zuletzt) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.unitsStyle = .full
        let wann = formatter.localizedString(for: zuletzt.performedAt, relativeTo: .now)
        return "\(wann) · \(Zahlformat.gewichtMitEinheit(zuletzt.gewichtKg))"
    }

    /// Zwei Marken, die es sonst nirgends gibt.
    ///
    /// Bewusst kein `Chip`: der ist absichtlich zweizustaendig (Umriss in
    /// muted oder Akzent) und kennt kein warn. Ihn fuer diesen einen
    /// Screen um einen Ton zu erweitern hiesse, ein geteiltes Bauteil fuer
    /// einen Sonderfall aufzubohren.
    private struct Marke: View {
        let text: String
        let farbe: Color

        var body: some View {
            Text(text)
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.6)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .foregroundStyle(farbe)
                .overlay(Capsule().stroke(farbe.opacity(0.4), lineWidth: 1))
                .fixedSize()
        }
    }

    // MARK: - Leer

    private var leerZustand: some View {
        VStack(spacing: DesignSystem.Spacing.s16) {
            Spacer()
            if suchtext.isEmpty {
                Text("In diesem Studio ist noch kein Gerät eingetragen.")
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .multilineTextAlignment(.center)
            } else {
                Text("Keine Treffer für „\(suchtext)“")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(DesignSystem.Color.text)
                    .multilineTextAlignment(.center)
                Text("Studios benennen Geräte unterschiedlich. Such nach dem Platz — „Fensterreihe“ — oder nach der Übung, die du machen willst.")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                anderesStudio
            }
            Spacer()
            Text("Fehlt das Gerät ganz in der Liste, ist es im Studio noch nicht eingetragen — sag dort einmal Bescheid.")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Color.textFaint)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.bottom, DesignSystem.Spacing.s24)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Nur bei mehr als einem Studio und nur im leeren Zustand: findet die
    /// Suche hier nichts, ist das andere Studio der wahrscheinlichste
    /// Grund. Als Dauerfilter ueber der Liste waere es Laerm.
    @ViewBuilder
    private var anderesStudio: some View {
        if let anderes = katalog.bootstrap?.studios.first(where: { $0.id != aktivesStudioId }) {
            Button { studioId = anderes.id } label: {
                Text("Auch in \(anderes.name) suchen")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.accent)
                    .frame(minHeight: 44)
            }
            .buttonStyle(PressButtonStyle())
        }
    }
}
