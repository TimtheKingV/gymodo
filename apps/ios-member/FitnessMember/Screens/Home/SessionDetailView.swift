import SwiftUI

/// SessionDetail.dc.html -- die Bloecke und Saetze einer Einheit.
///
/// Ohne eigenen Abruf: getSessions liefert die Bloecke mit, abgeleitet
/// aus den Saetzen und gruppiert nach (Geraet, Uebung). Ein zweiter
/// Durchgang am selben Geraet trifft denselben Block.
///
/// Ohne Vorschlaege: die gehoeren zum Abschluss. Fuer eine selbsttaetig
/// beendete Einheit existiert gar keine Vorschlagszeile (abschluss.ts),
/// ein Abschnitt dafuer bliebe hier bei jeder vergessenen Einheit leer.
///
/// Der Screen zeigt ALLE Teile der angetippten Karte, nicht nur die
/// Einheit hinter der Id: eine Karte, die zwei Einheiten zusammenfasst,
/// darf nicht in ein Detail fuehren, das eine davon verschweigt -- die
/// Saetze der zweiten waeren sonst nirgends zu sehen. Die Teile kommen
/// aus derselben Faltung wie die Liste (`HomeZeilen.karte(fuer:in:)`),
/// damit Liste und Detail gleich gruppieren -- bis auf eine Karte ueber
/// Mitternacht: die Liste faltet je Ortstag, das Detail den ganzen
/// Verlauf, und dort steht dann auch der Teil des Nachbartags.
///
/// Das Zusammenfassen bleibt reine ANZEIGE: die Teile stehen untereinander
/// und behalten ihre eigene Ueberschrift, in den Daten bleiben sie
/// getrennte Sessions -- kein Satz wird umgehaengt.
struct SessionDetailView: View {
    let sessionId: String
    let apiClient: APIClient

    @Environment(VerlaufStore.self) private var verlauf
    @Environment(CatalogStore.self) private var katalog
    @Environment(\.dismiss) private var dismiss

    /// Der Teil, fuer den die Rueckfrage offen ist -- wie
    /// MemberStudiosView.studioPendingLeave.
    @State private var zuLoeschen: SessionSummary?
    @State private var loeschFehler: String?

    private var karte: Trainingskarte? {
        HomeZeilen.karte(fuer: sessionId, in: verlauf.sessions)
    }

    var body: some View {
        ScrollView {
            if let karte {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                    kopf(karte)
                    if let loeschFehler {
                        InlineBanner(tone: .danger, message: loeschFehler)
                    }
                    ForEach(karte.teile) { teil in
                        teilAbschnitt(teil, mitUeberschrift: karte.teile.count > 1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s24)
            } else {
                // Der Verlauf wurde zwischenzeitlich geleert (Abmelden,
                // Kontowechsel). Kein Fehler, kein leerer Screen ohne Wort.
                Text("Diese Einheit steht nicht mehr im Verlauf. Auf Home steht, was gerade geladen ist.")
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .padding(.horizontal, 20)
                    .padding(.top, DesignSystem.Spacing.s48)
            }
        }
        .background(DesignSystem.Color.bg)
        .scrollContentBackground(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Dieses Training löschen?",
            isPresented: Binding(get: { zuLoeschen != nil }, set: { if !$0 { zuLoeschen = nil } }),
            titleVisibility: .visible,
            presenting: zuLoeschen
        ) { teil in
            Button("Löschen", role: .destructive) { Task { await loeschen(teil) } }
            Button("Abbrechen", role: .cancel) {}
        } message: { _ in
            Text("Sätze und Zeit sind danach weg, Wochenzahl und Serie rechnen neu. Das lässt sich nicht rückgängig machen.")
        }
        .testnotizScreen(kontext: ["sessionId": sessionId])
    }

    /// Datum des aeltesten Teils, darunter dieselben zwei Zeilen wie auf
    /// der Karte: wer die Karte antippt, soll oben wiederfinden, was er
    /// angetippt hat, statt eine zweite Rechnung ueber dieselbe Sache.
    private func kopf(_ karte: Trainingskarte) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text(Zeitpunkt.parse(karte.teile[0].startedAt).map(Zahlformat.kurzerWochentagDatum) ?? "")
                .font(DesignSystem.Typography.detailScreentitel)
                .foregroundStyle(DesignSystem.Color.text)

            Text(HomeZeilen.grosseZeile(karte))
                .font(DesignSystem.Typography.wertSekundaer)
                .foregroundStyle(DesignSystem.Color.text)
                .monospacedDigit()

            Text(HomeZeilen.kleineZeile(karte))
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .monospacedDigit()

            if karte.istAutoBeendet { autoBeendetHinweis }
        }
    }

    /// Hier und NICHT auf der Tageskarte auf Home (Testnotiz vom
    /// 19. September, Eintrag 4).
    ///
    /// Die Marke ist richtig, aber sie stand am falschen Ort: auf Home lag
    /// sie vor der kleinen Zeile und war damit das Erste, was an einem
    /// erledigten Training ins Auge fiel -- eine Warnfarbe fuer eine
    /// Nebensaechlichkeit. Wer wissen will, woran er bei einer Einheit
    /// ist, tippt sie an, und genau dort steht die Marke jetzt: mit dem
    /// Satz daneben, der sie erklaert, statt allein und ohne Zusammenhang.
    ///
    /// "Untergrenze", weil `getSessions` das Ende einer selbsttaetig
    /// beendeten Einheit auf den letzten Satz setzt -- siehe
    /// `HomeZeilen.dauerText`, der aus demselben Grund gar keine Dauer
    /// zeigt.
    private var autoBeendetHinweis: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.s8) {
            Text("AUTO BEENDET")
                .font(DesignSystem.Typography.label)
                .foregroundStyle(DesignSystem.Color.warn)
                .padding(.horizontal, DesignSystem.Spacing.s8)
                .padding(.vertical, DesignSystem.Spacing.s4)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.pille)
                        .stroke(DesignSystem.Color.warn, lineWidth: 1))

            Text("Ohne Bestätigung beendet — die Dauer ist eine Untergrenze.")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
        .padding(.top, DesignSystem.Spacing.s4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Auto beendet. Ohne Bestätigung beendet, die Dauer ist eine Untergrenze.")
    }

    /// Die Bloecke eines Teils unter seiner Uhrzeit.
    ///
    /// Die Ueberschrift steht nur bei mehreren Teilen: bei einem einzigen
    /// truege sie nichts bei, was der Kopf nicht schon sagt. Ohne sie hat
    /// der Abschnitt ein einziges Kind -- der Screen sieht dann aus wie
    /// vor dem Zusammenfassen.
    private func teilAbschnitt(_ teil: SessionSummary, mitUeberschrift: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            if mitUeberschrift {
                Text(HomeZeilen.teilUeberschrift(teil).uppercased())
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    // Gemischte Schreibweise fuers Vorlesen: "AB" in
                    // Grossbuchstaben buchstabiert VoiceOver. Als Kopfzeile
                    // springt der Rotor von Teil zu Teil, wie bei den
                    // Wochen-Ueberschriften im Kursplan.
                    .accessibilityLabel(HomeZeilen.teilUeberschrift(teil))
                    .accessibilityAddTraits(.isHeader)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                ForEach(Array(teil.blocks.enumerated()), id: \.offset) { _, block in
                    blockKarte(block)
                }
            }

            // Ein Knopf JE TEIL, nicht je Karte: beim Loeschen eines Teils einer
            // zusammengefassten Karte geht nur dieser Teil, nicht der ganze Tag
            // (Sammelstelle Punkt 19). Umriss in danger, keine Flaeche -- der Screen
            // hat keine Akzentflaeche (designsystem.md SS2).
            DangerOutlineButton(title: mitUeberschrift ? "Diesen Teil löschen" : "Training löschen") {
                zuLoeschen = teil
            }
            .testnotizElement("session.loeschen", typ: "DangerOutlineButton")
        }
    }

    private func blockKarte(_ block: SessionSummary.Block) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            HStack {
                Text("\(block.machineLabel) · \(block.exerciseName)")
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                Spacer()
                Text("\(block.sets.count) \(block.sets.count == 1 ? "SATZ" : "SÄTZE")")
                    .font(DesignSystem.Typography.label)
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }

            ForEach(block.sets, id: \.setIndex) { satz in
                satzZeile(satz)
            }
        }
        .padding(DesignSystem.Spacing.s16)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
    }

    private func satzZeile(_ satz: SessionSummary.Block.Set) -> some View {
        var label = "Satz \(satz.setIndex), \(Zahlformat.gewichtGesprochen(satz.weightKg)), \(Zahlformat.wiederholungenGesprochen(satz.reps))"
        if satz.problemFlag {
            label.append(", Problem gemeldet")
        }

        return HStack(spacing: DesignSystem.Spacing.s12) {
            Text("\(satz.setIndex)")
                .font(DesignSystem.Typography.label)
                .foregroundStyle(DesignSystem.Color.textFaint)
                .frame(width: 16, alignment: .leading)

            Text(Zahlformat.gewichtMitEinheit(satz.weightKg))
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.text)
                .monospacedDigit()

            Text("× \(satz.reps)")
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .monospacedDigit()

            if satz.problemFlag {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(DesignSystem.Color.warn)
            }

            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}

// MARK: - Loeschen

private extension SessionDetailView {
    /// Nicht optimistisch, wie beim Gewicht: erst der Server, dann der
    /// lokale Stand. Misslingt der Aufruf, bleibt der Screen stehen und der
    /// Fehler steht oben, statt eine Einheit verschwinden zu lassen, die
    /// serverseitig noch existiert.
    ///
    /// Danach zurueck: die Karte, ueber die man kam, gibt es so nicht mehr
    /// -- und die Kopfzeile auf Home holt sich Woche und Serie mit dem
    /// Abruf, den `laden` hier anstoesst.
    func loeschen(_ teil: SessionSummary) async {
        loeschFehler = nil
        do throws(APIError) {
            try await apiClient.deleteSession(sessionId: teil.id)
        } catch {
            loeschFehler = error == .offline
                ? "Keine Verbindung. Das Training wurde nicht gelöscht."
                : error.servertext
            return
        }
        if let id = UUID(uuidString: teil.id) { katalog.schreibvorgaengeVerwerfen(sessionId: id) }
        verlauf.einheitEntfernen(id: teil.id)
        Task { await verlauf.laden(studioId: katalog.activeStudioId) }
        dismiss()
    }
}
