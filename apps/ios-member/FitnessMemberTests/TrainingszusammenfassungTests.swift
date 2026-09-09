import Foundation
import Testing
@testable import FitnessMember

struct TrainingszusammenfassungTests {
    private let start = Date(timeIntervalSince1970: 1_757_000_000)

    private func satz(_ index: Int, _ gewicht: Double, _ minuten: Double,
                      problem: Bool = false) -> LokalerSatz {
        LokalerSatz(id: UUID(), setIndex: index, weightKg: gewicht, reps: 10,
                    rir: nil, problemFlag: problem, problemReason: problem ? .schmerz : nil,
                    performedAt: start.addingTimeInterval(minuten * 60))
    }

    @Test func rechnetDauerVomErstenBisZumLetztenSatz() throws {
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
            LokalerBlock(machineId: "m1", exerciseId: "e1",
                         saetze: [satz(1, 80, 0), satz(2, 80, 47)]),
        ])

        let z = try #require(Trainingszusammenfassung(session))

        #expect(z.dauerMinuten == 47)
        #expect(z.von == start)
        #expect(z.bis == start.addingTimeInterval(47 * 60))
    }

    @Test func zaehltGeraeteUndSaetze() throws {
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
            LokalerBlock(machineId: "m1", exerciseId: "e1",
                         saetze: [satz(1, 80, 0), satz(2, 80, 5), satz(3, 80, 10)]),
            LokalerBlock(machineId: "m2", exerciseId: "e2",
                         saetze: [satz(1, 45, 15)]),
        ])

        let z = try #require(Trainingszusammenfassung(session))

        #expect(z.geraeteAnzahl == 2)
        #expect(z.satzAnzahl == 4)
    }

    @Test func zaehltZweiUebungenAmSelbenGeraetAlsEinGeraet() throws {
        // "3 Geraete" auf dem Artboard meint Geraete, nicht Bloecke.
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
            LokalerBlock(machineId: "m1", exerciseId: "e1", saetze: [satz(1, 80, 0)]),
            LokalerBlock(machineId: "m1", exerciseId: "e2", saetze: [satz(1, 60, 5)]),
        ])

        let z = try #require(Trainingszusammenfassung(session))

        #expect(z.geraeteAnzahl == 1)
        #expect(z.bloecke.count == 2)
    }

    @Test func nenntDasGewichtNurWennAlleSaetzeSichEinigSind() throws {
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
            LokalerBlock(machineId: "m1", exerciseId: "e1",
                         saetze: [satz(1, 80, 0), satz(2, 80, 5)]),
            LokalerBlock(machineId: "m2", exerciseId: "e2",
                         saetze: [satz(1, 45, 10), satz(2, 47.5, 15)]),
        ])

        let z = try #require(Trainingszusammenfassung(session))

        #expect(z.bloecke[0].gewichtKg == 80)
        // Uneinheitlich: lieber keine Zahl als eine falsche.
        #expect(z.bloecke[1].gewichtKg == nil)
    }

    @Test func merktSichEinGemeldetesProblemJeBlock() throws {
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
            LokalerBlock(machineId: "m1", exerciseId: "e1",
                         saetze: [satz(1, 80, 0), satz(2, 80, 5, problem: true)]),
        ])

        let z = try #require(Trainingszusammenfassung(session))

        #expect(z.bloecke[0].problemGemeldet)
    }

    @Test func eineEinheitOhneSaetzeHatKeineZusammenfassung() {
        let leer = LokaleSession(id: UUID(), startedAt: start, bloecke: [])

        #expect(Trainingszusammenfassung(leer) == nil)
    }
}

@MainActor
struct AbgelaufeneSessionTests {
    private let start = Date(timeIntervalSince1970: 1_757_000_000)

    private func store() -> WorkoutSessionStore {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
    }

    @Test func eineLaufendeEinheitGiltNichtAlsAbgelaufen() {
        let sut = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                            rir: nil, problemFlag: false, problemReason: nil, jetzt: start)

        #expect(sut.abgelaufeneSession(jetzt: start.addingTimeInterval(600)) == nil)
    }

    @Test func nachVierStundenGiltSieAlsAbgelaufen() {
        let sut = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                            rir: nil, problemFlag: false, problemReason: nil, jetzt: start)

        #expect(sut.abgelaufeneSession(jetzt: start.addingTimeInterval(4 * 3600 + 1)) != nil)
    }

    @Test func quittierenLaesstSieVerschwinden() {
        let sut = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                            rir: nil, problemFlag: false, problemReason: nil, jetzt: start)
        let spaeter = start.addingTimeInterval(5 * 3600)

        sut.ausgelaufeneQuittieren()

        // Der Satz auf dem leeren Tab steht einmal, nicht fuer immer.
        #expect(sut.abgelaufeneSession(jetzt: spaeter) == nil)
    }

    @Test func eineSpaetereEinheitBekommtIhrenEigenenHinweis() {
        let sut = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                            rir: nil, problemFlag: false, problemReason: nil, jetzt: start)
        sut.ausgelaufeneQuittieren()

        // Ohne "Training beenden" zu druecken: der naechste Satz legt eine
        // neue Einheit an, weit genug hinter der ersten, dass sie eigenstaendig ist.
        let zweiterStart = start.addingTimeInterval(5 * 3600)
        _ = sut.satzSichern(machineId: "m2", exerciseId: "e2", weightKg: 45, reps: 10,
                            rir: nil, problemFlag: false, problemReason: nil, jetzt: zweiterStart)

        #expect(sut.abgelaufeneSession(jetzt: zweiterStart.addingTimeInterval(4 * 3600 + 1)) != nil)
    }

    @Test func einManuellBeendetesTrainingGiltNichtAlsAusgelaufen() {
        let sut = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                            rir: nil, problemFlag: false, problemReason: nil, jetzt: start)
        sut.beenden()

        #expect(sut.abgelaufeneSession(jetzt: start.addingTimeInterval(5 * 3600)) == nil)
    }
}

/// `Trainingszeitraum.kopfzeile` -- die Kopfzeile von TrainingAbschluss.
/// Rein deterministisch: fester Kalender (Europe/Berlin, de_DE), fester
/// `jetzt`, und die Uhrzeit kommt als Stub herein, damit der Test nicht
/// von der Geraetezeitzone abhaengt.
struct TrainingszeitraumTests {
    private var kalender: Calendar {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: "Europe/Berlin")!
        kalender.locale = Locale(identifier: "de_DE")
        return kalender
    }

    private func datum(_ jahr: Int, _ monat: Int, _ tag: Int, _ stunde: Int, _ minute: Int) -> Date {
        var komponenten = DateComponents()
        komponenten.year = jahr
        komponenten.month = monat
        komponenten.day = tag
        komponenten.hour = stunde
        komponenten.minute = minute
        return kalender.date(from: komponenten)!
    }

    /// Der Stub steht fuer Zahlformat.uhrzeit -- hier fest in der
    /// Testzeitzone, damit das Ergebnis nicht vom Simulator abhaengt.
    private func uhrzeit(_ zeitpunkt: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = kalender.timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: zeitpunkt)
    }

    private func kopfzeile(von: Date, bis: Date, jetzt: Date) -> String {
        Trainingszeitraum.kopfzeile(von: von, bis: bis, jetzt: jetzt,
                                    kalender: kalender, uhrzeit: uhrzeit)
    }

    @Test func einTrainingVonHeuteHeisstHeute() {
        let zeile = kopfzeile(
            von: datum(2026, 9, 9, 18, 4), bis: datum(2026, 9, 9, 19, 10),
            jetzt: datum(2026, 9, 9, 19, 12))

        #expect(zeile == "HEUTE · 18:04 – 19:10")
    }

    /// Der Fall aus der Durchsicht: 23:40 bis 00:20. "HEUTE · 23:40 –
    /// 00:20" behauptete eine Einheit von 41 Minuten am selben Tag.
    @Test func einTrainingUeberMitternachtNenntBeideTage() {
        let zeile = kopfzeile(
            von: datum(2026, 9, 8, 23, 40), bis: datum(2026, 9, 9, 0, 20),
            jetzt: datum(2026, 9, 9, 0, 21))

        #expect(zeile == "GESTERN · 23:40 – HEUTE 00:20")
    }

    /// Der Abschluss-Screen kann offen stehen bleiben: liest das Mitglied
    /// ihn am naechsten Tag, darf dort nicht "HEUTE" stehen.
    @Test func einTrainingVonGesternHeisstGestern() {
        let zeile = kopfzeile(
            von: datum(2026, 9, 8, 18, 4), bis: datum(2026, 9, 8, 19, 10),
            jetzt: datum(2026, 9, 9, 8, 0))

        #expect(zeile == "GESTERN · 18:04 – 19:10")
    }

    @Test func einAeltererTerminNenntSeinDatum() {
        let zeile = kopfzeile(
            von: datum(2026, 9, 5, 18, 4), bis: datum(2026, 9, 5, 19, 10),
            jetzt: datum(2026, 9, 9, 8, 0))

        #expect(zeile.hasPrefix("5. SEP"))
        #expect(zeile.hasSuffix("· 18:04 – 19:10"))
    }

    @Test func ueberMitternachtVorGesternNenntBeideDaten() {
        let zeile = kopfzeile(
            von: datum(2026, 9, 5, 23, 40), bis: datum(2026, 9, 6, 0, 20),
            jetzt: datum(2026, 9, 9, 8, 0))

        #expect(zeile.hasPrefix("5. SEP"))
        #expect(zeile.contains("23:40 – 6. SEP"))
        #expect(zeile.hasSuffix("00:20"))
    }

    @Test func tagesbezeichnungUeberEinenMonatswechsel() {
        // 1. Oktober, jetzt ist der 1. Oktober -- "HEUTE" muss auch dann
        // gelten, wenn der Vortag in einem anderen Monat liegt.
        #expect(Trainingszeitraum.tagesbezeichnung(
            datum(2026, 10, 1, 7, 0), jetzt: datum(2026, 10, 1, 20, 0), kalender: kalender) == "HEUTE")
        #expect(Trainingszeitraum.tagesbezeichnung(
            datum(2026, 9, 30, 23, 0), jetzt: datum(2026, 10, 1, 1, 0), kalender: kalender) == "GESTERN")
    }
}

/// `VorschlagsAnzeige.gesprochen` -- fuer VoiceOver blieb bisher eine
/// nackte Zahl ohne den Rahmen, den Sehende aus der Ueberschrift bekommen.
struct VorschlagsAnzeigeGesprochenTests {
    @Test func einPositivesDeltaNenntDasWortVorschlag() {
        #expect(VorschlagsAnzeige.delta(2.5).gesprochen == "Vorschlag plus 2,5 Kilogramm")
    }

    @Test func einNegativesDeltaSprichtMinusStattEinesMinuszeichens() {
        #expect(VorschlagsAnzeige.delta(-2.5).gesprochen == "Vorschlag minus 2,5 Kilogramm")
    }

    @Test func haltenUndKeinerTragenDenRahmenEbenfalls() {
        #expect(VorschlagsAnzeige.halten.gesprochen == "Vorschlag: Gewicht halten")
        #expect(VorschlagsAnzeige.keiner.gesprochen == "Kein Vorschlag")
    }
}
