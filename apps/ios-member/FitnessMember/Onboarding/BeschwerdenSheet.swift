import SwiftUI

/// Der Ablauf hinter der Profilzeile "Beschwerden" (Schritt 1.3 allein,
/// `OnboardingUmfang.nurBeschwerden`) -- als eigener Typ ohne View, damit
/// die Kette Abruf -> Aendern -> Speichern mit einer Attrappe pruefbar ist.
///
/// Anders als im Onboarding-Flow MUSS der Abruf gelingen, bevor gespeichert
/// werden darf: ein gescheiterter Abruf saehe sonst aus wie "keine
/// Einwilligung" (Haken leer), "Speichern" sendete nichts und schloesse das
/// Sheet wie nach einem Widerruf -- ohne dass der Server davon weiss
/// (DSGVO Art. 7 Abs. 3, Review Task 10 Runde 2). 404 ist dagegen ein
/// Erfolg: dann gibt es wirklich keine Einwilligung.
@MainActor
@Observable
final class BeschwerdenSitzung {
    enum Laden: Equatable {
        case laedt, geladen
        case fehler(APIError)
    }

    private(set) var laden: Laden = .laedt
    var plan = PlanAntworten(profil: nil)
    private(set) var schreibFehler: APIError?
    private(set) var schreibtGerade = false

    @ObservationIgnored private let client: any ProfilSchreibend

    init(client: any ProfilSchreibend) {
        self.client = client
    }

    func vorbelegen() async {
        laden = .laedt
        do throws(APIError) {
            let areas = try await client.trainingLimits()
            var neu = PlanAntworten(profil: nil)
            neu.beschwerdenUebernehmen(areas)
            plan = neu
            laden = .geladen
        } catch {
            laden = .fehler(error)
        }
    }

    var kannSpeichern: Bool {
        laden == .geladen && !schreibtGerade && plan.kannWeiter(.planBeschwerden)
    }

    /// `true` = geschrieben (oder nichts zu schreiben), das Sheet darf zu.
    func speichern() async -> Bool {
        guard laden == .geladen, plan.kannWeiter(.planBeschwerden) else { return false }
        schreibtGerade = true
        defer { schreibtGerade = false }
        let ergebnis = await OnboardingSchreiber.schreiben(
            OnboardingAntworten(), plan: plan, mit: client, mitAbschluss: false,
            offen: OnboardingSchreiber.vorgaenge(umfang: .nurBeschwerden))
        switch ergebnis {
        case .fertig:
            plan.beschwerdenGeschrieben()
            schreibFehler = nil
            return true
        case .teilweise(_, let fehler):
            schreibFehler = fehler
            return false
        }
    }

    /// Sendet nichts; der gespeicherte Stand bleibt, wie er ist.
    func abbrechen() {
        plan.beschwerdenVerwerfen()
    }
}

/// Die Ansicht dazu: dieselbe Huelle und derselbe Schritt wie im
/// Onboarding, nur mit Ladezustand und "Speichern"/"Abbrechen". Solange der
/// Abruf laeuft oder gescheitert ist, steht der Schritt gar nicht da -- ein
/// leerer Haken waere eine Aussage, die niemand geprueft hat.
struct BeschwerdenSheet: View {
    let beiFertig: () -> Void
    @State private var sitzung: BeschwerdenSitzung

    init(apiClient: APIClient, beiFertig: @escaping () -> Void) {
        self.init(sitzung: BeschwerdenSitzung(client: apiClient), beiFertig: beiFertig)
    }

    /// Fuer Vorschau und Sichtpruefung mit einer Attrappe.
    init(sitzung: BeschwerdenSitzung, beiFertig: @escaping () -> Void) {
        self.beiFertig = beiFertig
        _sitzung = State(initialValue: sitzung)
    }

    private var ladefehler: APIError? {
        if case .fehler(let fehler) = sitzung.laden { fehler } else { nil }
    }

    var body: some View {
        OnboardingScreen(
            schrittNummer: 1,
            gesamtSchritte: 1,
            titel: "Was sollen wir schonen?",
            lead: "Freiwillig. Wir lassen dann Übungen weg, die den Bereich stark belasten, oder wählen schonendere.",
            fussnote: nil,
            primaryTitle: ladefehler != nil || sitzung.schreibFehler != nil ? "Erneut versuchen" : "Speichern",
            primaryEnabled: ladefehler != nil || sitzung.kannSpeichern,
            primaryLoading: sitzung.laden == .laedt || sitzung.schreibtGerade,
            primaryDisabledHint: sitzung.laden == .geladen && !sitzung.plan.kannWeiter(.planBeschwerden)
                ? "Erst die Einwilligung bestätigen — oder abbrechen." : nil,
            spaeterEnabled: !sitzung.schreibtGerade,
            bereich: "Dein Trainingsplan",
            spaeterTitel: "Abbrechen",
            beiSpaeter: {
                sitzung.abbrechen()
                beiFertig()
            },
            beiWeiter: {
                if ladefehler != nil {
                    await sitzung.vorbelegen()
                } else if await sitzung.speichern() {
                    beiFertig()
                }
            }
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                if let ladefehler {
                    InlineBanner(tone: .danger, message: OnboardingHinweis.beschwerdenLadefehler(ladefehler))
                } else if let schreibFehler = sitzung.schreibFehler {
                    InlineBanner(tone: .danger, message: OnboardingHinweis.hinweis(
                        offen: [.beschwerden], fehler: schreibFehler, mitBestand: false))
                }
                switch sitzung.laden {
                case .geladen:
                    PlanBeschwerdenSchritt(plan: $sitzung.plan)
                case .laedt:
                    ProgressView()
                        .tint(DesignSystem.Color.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .accessibilityLabel("Deine Angaben werden geladen")
                case .fehler:
                    EmptyView()
                }
            }
        }
        .task { await sitzung.vorbelegen() }
    }
}
