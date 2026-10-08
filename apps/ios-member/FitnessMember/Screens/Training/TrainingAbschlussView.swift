import SwiftUI

/// Der Abschluss-Screen, Push innerhalb des Training-Tabs
/// (TrainingAbschluss.dc.html) -- die Tab-Leiste bleibt stehen.
///
/// Zwei Geschwindigkeiten: Zeitraum, die drei Zahlen und die Bloecke stehen
/// SOFORT -- sie kommen aus `zusammenfassung`, die beim Druck auf "Training
/// beenden" bereits lokal feststand (TrainingRootView.beenden()). Die
/// Vorschlaege je Block (Blockvorschlag.deltaLoad/reasonCode) kommen erst mit
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
    @Environment(VerlaufStore.self) private var verlauf

    @State private var vorschlaege: [Blockvorschlag]?
    @State private var ausfall: Vorschlagsausfall?
    @State private var verwerfenGefragt = false
    @State private var verwerfenFehler: String?

    /// Warum kein Vorschlag da ist -- getrennt nach Ursache, wie im
    /// Ladepfad der drei Kurse-Screens.
    ///
    /// Vorher stand hier ein blosses `vorschlagFehlt: Bool`, und der
    /// einzige Satz sprach von Empfang. Seit die Serverhaelfte ihre
    /// Abfragefehler nicht mehr verschluckt (m13), kommen sie als 500
    /// hier an -- und der Screen behauptete bei vollem Empfang
    /// "Vorschläge brauchen Empfang". Das ist woertlich M3, auf dem
    /// Screen, den JEDES beendete Training sieht.
    ///
    /// Der Ton bleibt in beiden Faellen derselbe und stimmt weiterhin:
    /// die Saetze sind lokal gesichert und gehen ueber die
    /// Schreib-Warteschlange raus. Nur die Ursache wird nicht mehr
    /// erfunden.
    private enum Vorschlagsausfall: Equatable {
        case ohneEmpfang
        case serverfehler(String)

        var satz: String {
            switch self {
            case .ohneEmpfang:
                "Vorschläge brauchen Empfang. Deine Sätze sind gespeichert und gehen raus, sobald du wieder Netz hast."
            case .serverfehler(let text):
                "\(text) Deine Sätze sind gespeichert — nur der Blick nach vorn fehlt."
            }
        }

        var symbol: String {
            switch self {
            case .ohneEmpfang: "wifi.slash"
            case .serverfehler: "exclamationmark.triangle"
            }
        }
    }

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
            VStack(spacing: DesignSystem.Spacing.s12) {
                if let verwerfenFehler {
                    InlineBanner(tone: .danger, message: verwerfenFehler)
                }
                // Die eine Hauptaktion des Screens, 64pt (designsystem.md SS4).
                // Nie deaktiviert, nie stumm: sie haengt an nichts, was vom Netz
                // kommen koennte -- "Fertig" muss auch dann aus dem Screen
                // herausfuehren, wenn completeSession nie antwortet.
                PrimaryButton(title: "Fertig") { beiFertig() }
                // Die Nebenaktion (Sammelstelle Punkt 19): hier merkt man, dass
                // die Einheit ein Fehlstart war, nicht drei Tage spaeter im
                // Verlauf. Als Text in danger, kein zweiter Umriss neben der
                // Akzentflaeche (designsystem.md SS2). Der Rahmen steht im Label:
                // mit PressButtonStyle ist nur das Label tippbar
                // (GeraetView.problemMelden).
                Button { verwerfenGefragt = true } label: {
                    Text("Training verwerfen")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(DesignSystem.Color.danger)
                .buttonStyle(PressButtonStyle())
                .accessibilityHint("Löscht diese Einheit nach einer Rückfrage")
                .testnotizElement("abschluss.verwerfen", typ: "Button")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, DesignSystem.Spacing.s24)
            .background(DesignSystem.Color.bg)
        }
        .confirmationDialog("Dieses Training verwerfen?", isPresented: $verwerfenGefragt, titleVisibility: .visible) {
            Button("Verwerfen", role: .destructive) { Task { await verwerfen() } }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Sätze und Zeit dieser Einheit sind danach weg. Das lässt sich nicht rückgängig machen.")
        }
        .task {
            // `do throws(APIError)`, damit `error` im catch getippt ist:
            // ohne die Annotation faellt Swift hier auf `any Error`
            // zurueck, und die Fallunterscheidung unten waere nicht
            // moeglich.
            do throws(APIError) {
                vorschlaege = try await apiClient.completeSession(sessionId: sessionId).vorschlaege
            } catch {
                // Kein Fehlerzustand: die Zahlen stehen bereits, nur der
                // Blick nach vorn fehlt. Welcher Satz das sagt, haengt am
                // tatsaechlichen Fehler -- `error` ist hier bereits als
                // APIError getippt (typed throws von completeSession).
                ausfall = error == .offline ? .ohneEmpfang : .serverfehler(error.servertext)
            }
        }
        .testnotizScreen(kontext: ["sessionId": sessionId.uuidString])
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
            } else if let ausfall {
                InlineBanner(tone: .muted, message: ausfall.satz, icon: ausfall.symbol)
            }
            // Solange vorschlaege == nil && ausfall == nil: nichts -- kein
            // Skelett ueber einer Zahl (designsystem.md SS5).
        }
    }

    private func blockZeile(_ zeile: AbschlussZeile) -> some View {
        // Ueber die Station: ein Typ-Block steht nicht in bootstrap.machines.
        let station = katalog.bootstrap?.station(schluessel: zeile.block.stationSchluessel,
                                                 studioId: katalog.activeStudioId)
        let uebung = station?.exercises.first { $0.id == zeile.block.exerciseId }
        let gemeldet = zeile.block.problemGemeldet
        return HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(AbschlussZeile.titel(station: station, uebung: uebung))
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                HStack(spacing: DesignSystem.Spacing.s8) {
                    Text(AbschlussZeile.untertitel(zeile.block))
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
                // Links unter den Zahlen, nicht rechts unter "Kein
                // Vorschlag": dort ist nur Platz fuer ein paar Zeichen
                // (Testnotiz 06.10., #19).
                if let grund = zeile.anzeige.grund {
                    Text(grund)
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .accessibilityHidden(true)
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
            //
            // Die Nebenbelastung steht als eigene, kleinere Zeile unter der
            // Zahl: in einer Zeile brach "+0,5 km/h bei 6,0 %" im Sichtcheck
            // mitten in "6,0 %" um und drueckte den Geraetenamen zusammen.
            VStack(alignment: .trailing, spacing: 2) {
                Text(zeile.anzeige.zahl)
                    .font(.system(size: 19, weight: .black).monospacedDigit())
                    .foregroundStyle(farbe(zeile.anzeige, gemeldet: gemeldet))
                    .multilineTextAlignment(.trailing)
                if let zusatz = zeile.anzeige.zusatz {
                    Text(zusatz)
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .fixedSize()
                }
            }
            .accessibilityElement(children: .ignore)
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
        case .ohne, .keiner: gemeldet ? DesignSystem.Color.warn : DesignSystem.Color.textMuted
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

// MARK: - Verwerfen

extension TrainingAbschlussView {
    /// Erst der Server, dann die Warteschlange, dann der Verlauf -- die
    /// Reihenfolge begruendet EinheitVerwerfen.Weg. Der Fall .nurLokal kommt
    /// ohne Netz aus; der andere sagt bei fehlendem Empfang, was jetzt gilt,
    /// statt eine halbe Einheit stehen zu lassen.
    private func verwerfen() async {
        verwerfenFehler = nil
        let weg = EinheitVerwerfen.weg(
            offeneSchreibvorgaenge: katalog.offeneSchreibvorgaenge(sessionId: sessionId),
            satzAnzahl: zusammenfassung.satzAnzahl)
        if weg == .ueberDenServer {
            do throws(APIError) {
                try await apiClient.deleteSession(sessionId: sessionId.uuidString)
            } catch {
                verwerfenFehler = error == .offline
                    ? "Keine Verbindung. Zum Verwerfen brauchst du Empfang — bis dahin bleibt die Einheit gespeichert."
                    : error.servertext
                return
            }
        }
        katalog.schreibvorgaengeVerwerfen(sessionId: sessionId)
        verlauf.einheitEntfernen(id: sessionId.uuidString)
        // Wie im Session-Detail: einheitEntfernen raeumt nur die Liste, Gesamtzahl,
        // Woche und Serie kommen erst mit dem naechsten Abruf. Home laedt beim
        // Tab-Wechsel nicht neu (HomeRootView), deshalb hier anstossen -- sonst
        // zeigt die Kopfzeile eine gerade verworfene Einheit noch mit.
        Task { await verlauf.laden(studioId: katalog.activeStudioId) }
        beiFertig()
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
    /// Reihenfolge wie im Artboard: erst die Belastung, dann die Satzzahl
    /// ("80,0 kg · 3 Sätze", "8,5 km/h · 6,0 % · 1 Satz"). Fehlt die
    /// Belastung (uneinheitliche Saetze), bleibt die Satzzahl allein
    /// stehen -- und mit ihr die Nebenbelastung weg, die ohne die
    /// Belastung nichts mehr beschreibt.
    static func untertitel(_ block: Blockzeile) -> String {
        let saetze = "\(block.satzAnzahl) \(block.satzAnzahl == 1 ? "Satz" : "Sätze")"
        guard let belastung = block.belastung else { return saetze }
        let werte = Zahlformat.belastungMitNebenbelastung(
            belastung, block.loadUnit, neben: block.nebenbelastung, block.secondaryUnit)
        return "\(werte) · \(saetze)"
    }

    /// "Modell · Uebung"; fehlt die Station im Bootstrap (stillgelegt,
    /// alter Cache), bleibt nur der Rest -- die Blockzeile selbst kennt
    /// keinen Namen.
    static func titel(station: Station?, uebung: BootstrapResponse.Exercise?) -> String {
        [station?.equipmentModel.name, uebung?.name].compactMap { $0 }.joined(separator: " · ")
    }

    static func zeilen(bloecke: [Blockzeile], vorschlaege: [Blockvorschlag]) -> [AbschlussZeile] {
        bloecke.map { block in
            let vorschlag = vorschlaege.first {
                $0.stationSchluessel == block.stationSchluessel && $0.exerciseId == block.exerciseId
            }
            return AbschlussZeile(
                block: block,
                // Die Einheiten des Vorschlags gehen vor: er kommt vom
                // Server und kennt das Modell, wie es jetzt ist.
                anzeige: VorschlagsAnzeige(
                    reasonCode: vorschlag?.reasonCode, deltaLoad: vorschlag?.deltaLoad,
                    loadUnit: vorschlag?.loadUnit ?? block.loadUnit,
                    secondaryLoad: vorschlag?.secondaryLoad,
                    secondaryUnit: vorschlag?.secondaryUnit
                )
            )
        }
    }
}

/// Die Zahl eines Vorschlags mit allem, was es zum Schreiben braucht:
/// Einheit der Belastung und, wenn das Geraet eine hat, die
/// Nebenbelastung, bei der der Vorschlag gilt ("+0,5 km/h bei 6,0 %").
/// Die Nebenbelastung wird nie gesteigert, nur genannt (Cardio-Spec 5.2).
struct Vorschlagsdelta: Equatable {
    let wert: Double
    let einheit: LoadUnit
    let nebenbelastung: Double?
    let nebeneinheit: LoadUnit?

    /// " bei 6,0 %" oder nichts -- an einem Kraftgeraet steht die Zeile
    /// damit Zeichen fuer Zeichen wie vor dem Umbau.
    fileprivate var beiNebenbelastung: (geschrieben: String, gesprochen: String)? {
        guard let nebenbelastung, let nebeneinheit else { return nil }
        return (" bei \(Zahlformat.belastungMitEinheit(nebenbelastung, nebeneinheit))",
                " bei \(Zahlformat.belastungGesprochen(nebenbelastung, nebeneinheit))")
    }
}

/// Die drei sichtbaren Faelle aus dem Aufgabenbrief. Vorschlaege sind eine
/// Rechnung, keine Empfehlung -- der Wortlaut bleibt entsprechend nuechtern
/// ("+2,5 kg", nie "Du solltest").
enum VorschlagsAnzeige: Equatable {
    /// Warum der Server bewusst nichts vorschlaegt -- die vier Codes aus
    /// packages/domain/src/progression.ts, die keine Zahl liefern.
    enum OhneGrund: Equatable {
        case keinVerlauf
        case uneinheitlich
        case problemGemeldet
        case geraetegrenze
    }

    case delta(Vorschlagsdelta)
    /// Mit Einheit, weil das Wort davon abhaengt: "Gewicht halten" an der
    /// Beinpresse, "Tempo halten" am Laufband.
    case halten(LoadUnit)
    /// "Kein Vorschlag" mit dem Grund darunter (Testnotiz 06.10., #19).
    /// Vorher fielen alle vier Codes stumm auf `.keiner` -- "sieben
    /// Formulierungen fuer dieselbe Aussage helfen niemandem" (Aufgabenbrief).
    /// Beim Benutzen half aber auch die eine nicht: sie liess offen, ob die
    /// App etwas falsch gemacht hat. Die Zahl rechts bleibt "Kein
    /// Vorschlag", der Grund steht klein darunter.
    case ohne(OhneGrund)
    /// Kein Vorschlag fuer diesen Block in der Serverantwort, ein
    /// unbekannter Code oder ein Korridor-Code ohne Zahl -- hier gibt es
    /// keinen Grund, den die App ehrlich nennen koennte.
    case keiner

    init(reasonCode: String?, deltaLoad: Double?, loadUnit: LoadUnit,
         secondaryLoad: Double? = nil, secondaryUnit: LoadUnit? = nil) {
        switch reasonCode {
        case "korridor_oben_erreicht", "korridor_unten_verfehlt":
            if let deltaLoad {
                self = .delta(Vorschlagsdelta(wert: deltaLoad, einheit: loadUnit,
                                              nebenbelastung: secondaryLoad, nebeneinheit: secondaryUnit))
            } else {
                self = .keiner
            }
        case "im_korridor":
            self = .halten(loadUnit)
        case "kein_verlauf":
            self = .ohne(.keinVerlauf)
        case "daten_uneindeutig":
            self = .ohne(.uneinheitlich)
        case "problem_gemeldet":
            self = .ohne(.problemGemeldet)
        case "geraetegrenze_erreicht":
            self = .ohne(.geraetegrenze)
        default:
            self = .keiner
        }
    }

    /// Ein Satz, warum es keine Zahl gibt -- nil fuer alles andere.
    var grund: String? {
        guard case .ohne(let grund) = self else { return nil }
        switch grund {
        case .keinVerlauf: return "Noch kein Verlauf an dieser Übung."
        // Die Regel rechnet nur mit einem Gewicht je Tag: eine Pyramide
        // (40, 45, 50 kg) laesst sich nicht eindeutig fortschreiben.
        case .uneinheitlich: return "Das Gewicht wechselte zwischen den Sätzen."
        case .problemGemeldet: return "Du hast ein Problem gemeldet."
        case .geraetegrenze: return "Die Grenze des Geräts ist erreicht."
        }
    }

    /// Was VoiceOver liest. "+2,5 kg" allein spraeche sich als nackte
    /// Zahl ohne Rahmen -- designsystem.md SS10 gibt "Vorschlag +2,5 kg"
    /// vor, und das Wort traegt die Produktgrenze (eine Rechnung, keine
    /// Empfehlung). Eine EINZIGE Zeichenkette, sonst liest VoiceOver
    /// "plus, zwei, Komma, fuenf, k, g" als Einzelteile (SS12, dieselbe
    /// Begruendung wie bei Zahlformat.belastungGesprochen).
    var gesprochen: String {
        switch self {
        case .delta(let delta):
            let richtung = delta.wert >= 0 ? "plus" : "minus"
            let bei = delta.beiNebenbelastung?.gesprochen ?? ""
            return "Vorschlag \(richtung) \(Zahlformat.belastungGesprochen(abs(delta.wert), delta.einheit))\(bei)"
        case .halten(let einheit):
            return "Vorschlag: \(einheit.reglername) halten"
        case .ohne:
            return "Kein Vorschlag. \(grund ?? "")"
        case .keiner:
            return "Kein Vorschlag"
        }
    }

    /// Die grosse Zahl der Zeile: "+0,5 km/h", "Gewicht halten".
    var zahl: String {
        guard case .delta(let delta) = self else { return text }
        return Zahlformat.belastungDelta(delta.wert, delta.einheit)
    }

    /// "bei 6,0 %" unter der Zahl -- nil an jedem Geraet ohne
    /// Nebenbelastung und bei "halten"/"Kein Vorschlag".
    var zusatz: String? {
        guard case .delta(let delta) = self, let bei = delta.beiNebenbelastung else { return nil }
        return bei.geschrieben.trimmingCharacters(in: .whitespaces)
    }

    /// Ueber Zahlformat.belastungDelta -- nie selbst formatiert
    /// (Aufgabenbrief): "+2,5 kg", "−10 W", "+0,5 km/h bei 6,0 %".
    var text: String {
        switch self {
        case .delta(let delta):
            return Zahlformat.belastungDelta(delta.wert, delta.einheit)
                + (delta.beiNebenbelastung?.geschrieben ?? "")
        case .halten(let einheit):
            return "\(einheit.reglername) halten"
        case .ohne, .keiner:
            return "Kein Vorschlag"
        }
    }
}
