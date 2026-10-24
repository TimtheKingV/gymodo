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

    private(set) var trainingsprofile: [TrainingsplanProfil] = []
    private(set) var beschwerden: [[String: String]] = []

    func putTrainingProfile(_ profil: TrainingsplanProfil) async throws(APIError) -> TrainingsplanProfil {
        aufrufe.append("putTrainingProfile")
        trainingsprofile.append(profil)
        if fehlerBei.contains("putTrainingProfile") { throw .offline }
        return profil
    }

    func putTrainingLimits(areas: [String: String]) async throws(APIError) {
        aufrufe.append("putTrainingLimits")
        beschwerden.append(areas)
        if fehlerBei.contains("putTrainingLimits") { throw .offline }
    }

    func deleteTrainingLimits() async throws(APIError) {
        aufrufe.append("deleteTrainingLimits")
        if fehlerBei.contains("deleteTrainingLimits") { throw .offline }
    }

    /// Was GET training-limits liefert; nil = 404 (keine Einwilligung).
    private var gespeicherteBeschwerden: [String: String]?
    func setzeGespeicherteBeschwerden(_ areas: [String: String]?) { gespeicherteBeschwerden = areas }

    func trainingLimits() async throws(APIError) -> [String: String]? {
        aufrufe.append("trainingLimits")
        if fehlerBei.contains("trainingLimits") { throw .offline }
        return gespeicherteBeschwerden
    }
}

/// Das Beschwerden-Sheet aus dem Profil (Review Task 10, Runde 2): ohne
/// gelungenen Abruf darf nichts gespeichert werden -- sonst saehe ein
/// gescheiterter Abruf wie "keine Einwilligung" aus, und "Speichern" schloesse
/// das Sheet wie nach einem Widerruf, ohne dass einer passiert ist.
@MainActor
@Suite("BeschwerdenSitzung")
struct BeschwerdenSitzungTests {
    @Test("Abruf scheitert: Speichern unmoeglich, nichts geschrieben; nach Erneut versuchen gilt der gespeicherte Stand, Haken weg sendet DELETE")
    func abrufScheitertDannWiderruf() async {
        let fake = FakeProfilSchreibend()
        await fake.setzeGespeicherteBeschwerden(["knie": "meiden"])
        await fake.lassFehlschlagen("trainingLimits")
        let sitzung = BeschwerdenSitzung(client: fake)

        await sitzung.vorbelegen()
        #expect(sitzung.laden == .fehler(.offline))
        #expect(!sitzung.kannSpeichern)
        #expect(await sitzung.speichern() == false)
        #expect(await fake.aufrufe == ["trainingLimits"])

        await fake.lassGelingen("trainingLimits")
        await sitzung.vorbelegen()
        #expect(sitzung.laden == .geladen)
        #expect(sitzung.plan.einwilligung)
        #expect(sitzung.plan.beschwerden == ["knie": "meiden"])

        // Die ganze Kette wie im Sheet: Haken weg -> Speichern -> DELETE.
        sitzung.plan.einwilligung = false
        #expect(sitzung.kannSpeichern)
        #expect(await sitzung.speichern())
        #expect(await fake.aufrufe == ["trainingLimits", "trainingLimits", "deleteTrainingLimits"])
    }

    @Test("Abruf 404 (keine Einwilligung) ist ein Erfolg: mit Haken und Bereich geht ein PUT raus")
    func keineEinwilligungDannPut() async {
        let fake = FakeProfilSchreibend()
        let sitzung = BeschwerdenSitzung(client: fake)
        await sitzung.vorbelegen()
        #expect(sitzung.laden == .geladen)
        #expect(!sitzung.plan.einwilligung)

        sitzung.plan.setzeStufe("vorsichtig", fuer: "huefte")
        #expect(!sitzung.kannSpeichern)
        sitzung.plan.einwilligung = true
        #expect(await sitzung.speichern())
        #expect(await fake.aufrufe == ["trainingLimits", "putTrainingLimits"])
        #expect(await fake.beschwerden == [["huefte": "vorsichtig"]])
    }

    @Test("Abbrechen sendet nichts -- auch nicht nach einer Aenderung")
    func abbrechenSendetNichts() async {
        let fake = FakeProfilSchreibend()
        await fake.setzeGespeicherteBeschwerden(["knie": "meiden"])
        let sitzung = BeschwerdenSitzung(client: fake)
        await sitzung.vorbelegen()
        sitzung.plan.einwilligung = false
        sitzung.abbrechen()
        #expect(await fake.aufrufe == ["trainingLimits"])
    }

    @Test("scheitert das Speichern, bleibt das Sheet mit Fehler offen")
    func speichernScheitert() async {
        let fake = FakeProfilSchreibend()
        await fake.setzeGespeicherteBeschwerden(["knie": "meiden"])
        await fake.lassFehlschlagen("deleteTrainingLimits")
        let sitzung = BeschwerdenSitzung(client: fake)
        await sitzung.vorbelegen()
        sitzung.plan.einwilligung = false
        #expect(await sitzung.speichern() == false)
        #expect(sitzung.schreibFehler == .offline)
    }
}

/// Der Block "Dein Trainingsplan" (Etappe 3, Task 10): Trainingsprofil und
/// Beschwerden laufen nach den vier Bestandsvorgaengen.
@Suite("OnboardingSchreiber Plan")
struct OnboardingSchreiberPlanTests {
    private var vollerPlan: PlanAntworten {
        var plan = PlanAntworten(profil: nil)
        plan.minuten = 60
        plan.erfahrung = "regelmaessig"
        plan.schwerpunktUmschalten("po")
        return plan
    }

    @Test("Schreiber: Profil-PUT nur mit minuten und erfahrung")
    func profilPutNurMitMinutenUndErfahrung() async {
        var plan = PlanAntworten(profil: nil)
        plan.minuten = 60
        let fake = FakeProfilSchreibend()
        // Sheet-Modus ohne Bestandsantworten: nur der Plan-Block zaehlt.
        let ergebnis = await OnboardingSchreiber.schreiben(OnboardingAntworten(), plan: plan, mit: fake, mitAbschluss: false)
        #expect(ergebnis == .fertig)
        #expect(await fake.aufrufe.isEmpty)

        let fake2 = FakeProfilSchreibend()
        _ = await OnboardingSchreiber.schreiben(OnboardingAntworten(), plan: vollerPlan, mit: fake2, mitAbschluss: false)
        #expect(await fake2.aufrufe == ["putTrainingProfile"])
        #expect(await fake2.trainingsprofile == [TrainingsplanProfil(minutes: 60, experience: "regelmaessig", focus: ["po"])])
    }

    @Test("Wurzel-Modus: Bestand zuerst, dann Trainingsprofil, dann Beschwerden")
    func reihenfolgeMitBestand() async {
        var plan = vollerPlan
        plan.setzeStufe("vorsichtig", fuer: "knie")
        plan.einwilligung = true
        let fake = FakeProfilSchreibend()
        let ergebnis = await OnboardingSchreiber.schreiben(OnboardingAntworten(), plan: plan, mit: fake)
        #expect(ergebnis == .fertig)
        #expect(await fake.aufrufe == ["updateProfile", "putTrainingProfile", "putTrainingLimits"])
        #expect(await fake.beschwerden == [["knie": "vorsichtig"]])
    }

    @Test("Beschwerden ohne Einwilligung gehen nie raus")
    func beschwerdenOhneEinwilligung() async {
        var plan = vollerPlan
        plan.setzeStufe("meiden", fuer: "knie")
        let fake = FakeProfilSchreibend()
        _ = await OnboardingSchreiber.schreiben(OnboardingAntworten(), plan: plan, mit: fake, mitAbschluss: false)
        #expect(await fake.aufrufe == ["putTrainingProfile"])
        #expect(await fake.beschwerden.isEmpty)
    }

    @Test("Widerruf sendet DELETE statt PUT")
    func widerrufSendetDelete() async {
        var plan = vollerPlan
        plan.beschwerdenUebernehmen(["knie": "meiden"])
        plan.einwilligung = false
        let fake = FakeProfilSchreibend()
        _ = await OnboardingSchreiber.schreiben(OnboardingAntworten(), plan: plan, mit: fake, mitAbschluss: false)
        #expect(await fake.aufrufe == ["putTrainingProfile", "deleteTrainingLimits"])
    }

    @Test("scheitert das Trainingsprofil, bleiben Profil und Beschwerden offen")
    func trainingsprofilScheitert() async {
        var plan = vollerPlan
        plan.setzeStufe("meiden", fuer: "knie")
        plan.einwilligung = true
        let fake = FakeProfilSchreibend()
        await fake.lassFehlschlagen("putTrainingProfile")
        let ergebnis = await OnboardingSchreiber.schreiben(OnboardingAntworten(), plan: plan, mit: fake, mitAbschluss: false)
        #expect(ergebnis == .teilweise(offen: [.trainingsprofil, .beschwerden], fehler: .offline))

        // Der zweite Versuch wiederholt nur das Offene.
        await fake.lassGelingen("putTrainingProfile")
        let zweites = await OnboardingSchreiber.schreiben(
            OnboardingAntworten(), plan: plan, mit: fake, mitAbschluss: false, offen: [.trainingsprofil, .beschwerden])
        #expect(zweites == .fertig)
        #expect(await fake.aufrufe == ["putTrainingProfile", "putTrainingProfile", "putTrainingLimits"])
    }

    @Test("nurBeschwerden schreibt nur die Beschwerden, nie das Trainingsprofil")
    func nurBeschwerdenSchreibtNurLimits() async {
        #expect(OnboardingSchreiber.vorgaenge(umfang: .nurBeschwerden) == [.beschwerden])
        #expect(OnboardingSchreiber.vorgaenge(umfang: .nurPlan) == nil)

        var plan = vollerPlan
        plan.beschwerdenUebernehmen(["knie": "meiden"])
        plan.einwilligung = false
        let fake = FakeProfilSchreibend()
        _ = await OnboardingSchreiber.schreiben(
            OnboardingAntworten(), plan: plan, mit: fake, mitAbschluss: false,
            offen: OnboardingSchreiber.vorgaenge(umfang: .nurBeschwerden))
        #expect(await fake.aufrufe == ["deleteTrainingLimits"])
    }

    @Test("ohne Plan-Block (nil) bleibt alles wie vor Etappe 3")
    func ohnePlanBlock() async {
        let fake = FakeProfilSchreibend()
        _ = await OnboardingSchreiber.schreiben(OnboardingAntworten(), mit: fake)
        #expect(await fake.aufrufe == ["updateProfile"])
    }

    @Test("nach einem gelungenen Versuch laufen nur geaenderte Vorgaenge erneut")
    func nurGeaenderteVorgaenge() {
        var antworten = OnboardingAntworten()
        antworten.richtung = .abnehmen
        antworten.tageProWoche = 3
        let plan = vollerPlan

        var spaeter = antworten
        spaeter.tageProWoche = 4
        var spaeterPlan = plan
        spaeterPlan.minuten = 45
        #expect(OnboardingSchreiber.geaenderteVorgaenge(
            vorher: antworten, planVorher: plan, jetzt: spaeter, planJetzt: spaeterPlan
        ) == [.wochenziel, .trainingsprofil, .beschwerden])
        #expect(OnboardingSchreiber.geaenderteVorgaenge(
            vorher: antworten, planVorher: plan, jetzt: antworten, planJetzt: plan
        ) == [.beschwerden])
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

    // MARK: - "Später" nach einem Teilerfolg

    // Spec 5.2: ist das Profil (mit onboardingDone) geschrieben, uebernimmt
    // die Nachholkarte auf Home. "Später" darf dann nicht weiter nur
    // wiederholen -- sonst kommt nicht heraus, wessen Gewicht dauerhaft
    // scheitert.
    @Test("Profil geschrieben, Rest offen: Später beendet ohne neuen Versuch")
    func spaeterBeendetNachGeschriebenemProfil() {
        #expect(OnboardingSchreiber.spaeterBeendet(offen: [.messwert, .wochenziel, .zielgewicht]))
        #expect(OnboardingSchreiber.spaeterBeendet(offen: [.zielgewicht]))
    }

    @Test("Profil noch offen: Später versucht erneut -- nichts ist gespeichert, das Gate kann nicht schliessen")
    func spaeterWiederholtSolangeDasProfilOffenIst() {
        #expect(!OnboardingSchreiber.spaeterBeendet(offen: [.profil]))
        #expect(!OnboardingSchreiber.spaeterBeendet(offen: [.profil, .messwert, .wochenziel]))
    }
}
