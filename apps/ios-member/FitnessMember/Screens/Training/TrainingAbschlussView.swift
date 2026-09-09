import SwiftUI

/// Der Abschluss-Screen, Push innerhalb des Training-Tabs
/// (TrainingAbschluss.dc.html) -- die Tab-Leiste bleibt stehen.
///
/// Zwei Geschwindigkeiten: Zeitraum, die drei Zahlen und die Bloecke stehen
/// SOFORT -- sie kommen aus `zusammenfassung`, die beim Druck auf "Training
/// beenden" bereits lokal feststand (TrainingRootView.beenden()). Die
/// Vorschlaege je Block (Blockvorschlag.deltaKg/reasonCode) kommen erst mit
/// der Antwort von completeSession und treffen SPAETER ein; bis dahin zeigt
/// "Beim naechsten Mal" nichts -- kein Skelett, weil designsystem.md SS5
/// Skelette nur fuer Medien erlaubt, nie ueber einer Zahl, und ein
/// Vorschlag ist eine Zahl.
///
/// Faellt completeSession aus (kein Empfang, Serverfehler), bleiben die
/// Zahlen unveraendert stehen -- sie kamen nie vom Server. Nur der Satz
/// unter "Beim naechsten Mal" sagt, dass der Blick nach vorn fehlt; die
/// Saetze selbst sind laengst lokal gesichert und gehen ueber die
/// Schreib-Warteschlange raus, sobald wieder Netz da ist (designsystem.md
/// SS5: offline heisst "gespeichert, wird gesendet", nie "fehlgeschlagen").
struct TrainingAbschlussView: View {
    let sessionId: UUID
    let zusammenfassung: Trainingszusammenfassung
    let apiClient: APIClient
    let beiFertig: () -> Void

    @Environment(CatalogStore.self) private var katalog

    @State private var vorschlaege: [Blockvorschlag]?
    @State private var vorschlagFehlt = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                kopf
                zahlen
                beimNaechstenMal
            }
            .padding(.horizontal, 20)
            .padding(.top, DesignSystem.Spacing.s24)
            .padding(.bottom, DesignSystem.Spacing.s16)
        }
        .background(DesignSystem.Color.bg)
        .safeAreaInset(edge: .bottom) {
            // Die eine Hauptaktion des Screens, 64pt (designsystem.md SS4).
            // Nie deaktiviert, nie stumm: sie haengt an nichts, was vom
            // Netz kommen koennte -- "Fertig" muss auch dann aus dem
            // Screen herausfuehren, wenn completeSession nie antwortet.
            PrimaryButton(title: "Fertig") { beiFertig() }
                .padding(.horizontal, 20)
                .padding(.bottom, DesignSystem.Spacing.s24)
                .background(DesignSystem.Color.bg)
        }
        .task {
            do {
                vorschlaege = try await apiClient.completeSession(sessionId: sessionId).vorschlaege
            } catch {
                // Kein Fehlerzustand: die Zahlen stehen bereits, nur der
                // Blick nach vorn fehlt. vorschlagsHinweis sagt genau das.
                vorschlagFehlt = true
            }
        }
    }

    // MARK: - Kopf

    private var kopf: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            // Nicht mehr fest "HEUTE": eine Einheit, die um 23:40
            // beginnt und um 00:20 endet, bekaeme sonst eine falsche
            // Aussage ueber das eigene Training (siehe
            // Trainingszeitraum).
            Text(Trainingszeitraum.kopfzeile(
                von: zusammenfassung.von, bis: zusammenfassung.bis,
                jetzt: Date(), kalender: Calendar.current,
                uhrzeit: Zahlformat.uhrzeit))
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
            Text("TRAINING BEENDET")
                .font(DesignSystem.Typography.screentitel)
                .tracking(-1)
                .foregroundStyle(DesignSystem.Color.text)
        }
    }

    // MARK: - Drei Zahlen (sofort aus zusammenfassung)

    private var zahlen: some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            statKarte(wert: zusammenfassung.dauerMinuten, label: "MINUTEN",
                      gesprochen: zusammenfassung.dauerMinuten == 1 ? "1 Minute" : "\(zusammenfassung.dauerMinuten) Minuten")
            statKarte(wert: zusammenfassung.geraeteAnzahl, label: "GERÄTE",
                      gesprochen: zusammenfassung.geraeteAnzahl == 1 ? "1 Gerät" : "\(zusammenfassung.geraeteAnzahl) Geräte")
            statKarte(wert: zusammenfassung.satzAnzahl, label: "SÄTZE",
                      gesprochen: zusammenfassung.satzAnzahl == 1 ? "1 Satz" : "\(zusammenfassung.satzAnzahl) Sätze")
        }
    }

    private func statKarte(wert: Int, label: String, gesprochen: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text("\(wert)")
                .font(.system(size: 27, weight: .black).monospacedDigit())
                .foregroundStyle(DesignSystem.Color.text)
            Text(label)
                .font(DesignSystem.Typography.label)
                .tracking(1)
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
        .padding(DesignSystem.Spacing.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
        // clipShape VOR overlay: umgekehrt schneidet die Maske die
        // aeussere Haelfte der Kontur weg und laesst eine halbe uebrig
        // (Vorlage: InlineBanner).
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(gesprochen)
    }

    // MARK: - Beim naechsten Mal (kommt spaeter, aus dem Netz)

    @ViewBuilder
    private var beimNaechstenMal: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text("BEIM NÄCHSTEN MAL")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)

            if let vorschlaege {
                // Abweichung vom Artboard: dort EIN Kartenkoerper mit
                // 1px-Trennlinien zwischen den Zeilen. Eigene Karten je
                // Zeile, wie auf TrainingLaeuft -- der Aufgabenbrief
                // verlangt woertlich, dass die Problemmeldung "aussieht wie
                // auf TrainingLaeuft, nicht anders", und dort traegt jeder
                // Block seine eigene Kontur (warn bei gemeldet, sonst line).
                VStack(spacing: DesignSystem.Spacing.s12) {
                    ForEach(AbschlussZeile.zeilen(bloecke: zusammenfassung.bloecke, vorschlaege: vorschlaege)) { zeile in
                        blockZeile(zeile)
                    }
                }
                produktgrenzeHinweis
            } else if vorschlagFehlt {
                InlineBanner(
                    tone: .muted,
                    message: "Vorschläge brauchen Empfang. Deine Sätze sind gespeichert und gehen raus, sobald du wieder Netz hast."
                )
            }
            // Solange vorschlaege == nil && !vorschlagFehlt: nichts -- kein
            // Skelett ueber einer Zahl (designsystem.md SS5).
        }
    }

    private func blockZeile(_ zeile: AbschlussZeile) -> some View {
        let maschine = katalog.bootstrap?.machines.first { $0.id == zeile.block.machineId }
        let uebung = maschine?.exercises.first { $0.id == zeile.block.exerciseId }
        let gemeldet = zeile.block.problemGemeldet
        return HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text([maschine?.equipmentModel.name, uebung?.name]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                HStack(spacing: DesignSystem.Spacing.s8) {
                    // Reihenfolge wie im Artboard: erst das Gewicht,
                    // dann die Satzzahl ("80,0 kg · 3 Sätze"). Fehlt das
                    // Gewicht (uneinheitliche Saetze), bleibt die
                    // Satzzahl allein stehen.
                    Text((zeile.block.gewichtKg.map { "\(Zahlformat.gewichtMitEinheit($0)) · " } ?? "")
                         + "\(zeile.block.satzAnzahl) \(zeile.block.satzAnzahl == 1 ? "Satz" : "Sätze")")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                    if gemeldet {
                        // Umriss, nie Flaeche -- dieselbe Form wie auf
                        // TrainingLaeuft (designsystem.md SS2).
                        Label("gemeldet", systemImage: "exclamationmark.triangle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignSystem.Color.warn)
                    }
                }
            }
            Spacer()
            // Abweichung vom Artboard: dort accent (#D4FF3F) fuer das
            // Delta. Die eine Akzentflaeche dieses Screens ist "Fertig"
            // (designsystem.md SS2, Aufgabenbrief "Global Constraints").
            // Sehende bekommen den Rahmen aus der Ueberschrift "BEIM
            // NÄCHSTEN MAL" und dem Produktgrenze-Satz darunter; fuer
            // VoiceOver blieb eine nackte Zahl. "Vorschlaege sind eine
            // Rechnung, keine Empfehlung" ist bindend -- das Wort gehoert
            // also auch in die gesprochene Fassung (designsystem.md SS10).
            Text(zeile.anzeige.text)
                .font(.system(size: 19, weight: .black).monospacedDigit())
                .foregroundStyle(farbe(zeile.anzeige, gemeldet: gemeldet))
                .multilineTextAlignment(.trailing)
                .accessibilityLabel(zeile.anzeige.gesprochen)
        }
        .padding(DesignSystem.Spacing.s16)
        .frame(minHeight: 44)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        // clipShape VOR overlay: umgekehrt schneidet die Maske die
        // aeussere Haelfte der Kontur weg und laesst eine halbe uebrig
        // (Vorlage: InlineBanner).
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(gemeldet ? DesignSystem.Color.warn : DesignSystem.Color.line,
                        lineWidth: gemeldet ? 1.5 : 1)
        )
        .accessibilityElement(children: .combine)
    }

    /// warn faerbt nur "Kein Vorschlag" bei einer gemeldeten Zeile ein --
    /// nie das Delta oder "Gewicht halten": warn markiert eine Rueckmeldung
    /// des Mitglieds, keine Rechnung (designsystem.md SS2).
    private func farbe(_ anzeige: VorschlagsAnzeige, gemeldet: Bool) -> SwiftUI.Color {
        switch anzeige {
        case .delta: DesignSystem.Color.text
        case .halten: DesignSystem.Color.textMuted
        case .keiner: gemeldet ? DesignSystem.Color.warn : DesignSystem.Color.textMuted
        }
    }

    /// Woertlich aus dem Aufgabenbrief: Vorschlaege sind eine Rechnung,
    /// keine Empfehlung.
    private var produktgrenzeHinweis: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.s8) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
            Text("Vorschläge entstehen aus deiner Historie und dem Zielkorridor deines Studios. Sie sind eine Rechnung, keine Empfehlung — du entscheidest.")
                .font(.system(size: 12))
                .lineSpacing(3)
        }
        .foregroundStyle(DesignSystem.Color.textMuted)
        .padding(.top, DesignSystem.Spacing.s4)
    }
}

// MARK: - Reine Ableitung: Bloecke + Vorschlaege

/// Wie eine Blockzeile aus "Beim naechsten Mal" zusammen mit ihrem
/// passenden Vorschlag angezeigt wird. Reine Ableitung ohne Netz oder
/// View -- deshalb ohne Simulator testbar (siehe
/// TrainingAbschlussZeilenTests).
struct AbschlussZeile: Equatable, Identifiable {
    var id: String { block.id }
    let block: Blockzeile
    let anzeige: VorschlagsAnzeige

    /// Ordnet jeder Blockzeile aus der Zusammenfassung ihren Vorschlag ueber
    /// (machineId, exerciseId) zu. Die Reihenfolge folgt IMMER `bloecke`
    /// (der lokalen, sofort verfuegbaren Liste), nicht der -- moeglicherweise
    /// anders sortierten oder unvollstaendigen -- Serverantwort: fehlt ein
    /// Vorschlag fuer einen Block, zeigt die Zeile trotzdem "Kein
    /// Vorschlag" statt zu verschwinden.
    static func zeilen(bloecke: [Blockzeile], vorschlaege: [Blockvorschlag]) -> [AbschlussZeile] {
        bloecke.map { block in
            let vorschlag = vorschlaege.first {
                $0.machineId == block.machineId && $0.exerciseId == block.exerciseId
            }
            return AbschlussZeile(
                block: block,
                anzeige: VorschlagsAnzeige(reasonCode: vorschlag?.reasonCode, deltaKg: vorschlag?.deltaKg)
            )
        }
    }
}

/// Die drei sichtbaren Faelle aus dem Aufgabenbrief. Vorschlaege sind eine
/// Rechnung, keine Empfehlung -- der Wortlaut bleibt entsprechend nuechtern
/// ("+2,5 kg", nie "Du solltest").
enum VorschlagsAnzeige: Equatable {
    case delta(Double)
    case halten
    case keiner

    /// `reasonCode` fehlt (kein Vorschlag fuer diesen Block in der
    /// Serverantwort) oder ist einer der vier uebrigen Codes
    /// (`kein_verlauf`, `daten_uneindeutig`, `geraetegrenze_erreicht`,
    /// `problem_gemeldet`) -- alle fallen auf "Kein Vorschlag", weil sieben
    /// Formulierungen fuer dieselbe Aussage niemandem helfen
    /// (Aufgabenbrief).
    init(reasonCode: String?, deltaKg: Double?) {
        switch reasonCode {
        case "korridor_oben_erreicht", "korridor_unten_verfehlt":
            if let deltaKg { self = .delta(deltaKg) } else { self = .keiner }
        case "im_korridor":
            self = .halten
        default:
            self = .keiner
        }
    }

    /// Was VoiceOver liest. "+2,5 kg" allein spraeche sich als nackte
    /// Zahl ohne Rahmen -- designsystem.md SS10 gibt "Vorschlag +2,5 kg"
    /// vor, und das Wort traegt die Produktgrenze (eine Rechnung, keine
    /// Empfehlung). Eine EINZIGE Zeichenkette, sonst liest VoiceOver
    /// "plus, zwei, Komma, fuenf, k, g" als Einzelteile (SS12, dieselbe
    /// Begruendung wie bei Zahlformat.gewichtGesprochen).
    var gesprochen: String {
        switch self {
        case .delta(let kg):
            let richtung = kg >= 0 ? "plus" : "minus"
            return "Vorschlag \(richtung) \(Zahlformat.gewichtGesprochen(abs(kg)))"
        case .halten:
            return "Vorschlag: Gewicht halten"
        case .keiner:
            return "Kein Vorschlag"
        }
    }

    /// Ueber Zahlformat.gewicht, mit Vorzeichen -- nie selbst formatiert
    /// (Aufgabenbrief). Negative Deltas tragen ihr Minuszeichen schon aus
    /// dem Formatter, positive bekommen es hier dazu.
    var text: String {
        switch self {
        case .delta(let kg):
            let vorzeichen = kg >= 0 ? "+" : ""
            return vorzeichen + Zahlformat.gewichtMitEinheit(kg)
        case .halten:
            return "Gewicht halten"
        case .keiner:
            return "Kein Vorschlag"
        }
    }
}
