import Foundation
import Testing
@testable import FitnessMember

/// Ein ausgepacktes `ProfilWrite` -- die Attrappe speichert diesen
/// Schnappschuss statt `ProfilWrite` selbst: dessen `Feld<T>` ist zwar seit
/// dieser Aufgabe `Sendable` (und darf die Actor-Grenze der Attrappe
/// deshalb ueberqueren), aber nicht `Equatable` -- ein Schnappschuss aus
/// einfachen Werten laesst sich dagegen mit `#expect` vergleichen.
struct ProfilSchreibVersuch: Equatable, Sendable {
    let onboardingDone: Bool?
    let sex: String?
    let ageBand: String?
    let heightCm: Int?
    let trainingGoal: String?
}

private extension ProfilWrite.Feld {
    var wert: T? {
        if case .setzen(let wert) = self { return wert }
        return nil
    }
}

/// Zeichnet die Aufrufe an `ProfilSchreibend` in Reihenfolge auf und kann
/// gezielt einen benannten Aufruf scheitern lassen -- die Attrappe aus
/// Aufgabe 6 (Step 1).
actor FakeProfilSchreibend: ProfilSchreibend {
    private(set) var aufrufe: [String] = []
    private(set) var profilSchreiben: [ProfilSchreibVersuch] = []
    private(set) var messungen: [MesswertWrite] = []
    private(set) var ziele: [ZielWrite] = []
    private var fehlerBei: Set<String> = []

    func lassFehlschlagen(_ aufruf: String) { fehlerBei.insert(aufruf) }
    func lassGelingen(_ aufruf: String) { fehlerBei.remove(aufruf) }

    func updateProfile(_ body: ProfilWrite) async throws(APIError) -> ProfilAntwort {
        aufrufe.append("updateProfile")
        profilSchreiben.append(ProfilSchreibVersuch(
            onboardingDone: body.onboardingDone,
            sex: body.sex?.wert,
            ageBand: body.ageBand?.wert,
            heightCm: body.heightCm?.wert,
            trainingGoal: body.trainingGoal?.wert
        ))
        if fehlerBei.contains("updateProfile") { throw .server(message: "boom") }
        return ProfilAntwort(displayName: nil, sex: nil, ageBand: nil, heightCm: nil, trainingGoal: nil, onboardingCompletedAt: nil)
    }

    func putMeasurement(_ body: MesswertWrite) async throws(APIError) -> MesswertAntwort {
        aufrufe.append("putMeasurement")
        messungen.append(body)
        if fehlerBei.contains("putMeasurement") { throw .server(message: "boom") }
        return MesswertAntwort(measuredOn: body.measuredOn, weightKg: body.weightKg, goalReached: false)
    }

    func setGoal(_ body: ZielWrite) async throws(APIError) -> Ziel {
        let name = "setGoal(\(body.kind))"
        aufrufe.append(name)
        ziele.append(body)
        if fehlerBei.contains(name) { throw .server(message: "boom") }
        return Ziel(id: "z-\(body.kind)", kind: body.kind, targetValue: body.targetValue, createdAt: "2026-01-01")
    }
}

@Suite("OnboardingSchreiber")
struct OnboardingSchreiberTests {
    private var volleAntworten: OnboardingAntworten {
        var antworten = OnboardingAntworten()
        antworten.geschlecht = .weiblich
        antworten.altersspanne = .bis34
        antworten.groesseCm = 170
        antworten.gewichtKg = 65.5
        antworten.richtung = .abnehmen
        antworten.tageProWoche = 4
        antworten.zielgewichtKg = 60.0
        return antworten
    }

    /// Groesse, Gewicht und Wochentage, aber kein "ueber dich" (Geschlecht/
    /// Altersspanne) und keine Richtung -- der Fall aus R19, der die alte,
    /// screen-basierte `offen`-Ableitung zu Fall gebracht hatte: das
    /// Profil-PUT traegt hier NUR die Groesse.
    private var antwortenOhneUeberDichUndZiel: OnboardingAntworten {
        var antworten = OnboardingAntworten()
        antworten.groesseCm = 170
        antworten.gewichtKg = 65.5
        antworten.tageProWoche = 4
        return antworten
    }

    @Test("volle Antworten schreiben in genau dieser Reihenfolge")
    func volleAntwortenReihenfolge() async {
        let fake = FakeProfilSchreibend()
        let ergebnis = await OnboardingSchreiber.schreiben(volleAntworten, mit: fake)
        #expect(ergebnis == .fertig)
        let aufrufe = await fake.aufrufe
        #expect(aufrufe == ["updateProfile", "putMeasurement", "setGoal(weekly_days)", "setGoal(target_weight)"])

        let profilSchreiben = await fake.profilSchreiben
        #expect(profilSchreiben.count == 1)
        #expect(profilSchreiben.first?.onboardingDone == true)
    }

    @Test("leere Antworten schreiben nur onboardingDone, sonst nichts")
    func leereAntworten() async {
        let fake = FakeProfilSchreibend()
        let ergebnis = await OnboardingSchreiber.schreiben(OnboardingAntworten(), mit: fake)
        #expect(ergebnis == .fertig)
        let aufrufe = await fake.aufrufe
        #expect(aufrufe == ["updateProfile"])
        let profilSchreiben = await fake.profilSchreiben
        #expect(profilSchreiben.first?.onboardingDone == true)
    }

    @Test("scheitert die Messung, bleiben Wochenziel und Zielgewicht offen -- das Profil ist schon geschrieben")
    func messungScheitertHaeltRestOffen() async {
        let fake = FakeProfilSchreibend()
        await fake.lassFehlschlagen("putMeasurement")

        let ersterVersuch = await OnboardingSchreiber.schreiben(volleAntworten, mit: fake)
        guard case .teilweise(let offen, _) = ersterVersuch else {
            Issue.record("erwartet .teilweise, bekam \(ersterVersuch)")
            return
        }
        // Reihenfolge wie geschrieben wird: erst die gescheiterte Messung,
        // dann Wochenziel und Zielgewicht -- beide noch nicht einmal
        // versucht, weil beim ersten Fehler abgebrochen wird.
        #expect(offen == [.messwert, .wochenziel, .zielgewicht])

        let aufrufeNachErstemVersuch = await fake.aufrufe
        #expect(aufrufeNachErstemVersuch == ["updateProfile", "putMeasurement"])

        // Ein zweiter Aufruf mit demselben `offen` wiederholt NUR das
        // Offene, in dieser Reihenfolge -- kein zweites `updateProfile`,
        // also auch kein zweites `onboardingDone`.
        await fake.lassGelingen("putMeasurement")
        let zweiterVersuch = await OnboardingSchreiber.schreiben(volleAntworten, mit: fake, offen: offen)
        #expect(zweiterVersuch == .fertig)

        let aufrufeGesamt = await fake.aufrufe
        #expect(aufrufeGesamt == [
            "updateProfile", "putMeasurement",
            "putMeasurement", "setGoal(weekly_days)", "setGoal(target_weight)",
        ])
        let profilSchreiben = await fake.profilSchreiben
        #expect(profilSchreiben.count == 1)
    }

    @Test("scheitert das Profil, wird nichts weiter versucht -- offen enthaelt alles, was eine Antwort hat")
    func profilScheitertStopptAlles() async {
        let fake = FakeProfilSchreibend()
        await fake.lassFehlschlagen("updateProfile")

        let ergebnis = await OnboardingSchreiber.schreiben(volleAntworten, mit: fake)
        guard case .teilweise(let offen, _) = ergebnis else {
            Issue.record("erwartet .teilweise, bekam \(ergebnis)")
            return
        }
        #expect(offen == [.profil, .messwert, .wochenziel, .zielgewicht])
        let aufrufe = await fake.aufrufe
        #expect(aufrufe == ["updateProfile"])
    }

    @Test("scheitert das Profil bei leeren Antworten, enthaelt offen nur das Profil selbst")
    func profilScheitertBeiLeerenAntworten() async {
        let fake = FakeProfilSchreibend()
        await fake.lassFehlschlagen("updateProfile")

        let ergebnis = await OnboardingSchreiber.schreiben(OnboardingAntworten(), mit: fake)
        guard case .teilweise(let offen, _) = ergebnis else {
            Issue.record("erwartet .teilweise, bekam \(ergebnis)")
            return
        }
        #expect(offen == [.profil])

        // Wiederholung schreibt wieder nur das Profil, mit onboardingDone.
        await fake.lassGelingen("updateProfile")
        let zweiterVersuch = await OnboardingSchreiber.schreiben(OnboardingAntworten(), mit: fake, offen: offen)
        #expect(zweiterVersuch == .fertig)
        let aufrufe = await fake.aufrufe
        #expect(aufrufe == ["updateProfile", "updateProfile"])
        let profilSchreiben = await fake.profilSchreiben
        #expect(profilSchreiben.allSatisfy { $0.onboardingDone == true })
    }

    // R19: der Fall, der die alte screen-basierte Ableitung zu Fall
    // gebracht hatte -- Groesse UND Gewicht gesetzt, aber kein "ueber
    // dich" und keine Richtung. `.koerper` als Screen waere hier
    // zweideutig; `.profil`/`.messwert` als Schreibvorgaenge sind es nicht.
    @Test("scheitert das Profil mit Groesse, Gewicht und Wochentagen, bleibt das Profil selbst in offen -- keine Verwechslung mit der Messung")
    func profilScheitertMitGroesseUndGewicht() async {
        let fake = FakeProfilSchreibend()
        await fake.lassFehlschlagen("updateProfile")

        let ergebnis = await OnboardingSchreiber.schreiben(antwortenOhneUeberDichUndZiel, mit: fake)
        guard case .teilweise(let offen, _) = ergebnis else {
            Issue.record("erwartet .teilweise, bekam \(ergebnis)")
            return
        }
        #expect(offen == [.profil, .messwert, .wochenziel])

        // Die Wiederholung schreibt das Profil ZUERST -- mit der Groesse
        // und onboardingDone -- dann erst die Messung und das Wochenziel.
        await fake.lassGelingen("updateProfile")
        let zweiterVersuch = await OnboardingSchreiber.schreiben(antwortenOhneUeberDichUndZiel, mit: fake, offen: offen)
        #expect(zweiterVersuch == .fertig)

        let aufrufe = await fake.aufrufe
        #expect(aufrufe == ["updateProfile", "updateProfile", "putMeasurement", "setGoal(weekly_days)"])
        let profilSchreiben = await fake.profilSchreiben
        #expect(profilSchreiben.count == 2)
        #expect(profilSchreiben.last?.onboardingDone == true)
        #expect(profilSchreiben.last?.heightCm == 170)
    }

    // R21: die Nachholkarte (Aufgabe 8) laeuft nach einem bereits
    // abgeschlossenen Onboarding -- `onboardingDone` darf hier nie
    // (wieder) gesetzt werden, auch wenn alle Stammdaten beantwortet sind.
    @Test("mitAbschluss: false schreibt das Profil ohne onboardingDone, obwohl Stammdaten beantwortet sind")
    func sheetModusOhneAbschlussFlag() async {
        let fake = FakeProfilSchreibend()
        let ergebnis = await OnboardingSchreiber.schreiben(volleAntworten, mit: fake, mitAbschluss: false)
        #expect(ergebnis == .fertig)

        let aufrufe = await fake.aufrufe
        #expect(aufrufe == ["updateProfile", "putMeasurement", "setGoal(weekly_days)", "setGoal(target_weight)"])

        let profilSchreiben = await fake.profilSchreiben
        #expect(profilSchreiben.count == 1)
        // nil, nicht false: die Eigenschaft heisst "nicht gesendet"
        // (siehe ProfilWrite.encode), ein explizites false waere ein
        // zweiter Weg, dasselbe zu sagen.
        #expect(profilSchreiben.first?.onboardingDone == nil)
    }

    // R21: ohne jede Antwort und ohne Abschluss gibt es nichts zu
    // schreiben -- anders als im Wurzel-Modus laeuft `updateProfile` hier
    // NICHT automatisch mit, weil kein `onboardingDone` zu setzen ist.
    @Test("mitAbschluss: false und leere Antworten schreiben gar nichts")
    func sheetModusOhneAbschlussFlagUndLeereAntworten() async {
        let fake = FakeProfilSchreibend()
        let ergebnis = await OnboardingSchreiber.schreiben(OnboardingAntworten(), mit: fake, mitAbschluss: false)
        #expect(ergebnis == .fertig)
        let aufrufe = await fake.aufrufe
        #expect(aufrufe.isEmpty)
    }

    // R21: nur Gewicht beantwortet (kein Stammdatenfeld) -- das Profil-PUT
    // muss aussenvor bleiben, weil es ohne mitAbschluss und ohne eigene
    // Antwort nichts zu sagen haette.
    @Test("mitAbschluss: false ohne Stammdaten, aber mit Gewicht, schreibt nur die Messung")
    func sheetModusOhneAbschlussFlagNurGewicht() async {
        let fake = FakeProfilSchreibend()
        var antworten = OnboardingAntworten()
        antworten.gewichtKg = 82.5
        let ergebnis = await OnboardingSchreiber.schreiben(antworten, mit: fake, mitAbschluss: false)
        #expect(ergebnis == .fertig)
        let aufrufe = await fake.aufrufe
        #expect(aufrufe == ["putMeasurement"])
    }

    @Test("scheitert ein spaeterer Vorgang bei der Wiederholung, schrumpft offen auf ihn und die folgenden")
    func spaetererVorgangScheitertBeiWiederholung() async {
        let fake = FakeProfilSchreibend()
        await fake.lassFehlschlagen("putMeasurement")
        let ersterVersuch = await OnboardingSchreiber.schreiben(volleAntworten, mit: fake)
        guard case .teilweise(let ersteOffen, _) = ersterVersuch else {
            Issue.record("erwartet .teilweise, bekam \(ersterVersuch)")
            return
        }
        #expect(ersteOffen == [.messwert, .wochenziel, .zielgewicht])

        // Messung gelingt jetzt, aber das Wochenziel scheitert neu.
        await fake.lassGelingen("putMeasurement")
        await fake.lassFehlschlagen("setGoal(weekly_days)")
        let zweiterVersuch = await OnboardingSchreiber.schreiben(volleAntworten, mit: fake, offen: ersteOffen)
        guard case .teilweise(let zweiteOffen, _) = zweiterVersuch else {
            Issue.record("erwartet .teilweise, bekam \(zweiterVersuch)")
            return
        }
        #expect(zweiteOffen == [.wochenziel, .zielgewicht])

        let aufrufe = await fake.aufrufe
        #expect(aufrufe == ["updateProfile", "putMeasurement", "putMeasurement", "setGoal(weekly_days)"])
        // Kein zweites Profil-PUT in keinem der beiden Versuche.
        let profilSchreiben = await fake.profilSchreiben
        #expect(profilSchreiben.count == 1)
    }
}
