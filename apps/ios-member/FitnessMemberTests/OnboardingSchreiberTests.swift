import Foundation
import Testing
@testable import FitnessMember

/// Ein ausgepacktes `ProfilWrite` -- die Attrappe speichert diesen
/// Schnappschuss statt `ProfilWrite` selbst: dessen `Feld<T>` traegt kein
/// `Sendable` (nur `Encodable`, siehe ProfilWrite.swift) und duerfte die
/// Actor-Grenze der Attrappe deshalb gar nicht ueberqueren.
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
        // Reihenfolge wie geschrieben wird: erst Koerper (die gescheiterte
        // Messung), dann Wochenziel, dann Zielgewicht -- beide noch nicht
        // einmal versucht, weil beim ersten Fehler abgebrochen wird.
        #expect(offen == [.koerper, .wieOft, .zielgewicht])

        let aufrufeNachErstemVersuch = await fake.aufrufe
        #expect(aufrufeNachErstemVersuch == ["updateProfile", "putMeasurement"])

        // Ein zweiter Aufruf mit demselben `offen` wiederholt nur das
        // Offene -- kein zweites `onboardingDone`.
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

    @Test("scheitert das Profil, wird nichts weiter versucht -- offen enthaelt alles")
    func profilScheitertStopptAlles() async {
        let fake = FakeProfilSchreibend()
        await fake.lassFehlschlagen("updateProfile")

        let ergebnis = await OnboardingSchreiber.schreiben(volleAntworten, mit: fake)
        guard case .teilweise(let offen, _) = ergebnis else {
            Issue.record("erwartet .teilweise, bekam \(ergebnis)")
            return
        }
        #expect(offen == [.ueberDich, .koerper, .ziel, .wieOft, .zielgewicht])
        let aufrufe = await fake.aufrufe
        #expect(aufrufe == ["updateProfile"])
    }
}
