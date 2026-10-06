import Foundation
import Testing
@testable import FitnessMember

/// Nur die Ableitungen werden geprueft -- reine SwiftUI-Views werden laut
/// Spec Abschnitt 10 manuell gegen die Artboards abgenommen.
@MainActor
struct GeraetModelTests {
    private func modell(
        maschine: BootstrapResponse.Machine,
        bootstrap: BootstrapResponse,
        sessions: WorkoutSessionStore? = nil,
        loader: FakeGeraetLoader = FakeGeraetLoader(),
        enqueue: @escaping (PendingSetWrite) -> Void = { _ in },
        satzZiel: Int = Einstellungen.satzZielVorgabe,
        mitschnitt: (any SatzMitschnitt)? = nil
    ) -> GeraetModel {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return GeraetModel(
            maschine: maschine,
            uebungId: maschine.exercises.first?.id ?? "e1",
            token: nil,
            bootstrap: bootstrap,
            loader: loader,
            sessions: sessions ?? WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis)),
            enqueue: enqueue,
            satzZiel: { satzZiel },
            mitschnitt: mitschnitt
        )
    }

    @Test func startetOhneHistorieAmGeraeteminimum() {
        // designsystem.md SS8: "Beim ersten Mal schlaegt gymodo kein Gewicht
        // vor. Das Rad startet am Geraetminimum."
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [])
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)

        #expect(sut.belastung == 5.0)
        #expect(sut.vorschlagText == nil)
    }

    @Test func uebernimmtDenLetztenEigenenWertOhneNetz() {
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)])
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)

        #expect(sut.belastung == 77.5)
        #expect(sut.umfang == 11)
        #expect(sut.rueckblick?.zuletzt == "77,5 kg × 11")
    }

    @Test func rastetEinenVorschlagAufDieSchrittweite() {
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)])
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)

        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0))

        #expect(sut.belastung == 80.0)
        #expect(sut.vorschlagText == "Vorschlag · +2,5 kg")
    }

    @Test func kontextUebernehmenUebernimmtDenVorschlagOhneBerührungDesRades() {
        // Unangetastet: kontextLaden() kann jederzeit nach dem initialen
        // Rendern eintreffen -- ohne eigene Eingabe des Mitglieds soll der
        // Vorschlag ganz normal greifen (Review-Fund I2, "unberuehrt").
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)])
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)

        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0))

        #expect(sut.belastung == 80.0)
    }

    @Test func kontextUebernehmenLaesstEinenSelbstGewaehltenWertInRuhe() {
        // Ein spaet eintreffender tagContext darf den Wert nicht mehr unter
        // dem Daumen ersetzen, sobald das Mitglied am Rad gedreht hat
        // (Review-Fund I2). belastungGewaehlt(_:) ist der einzige Weg dahin --
        // seit die Raeder immer offen sind, gibt es kein "Oeffnen" mehr, an
        // dem man es festmachen koennte.
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)])
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)
        sut.belastungGewaehlt(75.0)

        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0))

        #expect(sut.belastung == 75.0)
        // Der Vorschlag selbst bleibt sichtbar -- nur die Uebernahme in
        // belastung unterbleibt.
        #expect(sut.vorschlagText == "Vorschlag · +2,5 kg")
    }

    @Test func uebungWechselnGibtDenWertWiederFrei() {
        // Neue Uebung, neuer Wert: die Markierung "vom Mitglied gewaehlt" gilt
        // fuer die alte Uebung. Ein Vorschlag, der danach eintrifft, darf
        // wieder greifen -- sonst bliebe das Rad fuer e2 auf dem Wert von e1.
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        sut.belastungGewaehlt(75.0)

        sut.uebungWechseln(zu: "e2")
        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0))

        #expect(sut.belastung == 80.0)
    }

    @Test func meldetDenAnschlagNurWennEsEinenGibt() {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(sut.anschlagText == "Maximum des Geräts erreicht")

        let ohneGrenze = modell(maschine: GeraetTestdaten.maschineOhneMaximum,
                                bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(ohneGrenze.anschlagText == nil)
    }

    @Test func einstellwerteTragenDieBeschriftungAuchOhneNetz() {
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [], mitKalibrierung: true)
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)

        #expect(sut.einstellwerte.first?.label == "Sitzposition")
        #expect(sut.einstellwerte.first?.anzeige == "4")
    }

    @Test func hatEinstellparameterFolgtDenDefinitionenDesModells() {
        let mit = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        let ohne = modell(maschine: GeraetTestdaten.maschineOhneEinstellparameter,
                          bootstrap: GeraetTestdaten.bootstrap(lastSets: []))

        #expect(mit.hatEinstellparameter == true)
        #expect(ohne.hatEinstellparameter == false)
    }

    @Test func ohneEinstellparameterBleibenDieEinstellwerteLeer() {
        // GeraetView haengt die Zeile mit "aendern" an nicht leere
        // Einstellwerte. Ohne Definitionen gibt es nichts zu beschriften --
        // auch dann nicht, wenn bootstrap zu diesem Geraet noch Werte traegt
        // (etwa aus einer Zeit, in der das Modell Parameter hatte). Sonst
        // fuehrte "aendern" in einen Schritt, den es nicht mehr gibt.
        let sut = modell(maschine: GeraetTestdaten.maschineOhneEinstellparameter,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: [], mitKalibrierung: true))

        #expect(sut.einstellwerte.isEmpty)
    }

    @Test func satzNummerZaehltImBlock() async {
        // Jeder Satz geht durch die Warteschlange, immer -- ein geloeschter
        // enqueue-Aufruf muss hier auffallen, nicht nur satzNummer/phase
        // (designsystem.md Konstante "gespeichert, wird gesendet").
        let erfasser = Erfassungswarteschlange()
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         sessions: sessions,
                         enqueue: { erfasser.geschriebene.append($0) })
        #expect(sut.satzNummer == 1)

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        #expect(sut.satzNummer == 2)
        #expect(sut.laufendePause != nil)

        let laufendeSession = sessions.aktiveSession()
        let gespeicherterSatz = laufendeSession?.bloecke.first?.saetze.first
        #expect(erfasser.geschriebene.count == 1)
        #expect(erfasser.geschriebene.first?.sessionId == laufendeSession?.id)
        #expect(erfasser.geschriebene.first?.setId == gespeicherterSatz?.id)
        #expect(erfasser.geschriebene.first?.body.load == sut.belastung)
        #expect(erfasser.geschriebene.first?.body.volume == sut.umfang)
        // Die Gegenprobe aus Spec Abschnitt 9: ein Kraftsatz traegt keine
        // Nebenbelastung -- der Server wiese ihn sonst ab.
        #expect(erfasser.geschriebene.first?.body.secondaryLoad == nil)
        #expect(laufendeSession?.bloecke.first?.einheiten == .kilogrammWiederholungen)
    }

    // MARK: - Phasen

    @Test func vorDemLetztenGeplantenSatzStartetDiePause() async {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         satzZiel: 3)

        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(sut.laufendePause != nil)
        #expect(sut.phase != .abschluss)

        sut.pauseBeenden()
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(sut.laufendePause != nil)
    }

    @Test func nachDemLetztenGeplantenSatzKommtKeinePauseSondernDieEntscheidung() async {
        // Eine Pause vor einem Satz, der nicht mehr kommt, ist nur
        // Wartezeit -- an ihrer Stelle steht die Frage "noch einer, oder
        // fertig hier?".
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         sessions: sessions,
                         satzZiel: 3)

        await sut.satzSichern(problemFlag: false, problemReason: nil)
        sut.pauseBeenden()
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        sut.pauseBeenden()
        #expect(sut.satzNummer == 3)

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        #expect(sut.phase == .abschluss)
        #expect(sut.laufendePause == nil)
    }

    @Test func weitererSatzStartetEineNeuePause() async {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         satzZiel: 1)

        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(sut.phase == .abschluss)

        sut.weitererSatz()
        #expect(sut.laufendePause != nil)
    }

    @Test func pauseBeendenSchaltetZurueckAufDieEingabe() async {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         satzZiel: 3)

        await sut.satzSichern(problemFlag: false, problemReason: nil)
        sut.pauseBeenden()

        #expect(sut.phase == .eingabe)
        #expect(sut.laufendePause == nil)
    }

    @Test func verlaengernSchiebtNurDasEndeUndNurInDerPause() async {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         satzZiel: 3)

        // Ausserhalb der Pause ist "+30 s" wirkungslos statt zustandsbildend.
        sut.pauseVerlaengern()
        #expect(sut.phase == .eingabe)

        await sut.satzSichern(problemFlag: false, problemReason: nil)
        let vorher = sut.laufendePause
        sut.pauseVerlaengern()

        #expect(sut.laufendePause?.start == vorher?.start)
        #expect(sut.laufendePause?.endetAm == vorher?.endetAm.addingTimeInterval(30))
    }

    @Test func uebungWechselnSetztDiePhaseZurueck() async {
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         satzZiel: 1)

        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(sut.phase == .abschluss)

        // e2 hat eigene Saetze und ein eigenes Ziel -- die Entscheidung von
        // e1 gilt dort nicht.
        sut.uebungWechseln(zu: "e2")
        #expect(sut.phase == .eingabe)
    }

    @Test func satzSichernSchreibtKeineReserveMehr() async {
        let erfasser = Erfassungswarteschlange()
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         enqueue: { erfasser.geschriebene.append($0) })

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        #expect(erfasser.geschriebene.first?.body.rir == nil)
    }

    @Test func gesicherteSaetzeSteigtNurBeimSichernNichtBeimUebungswechsel() async {
        // Review-Fund Task 9: satzNummer ist die Satznummer der GERADE
        // ANGEZEIGTEN Uebung. Hat die Zielübung schon mehr gesicherte
        // Saetze als die aktuelle, springt satzNummer beim blossen
        // uebungWechseln(zu:) nach oben, ohne dass ein Satz gesichert
        // wurde -- ein an satzNummer haengender Haptik-Trigger feuerte
        // dann bei einer Navigation. gesicherteSaetze darf das nicht.
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        // e2 hat schon zwei gesicherte Saetze -- mehr, als e1 unten nach
        // dem einen gesicherten Satz haben wird.
        _ = sessions.satzSichern(machineId: "m1", exerciseId: "e2",
                                  einheiten: .kilogrammWiederholungen, load: 40, volume: 10,
                                  problemFlag: false, problemReason: nil)
        _ = sessions.satzSichern(machineId: "m1", exerciseId: "e2",
                                  einheiten: .kilogrammWiederholungen, load: 40, volume: 10,
                                  problemFlag: false, problemReason: nil)
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         sessions: sessions)
        #expect(sut.gesicherteSaetze == 0)

        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(sut.gesicherteSaetze == 1)
        #expect(sut.satzNummer == 2)

        sut.uebungWechseln(zu: "e2")
        // satzNummer springt (e2 hatte schon zwei Saetze) -- das ist der
        // Fehler, den der alte Trigger nicht kannte. gesicherteSaetze
        // bleibt unberuehrt.
        #expect(sut.satzNummer == 3)
        #expect(sut.gesicherteSaetze == 1)

        sut.uebungWechseln(zu: "e1")
        #expect(sut.gesicherteSaetze == 1)
    }

    @Test func verwirftKalibrierungUndVorschlagDerVorherigenUebungBeimWechsel() {
        // tag-context.ts berechnet calibration und suggestion serverseitig
        // fuer genau eine Uebung (selectedExerciseId). Nach einem Wechsel
        // muessen Einstellwerte wieder aus bootstrap fuer die NEUE Uebung
        // kommen und der Vorschlag verschwinden -- sonst zeigt der Screen
        // die Sitzposition der vorherigen Uebung unter dem falschen Namen,
        // und das Mitglied stellt das Geraet physisch falsch ein.
        let bootstrap = GeraetTestdaten.bootstrap(
            lastSets: [], mitKalibrierung: true,
            kalibrierungExerciseId: "e2", kalibrierungSitzWert: 6
        )
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen, bootstrap: bootstrap)

        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0, kalibrierungSitzWert: 4))
        #expect(sut.einstellwerte.first?.anzeige == "4")
        #expect(sut.vorschlagText != nil)

        sut.uebungWechseln(zu: "e2")

        #expect(sut.vorschlagText == nil)
        #expect(sut.einstellwerte.first?.anzeige == "6")
    }

    @Test func kalibrierungVorbereitenLiestDurchDenselbenUebungsgateWieKalibrierungswerte() {
        // Dieselbe Klammer wie kalibrierungswerte: der Entwurf muss aus der
        // Kalibrierung der AKTUELLEN Uebung entstehen, nicht aus e1, auch
        // wenn der geladene Kontext (falls vorhanden) noch zu e1 gehoert.
        let bootstrap = GeraetTestdaten.bootstrap(
            lastSets: [], mitKalibrierung: true,
            kalibrierungExerciseId: "e2", kalibrierungSitzWert: 6
        )
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen, bootstrap: bootstrap)
        sut.uebungWechseln(zu: "e2")

        sut.kalibrierungVorbereiten()

        #expect(sut.entwurfEinstellung["sitz"] == 6)
        #expect(sut.kalibrierungFehler == nil)
    }

    @Test func kalibrierungVorbereitenFaelltOhneVorherigeWerteAufsMinimum() {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))

        sut.kalibrierungVorbereiten()

        #expect(sut.entwurfEinstellung["sitz"] == 1)
    }

    @Test func kalibrierungSichernSpeichertUndSchliesst() async {
        let loader = FakeGeraetLoader()
        await loader.setCalibration(.success(RecordedCalibration(
            id: "c1", machineId: "m1", exerciseId: "e1",
            settingValues: .number(4), schemaVersion: 1, source: "self",
            createdAt: "2026-09-01T10:00:00Z"
        )))
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), loader: loader)
        sut.kalibrierungOeffnen()
        sut.entwurfEinstellung = ["sitz": 4]

        let ergebnis = await sut.kalibrierungSichern()

        #expect(ergebnis == true)
        #expect(sut.kalibrierungFehler == nil)
        #expect(sut.kalibrierungOffen == false)
    }

    @Test func kalibrierungSichernZeigtDenServertextWoertlichUndSchliesstNicht() async {
        // Der Text kommt vom Server -- nur er kennt die Grenzen des
        // Geraetemodells. Er wird hier NICHT umformuliert.
        let loader = FakeGeraetLoader()
        await loader.setCalibration(.failure(.validation(message: "Sitz darf höchstens 8 sein.")))
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), loader: loader)
        sut.kalibrierungOeffnen()
        sut.entwurfEinstellung = ["sitz": 99]

        let ergebnis = await sut.kalibrierungSichern()

        #expect(ergebnis == false)
        #expect(sut.kalibrierungFehler == "Sitz darf höchstens 8 sein.")
        #expect(sut.kalibrierungOffen == true)
    }

    // MARK: - Auswahl-Einstellungen (Testnotiz 06.10., #17)

    @Test func kalibrierungVorbereitenBelegtEineAuswahlMitDemErstenErlaubtenWert() {
        let sut = modell(maschine: GeraetTestdaten.maschineMitAuswahl,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))

        sut.kalibrierungVorbereiten()

        #expect(sut.entwurfAuswahl["griff"] == "eng")
        // Eine Auswahl ist keine Zahl -- sie darf im Zahlenentwurf nicht
        // auftauchen, sonst ginge sie als 0 an den Server.
        #expect(sut.entwurfEinstellung["griff"] == nil)
        #expect(sut.entwurfEinstellung["hoehe"] == 1)
        #expect(sut.entwurfEinstellung["sitz"] == 1)
    }

    @Test func kalibrierungVorbereitenUebernimmtDieBisherigeAuswahl() {
        let sut = modell(maschine: GeraetTestdaten.maschineMitAuswahl,
                         bootstrap: GeraetTestdaten.bootstrapMitAuswahl(griff: "weit"))

        sut.kalibrierungVorbereiten()

        #expect(sut.entwurfAuswahl["griff"] == "weit")
        #expect(sut.entwurfEinstellung["hoehe"] == 7)
        #expect(sut.entwurfEinstellung["sitz"] == 3)
    }

    @Test func kalibrierungVorbereitenVerwirftEineNichtMehrErlaubteAuswahl() {
        // Das Studio hat die Werteliste seither geaendert -- ein alter Wert
        // ausserhalb der Liste wuerde am Server abgewiesen.
        let sut = modell(maschine: GeraetTestdaten.maschineMitAuswahl,
                         bootstrap: GeraetTestdaten.bootstrapMitAuswahl(griff: "breit"))

        sut.kalibrierungVorbereiten()

        #expect(sut.entwurfAuswahl["griff"] == "eng")
    }

    @Test func kalibrierungSichernSendetEineAuswahlAlsText() async {
        let loader = FakeGeraetLoader()
        await loader.setCalibration(.success(RecordedCalibration(
            id: "c1", machineId: "m1", exerciseId: "e1",
            settingValues: .null, schemaVersion: 1, source: "self",
            createdAt: "2026-10-06T10:00:00Z"
        )))
        let sut = modell(maschine: GeraetTestdaten.maschineMitAuswahl,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), loader: loader)
        sut.kalibrierungVorbereiten()
        sut.entwurfAuswahl["griff"] = "neutral"
        sut.entwurfEinstellung["hoehe"] = 12

        let ergebnis = await sut.kalibrierungSichern()

        #expect(ergebnis == true)
        let gesendet = await loader.kalibrierungen.last?.settingValues
        #expect(gesendet == ["hoehe": .number(12), "griff": .string("neutral"), "sitz": .number(1)])
    }

    // MARK: - Uebung abschliessen (Testnotiz 06.10., #12)

    @Test func uebungAbschliessenFragtNurBeiMehrerenUebungenNach() {
        // Antwort auf die Rueckfrage: der Drawer "Weitere Uebung / Geraet
        // abschliessen" kommt immer, sobald das Geraet mehr als eine Uebung
        // hat -- auch wenn alle schon dran waren.
        let eine = modell(maschine: GeraetTestdaten.maschine,
                          bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(eine.abschlussFragtNach == false)
        let zwei = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen,
                          bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(zwei.abschlussFragtNach == true)
    }

    @Test func blockInEinheitNenntDieSaetzeJederUebungDiesesGeraets() {
        // Die Uebungsliste zeigt bei schon gemachten Uebungen die Saetze der
        // laufenden Einheit, wie die Blockliste im Training-Tab.
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), sessions: sessions)
        _ = sessions.satzSichern(machineId: "m1", exerciseId: "e1",
                                  einheiten: .kilogrammWiederholungen, load: 40, volume: 10,
                                  problemFlag: false, problemReason: nil)
        _ = sessions.satzSichern(machineId: "m1", exerciseId: "e1",
                                  einheiten: .kilogrammWiederholungen, load: 42.5, volume: 9,
                                  problemFlag: false, problemReason: nil)
        // Derselbe Uebungs-Schluessel an einem anderen Geraet zaehlt nicht.
        _ = sessions.satzSichern(machineId: "m2", exerciseId: "e2",
                                  einheiten: .kilogrammWiederholungen, load: 20, volume: 12,
                                  problemFlag: false, problemReason: nil)

        #expect(sut.blockInEinheit(fuer: "e1")?.saetze.count == 2)
        #expect(sut.blockInEinheit(fuer: "e2") == nil)
    }

    @Test func erstkontaktLaeuftGenauEinmalJeGeraetUndUebung() {
        // "Der Dreischritt laeuft genau einmal je Geraet und Uebung" --
        // erstkontaktAbschliessen() ist die einzige Stelle, die istErstkontakt
        // fuer die AKTUELLE Uebung nach einem abgeschlossenen Dreischritt
        // korrigiert (Task 16, Step 3 der Aufgabe).
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(sut.istErstkontakt == true)

        sut.erstkontaktAbschliessen()

        #expect(sut.istErstkontakt == false)

        // Der Fluchtweg (ErstkontaktFlow.beiAbbruch, in GeraetScreen auf
        // beiZurueckZumTraining verdrahtet) ruft erstkontaktAbschliessen()
        // NIE auf -- sonst zeigte istErstkontakt beim naechsten Scan
        // faelschlich "erledigt", obwohl das Mitglied den Dreischritt nie zu
        // Ende gebracht hat. Ein frisches Modell im selben Ausgangszustand,
        // ohne den Aufruf, steht dafuer: istErstkontakt bleibt wahr.
        let abgebrochen = modell(maschine: GeraetTestdaten.maschine,
                                 bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(abgebrochen.istErstkontakt == true)
    }

    @Test func istErstkontaktBleibtNachRueckkehrZumGeraetFalschTrotzStalemBootstrap() {
        // Der Zirkelfall aus M1-Spec SS5.3 (Schlusswellen-Fund C2, Faelle 1):
        // Dreischritt an Maschine 7 abgeschlossen, Saetze gemacht, zu einem
        // anderen Geraet gewechselt und ueber die Blockliste zurueck --
        // TrainingRootView.modell(...) baut dabei ein FRISCHES GeraetModel.
        // bootstrap bleibt dabei die alte Momentaufnahme ohne Kalibrierung
        // und ohne lastSet; nur die lokale Session weiss vom Satz.
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [])

        let erstesModell = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap, sessions: sessions)
        #expect(erstesModell.istErstkontakt == true)
        erstesModell.erstkontaktAbschliessen()
        _ = sessions.satzSichern(machineId: "m1", exerciseId: "e1",
                                  einheiten: .kilogrammWiederholungen, load: 40, volume: 10,
                                  problemFlag: false, problemReason: nil)

        // Ein neuer Push: dieselbe sessions-Instanz, aber ein komplett neues
        // GeraetModel -- erledigt der ersten Instanz ist damit weg, nur
        // sessions kennt noch den Satz.
        let zweitesModell = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap, sessions: sessions)
        #expect(zweitesModell.istErstkontakt == false)
    }

    @Test func istErstkontaktGiltFuerEineNieBenutzteUebungAuchNachDemWechsel() {
        // Faelle 2 desselben Funds: uebungWechseln(zu:) darf den Dreischritt
        // einer noch nie benutzten Uebung nicht ueberspringen, nur weil eine
        // ANDERE Uebung am selben Geraet ihn schon hinter sich hat.
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [])
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen, bootstrap: bootstrap, sessions: sessions)
        #expect(sut.istErstkontakt == true)

        sut.erstkontaktAbschliessen()
        _ = sessions.satzSichern(machineId: "m1", exerciseId: "e1",
                                  einheiten: .kilogrammWiederholungen, load: 40, volume: 10,
                                  problemFlag: false, problemReason: nil)
        #expect(sut.istErstkontakt == false)

        sut.uebungWechseln(zu: "e2")

        #expect(sut.istErstkontakt == true)
    }

    @Test func kalibrierungSichernZeigtEinenEigenenTextOffline() async {
        let loader = FakeGeraetLoader()
        await loader.setCalibration(.failure(.offline))
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), loader: loader)
        sut.entwurfEinstellung = ["sitz": 4]

        let ergebnis = await sut.kalibrierungSichern()

        #expect(ergebnis == false)
        #expect(sut.kalibrierungFehler?.contains("Ohne Empfang") == true)
    }

    // MARK: - Rueckblick (Sammelstelle Punkt 11)

    @Test func rueckblickTraegtDenLetztenSatzUndSpaeterDenVorschlag() {
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)])
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)
        // Offline gibt es nur den letzten Satz; der Vorschlag kommt mit dem Kontext.
        #expect(sut.rueckblick == Rueckblick(zuletzt: "77,5 kg × 11", vorschlag: nil))

        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0))

        #expect(sut.rueckblick == Rueckblick(zuletzt: "77,5 kg × 11", vorschlag: "Vorschlag · +2,5 kg"))
    }

    @Test func beimErstenMalAmGeraetGibtEsKeinenRueckblick() {
        // Ohne letzten Satz und ohne Vorschlag haette der Drawer nichts zu
        // sagen -- er kommt gar nicht (Sammelstelle Punkt 11).
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(sut.rueckblick == nil)
        #expect(sut.rueckblickFaellig == false)

        sut.geraetGeoeffnet()

        #expect(sut.rueckblickOffen == false)
    }

    @Test func rueckblickKommtNurVorDemErstenSatzDesBlocks() async {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)]),
                         satzZiel: 3)
        #expect(sut.rueckblickFaellig == true)
        sut.geraetGeoeffnet()
        #expect(sut.rueckblickOffen == true)
        sut.rueckblickOffen = false

        await sut.satzSichern(problemFlag: false, problemReason: nil)
        sut.pauseBeenden()

        // Vor Satz 2 ist der Rueckblick da, aber nicht mehr faellig -- und ein
        // erneutes "Oeffnen" (das im View nicht vorkommt) holte ihn nicht zurueck.
        #expect(sut.rueckblick != nil)
        #expect(sut.rueckblickFaellig == false)
        sut.geraetGeoeffnet()
        #expect(sut.rueckblickOffen == false)
    }

    @Test func imZirkelZurueckAmGeraetKommtDerRueckblickNichtNochEinmal() {
        // Ueber die Blockliste entsteht ein FRISCHES GeraetModel
        // (TrainingRootView.modell(...)); bootstrap ist die alte Momentaufnahme
        // mit dem letzten Satz von gestern, nur die lokale Session weiss vom
        // ersten Satz von heute. satzNummer liest aus der Session -- deshalb
        // ist sie die tragende Bedingung, nicht bootstrap.
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        _ = sessions.satzSichern(machineId: "m1", exerciseId: "e1",
                                  einheiten: .kilogrammWiederholungen, load: 77.5, volume: 11,
                                  problemFlag: false, problemReason: nil)
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)]),
                         sessions: sessions)

        #expect(sut.rueckblick != nil)
        #expect(sut.rueckblickFaellig == false)
    }

    @Test func rueckblickGehoertZurAngezeigtenUebung() {
        // Derselbe Uebungs-Vorbehalt wie bei kalibrierungswerte: der letzte Satz
        // von e2 sagt nichts ueber e1.
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: [("m1", "e2", 40, 10)]))
        #expect(sut.rueckblick == nil)

        sut.uebungWechseln(zu: "e2")

        #expect(sut.rueckblick?.zuletzt == "40,0 kg × 10")
    }

    // MARK: - Belastung und Umfang in der Einheit des Geraets (Cardio Schnitt 3)

    @Test func dieBeinpresseNenntSchrittBereichUndZielWieBisher() {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))

        #expect(sut.loadUnit == .kg)
        #expect(sut.volumeKind == .reps)
        #expect(sut.secondaryUnit == nil)
        #expect(sut.nebenbelastung == nil)
        #expect(sut.kontextzeileBelastung == "Schritt 2,5 kg · 5,0 – 150,0")
        #expect(sut.kontextzeileUmfang == "Ziel 8 – 12")
        #expect(sut.umfangsWerte == Array(1...40))
        #expect(sut.umfang == 8)

        let ohneGrenze = modell(maschine: GeraetTestdaten.maschineOhneMaximum,
                                bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(ohneGrenze.kontextzeileBelastung == "Schritt 2,5 kg · ab 5,0")
    }

    @Test func dasLaufbandLiestEinheitUndUmfangsartVomModell() {
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))

        #expect(sut.loadUnit == .kmh)
        #expect(sut.secondaryUnit == .pct)
        #expect(sut.volumeKind == .seconds)
        #expect(sut.kontextzeileBelastung == "Schritt 0,5 km/h · 0,0 – 20,0")
        #expect(sut.kontextzeileUmfang == "Ziel 15 – 20 min")
        #expect(sut.umfangsWerte == Rastwerte.umfang(.seconds))
        #expect(sut.belastungsWerte.count == 41)
        #expect(sut.nebenbelastungsWerte.count == 31)
        // Ohne Historie: Belastung am Geraeteminimum, Umfang am unteren
        // Korridorende -- dieselbe Regel wie an der Beinpresse.
        #expect(sut.belastung == 0)
        #expect(sut.umfang == 900)
    }

    @Test func eineStufenanzeigeSchreibtDieEinheitHinterDieSchrittweite() {
        // "Schritt Level 1" laese sich wie die Stufe 1, nicht wie eine
        // Aenderung um eine Stufe.
        let sut = modell(maschine: GeraetTestdaten.ergometerMitStufen,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))

        #expect(sut.kontextzeileBelastung == "Schritt 1 Level · 1 – 20")
        #expect(sut.kontextzeileUmfang == "Ziel 20 – 30 min")
        #expect(sut.secondaryUnit == .rpm)
        #expect(sut.nebenbelastung == 50)
    }

    @Test func dieNebenbelastungStartetOhneHistorieAmMinimum() {
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))

        #expect(sut.nebenbelastung == 0)
    }

    @Test func dieNebenbelastungIstVomLetztenSatzVorbelegt() {
        // Cardio-Spec 3.1b: im Normalfall bleibt die Neigung gleich, und
        // das Mitglied fasst den Regler nicht an.
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(laufbandSaetze: [("m9", "e9", 8.5, 6, 1200)]))

        #expect(sut.belastung == 8.5)
        #expect(sut.nebenbelastung == 6)
        #expect(sut.umfang == 1200)
        #expect(sut.rueckblick?.zuletzt == "8,5 km/h · 6,0 % × 20:00 min")
    }

    @Test func einUmfangAbseitsDerRasterRastetAufDieListe() {
        // Ein Satz aus einer anderen Quelle (Portal, spaetere Fassung) kann
        // 1195 Sekunden tragen; RastRad verlangt ein Element der Liste.
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(laufbandSaetze: [("m9", "e9", 8.4, 6.2, 1195)]))

        #expect(sut.umfang == 1200)
        #expect(sut.belastung == 8.5)
        #expect(sut.nebenbelastung == 6)
    }

    @Test func derVorschlagUebernimmtBelastungUndNebenbelastung() {
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(laufbandSaetze: [("m9", "e9", 8.5, 4, 1200)]))

        sut.kontextUebernehmen(GeraetTestdaten.laufbandKontext(vorschlag: 9, bisher: 8.5, neben: 6))

        #expect(sut.belastung == 9)
        #expect(sut.nebenbelastung == 6)
        #expect(sut.vorschlagText == "Vorschlag · +0,5 km/h")
    }

    @Test func eineSelbstGesetzteNebenbelastungBleibtBeimVorschlag() {
        // Dieselbe ...VomNutzer-Regel wie bei der Belastung, aber getrennt
        // gefuehrt: wer nur die Neigung anfasst, bekommt den
        // Tempo-Vorschlag trotzdem.
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(laufbandSaetze: [("m9", "e9", 8.5, 4, 1200)]))
        sut.nebenbelastungGewaehlt(2)

        sut.kontextUebernehmen(GeraetTestdaten.laufbandKontext(vorschlag: 9, bisher: 8.5, neben: 6))

        #expect(sut.nebenbelastung == 2)
        #expect(sut.belastung == 9)
    }

    @Test func eineSelbstGesetzteBelastungLaesstDieNebenbelastungDemVorschlag() {
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(laufbandSaetze: [("m9", "e9", 8.5, 4, 1200)]))
        sut.belastungGewaehlt(7)

        sut.kontextUebernehmen(GeraetTestdaten.laufbandKontext(vorschlag: 9, bisher: 8.5, neben: 6))

        #expect(sut.belastung == 7)
        #expect(sut.nebenbelastung == 6)
    }

    @Test func dieNebenbelastungRastetAufDieStufenDesGeraets() {
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))

        sut.nebenbelastungGewaehlt(6.3)
        #expect(sut.nebenbelastung == 6.5)
        sut.nebenbelastungGewaehlt(99)
        #expect(sut.nebenbelastung == 15)
    }

    @Test func anEinemKraftgeraetBleibtDieNebenbelastungNil() {
        // Ein gesetzter Wert liesse den Server den Satz abweisen.
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))

        sut.nebenbelastungGewaehlt(6)
        #expect(sut.nebenbelastung == nil)

        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0))
        #expect(sut.nebenbelastung == nil)
    }

    @Test func derSatzTraegtDieNebenbelastungGenauWennDasModellEineHat() async {
        let erfasser = Erfassungswarteschlange()
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(laufbandSaetze: [("m9", "e9", 8.5, 6, 1200)]),
                         sessions: sessions,
                         enqueue: { erfasser.geschriebene.append($0) })

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        let body = erfasser.geschriebene.first?.body
        #expect(body?.load == 8.5)
        #expect(body?.secondaryLoad == 6)
        #expect(body?.volume == 1200)
        let block = sessions.aktiveSession()?.bloecke.first
        #expect(block?.einheiten == Blockeinheiten(loadUnit: .kmh, secondaryUnit: .pct, volumeKind: .seconds))
        #expect(block?.saetze.first?.secondaryLoad == 6)
    }

    @Test func derKontextKannEineNebenbelastungBringenDieDerPrefetchNichtKannte() {
        // Das Studio hat dem Modell seit dem letzten Prefetch eine
        // Nebenbelastung eingetragen. Ohne Abgleich bliebe sie nil, und der
        // Server wiese den Satz ab.
        let sut = modell(maschine: GeraetTestdaten.laufbandOhneNeigung,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(sut.nebenbelastung == nil)

        sut.kontextUebernehmen(GeraetTestdaten.laufbandKontext(vorschlag: nil, bisher: nil, neben: nil))

        #expect(sut.secondaryUnit == .pct)
        #expect(sut.nebenbelastung == 0)
    }

    // MARK: - Satzziel bei Zeit und Strecke (Task 6)

    @Test func amLaufbandIstNachDemErstenSatzDieEntscheidungDran() async {
        // Ein Satz ist bei Zeit und Strecke die Einheit: keine Pause vor
        // einem zweiten Dauerlauf, auch wenn das Profil drei Saetze plant.
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         satzZiel: 3)
        #expect(sut.satzZiel == 1)

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        #expect(sut.phase == .abschluss)
        #expect(sut.laufendePause == nil)
    }

    @Test func einWeitererSatzAmLaufbandBekommtSeinePause() async {
        // Wer trotzdem weitermacht (Intervalle), bekommt die Pause wie
        // jeder Zusatzsatz -- die Regel aendert nur, wann gefragt wird.
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         satzZiel: 3)
        await sut.satzSichern(problemFlag: false, problemReason: nil)

        sut.weitererSatz()

        #expect(sut.laufendePause != nil)
    }

    @Test func auchMeterUebungenHabenEinenSatz() {
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         satzZiel: 4)
        sut.uebungWechseln(zu: "e10")

        #expect(sut.volumeKind == .meters)
        #expect(sut.satzZiel == 1)
    }

    @Test func dieBeinpresseFolgtWeiterDemProfil() async {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         satzZiel: 3)
        #expect(sut.satzZiel == 3)

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        #expect(sut.phase != .abschluss)
        #expect(sut.laufendePause != nil)
    }

    @Test func derUebungswechselRastetDenUmfangAufDieNeueUmfangsart() {
        // Vom Dauerlauf (Sekunden) auf das Intervall (Meter): die Liste
        // wechselt, und der Startwert ist das untere Korridorende der neuen
        // Uebung.
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(laufbandSaetze: [("m9", "e9", 8.5, 6, 1200)]))
        #expect(sut.umfang == 1200)

        sut.uebungWechseln(zu: "e10")

        #expect(sut.volumeKind == .meters)
        #expect(sut.umfangsWerte == Rastwerte.umfang(.meters))
        #expect(sut.umfang == 2000)
        #expect(sut.kontextzeileUmfang == "Ziel 2.000 – 5.000 m")
        // Fuer die neue Uebung gibt es keinen letzten Satz: die
        // Nebenbelastung faellt auf das Minimum, nicht auf die 6 Prozent
        // des Dauerlaufs.
        #expect(sut.nebenbelastung == 0)
    }

    // MARK: - Mitschnitt

    @Test func oeffnenMeldetDieEingabeMitGeraetUndUebung() {
        let spion = MitschnittSpion()
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), mitschnitt: spion)
        sut.geraetGeoeffnet()
        #expect(spion.ereignisse == [.eingabe(SatzMitschnittKontext(
            machineId: "m1", machineName: "Beinpresse", exerciseId: "e1", exerciseName: "Beidbeinig"))])
    }

    @Test func sichernMeldetGenauDenGeschriebenenSatz() async throws {
        let spion = MitschnittSpion()
        var geschrieben: [PendingSetWrite] = []
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)]),
                         enqueue: { geschrieben.append($0) }, mitschnitt: spion)
        sut.geraetGeoeffnet()

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        let write = try #require(geschrieben.first)
        #expect(spion.ereignisse.last == .gesichert(GesicherterSatz(
            sessionId: write.sessionId, setId: write.setId, setIndex: 1,
            weightKg: 77.5, reps: 11, problemFlag: false)))
    }

    @Test func nachDerPauseBeginntDieEingabeErneut() async {
        let spion = MitschnittSpion()
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), mitschnitt: spion)
        sut.geraetGeoeffnet()
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(spion.eingaben == 1)          // in der Pause laeuft nichts
        sut.pauseBeenden()
        #expect(spion.eingaben == 2)
    }

    @Test func uebungswechselInDerEingabeMeldetDenNeuenKontext() {
        let spion = MitschnittSpion()
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), mitschnitt: spion)
        sut.geraetGeoeffnet()
        sut.uebungWechseln(zu: "e2")
        #expect(spion.ereignisse.last == .eingabe(SatzMitschnittKontext(
            machineId: "m1", machineName: "Beinpresse", exerciseId: "e2", exerciseName: "Einbeinig")))
        #expect(spion.eingaben == 2)
    }

    @Test func uebungswechselAusDerPauseMeldetGenauEinmal() async {
        let spion = MitschnittSpion()
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), mitschnitt: spion)
        sut.geraetGeoeffnet()
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        sut.uebungWechseln(zu: "e2")
        #expect(spion.eingaben == 2)
    }

    @Test func amCardioGeraetBleibtDasLabelOhneKiloUndWiederholungen() async throws {
        let spion = MitschnittSpion()
        let sut = modell(maschine: GeraetTestdaten.laufband,
                         bootstrap: GeraetTestdaten.bootstrap(laufbandSaetze: [("m9", "e9", 8.5, 6, 1200)]),
                         mitschnitt: spion)
        sut.geraetGeoeffnet()

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        guard case .gesichert(let satz)? = spion.ereignisse.last else {
            Issue.record("kein gesicherter Satz gemeldet"); return
        }
        #expect(satz.weightKg == nil)
        #expect(satz.reps == nil)
    }

    @Test func verlassenWirdWeitergereicht() {
        let spion = MitschnittSpion()
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), mitschnitt: spion)
        sut.geraetGeoeffnet()
        sut.screenVerlassen()
        #expect(spion.ereignisse.last == .verlassen)
    }
}

@MainActor
final class MitschnittSpion: SatzMitschnitt {
    enum Ereignis: Equatable {
        case eingabe(SatzMitschnittKontext)
        case gesichert(GesicherterSatz)
        case verlassen
    }
    var ereignisse: [Ereignis] = []
    var eingaben: Int { ereignisse.filter { if case .eingabe = $0 { true } else { false } }.count }

    func eingabeBegonnen(_ kontext: SatzMitschnittKontext) { ereignisse.append(.eingabe(kontext)) }
    func satzGesichert(_ satz: GesicherterSatz) { ereignisse.append(.gesichert(satz)) }
    func screenVerlassen() { ereignisse.append(.verlassen) }
}

/// Faengt ein, was eine GeraetModel-Instanz einreiht -- damit ein
/// still geloeschter enqueue-Aufruf in einem Test auffaellt statt
/// unbemerkt durchzugehen.
@MainActor
private final class Erfassungswarteschlange {
    var geschriebene: [PendingSetWrite] = []
}

// MARK: - Testdaten

actor FakeGeraetLoader: GeraetLoading {
    var kontextResult: Result<TagContextResponse, APIError> = .failure(.offline)
    var calibrationResult: Result<RecordedCalibration, APIError> = .failure(.offline)

    /// Wer gerufen wurde. Seit ein Geraet auch ohne Token erreichbar ist,
    /// ist die Wegwahl selbst pruefenswert, nicht nur das Ergebnis.
    private(set) var tagAufrufe: [String] = []
    private(set) var machineAufrufe: [String] = []

    func setKontext(_ value: Result<TagContextResponse, APIError>) { kontextResult = value }
    func setCalibration(_ value: Result<RecordedCalibration, APIError>) { calibrationResult = value }

    func tagContext(token: String) async throws(APIError) -> TagContextResponse {
        tagAufrufe.append(token)
        switch kontextResult {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }

    /// Liefert dasselbe wie tagContext: der Server liefert auf beiden
    /// Wegen dieselbe Form, und geprueft wird hier der Weg, nicht der Inhalt.
    func machineContext(machineId: String) async throws(APIError) -> TagContextResponse {
        machineAufrufe.append(machineId)
        switch kontextResult {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }

    /// Was gesendet wurde -- bei Auswahlwerten zaehlt die Form (Text statt
    /// Zahl), nicht nur, dass gesendet wurde.
    private(set) var kalibrierungen: [CalibrationWrite] = []

    func recordCalibration(_ body: CalibrationWrite) async throws(APIError) -> RecordedCalibration {
        kalibrierungen.append(body)
        switch calibrationResult {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }

    func completeSession(sessionId: UUID) async throws(APIError) -> CompletedSession {
        throw APIError.offline
    }
}

enum GeraetTestdaten {
    static func dekodiere<T: Decodable>(_ json: String, as: T.Type = T.self) -> T {
        try! JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    static var maschine: BootstrapResponse.Machine { maschine(loadMax: "150.0") }
    static var maschineOhneMaximum: BootstrapResponse.Machine { maschine(loadMax: "null") }

    /// Ein Modell ohne Einstellparameter -- laut Trainerportal ein
    /// regulaerer Zustand, kein Datenfehler.
    static var maschineOhneEinstellparameter: BootstrapResponse.Machine {
        dekodiere("""
        {"id":"m1","studioId":"s1","label":"Gerät 7","locationNote":"Fensterseite",
         "status":"active","tokenHashes":[],"visitCount":2,
         "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":"Technogym",
           "category":"kraft","photoPath":null,"loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
           "settingDefinitions":[]},
         "exercises":[{"id":"e1","name":"Beidbeinig","volumeKind":"reps","targetMin":8,"targetMax":12}]}
        """)
    }

    /// Drei Einstellparameter, der mittlere eine Auswahl -- genau der Fall
    /// aus der Testnotiz 06.10., #17 (Kabelzug mit Griffposition).
    static var maschineMitAuswahl: BootstrapResponse.Machine {
        dekodiere("""
        {"id":"m1","studioId":"s1","label":"Gerät 7","locationNote":null,
         "status":"active","tokenHashes":[],"visitCount":0,
         "equipmentModel":{"id":"em1","name":"Kabelzug","manufacturer":null,
           "category":"kraft","photoPath":null,"loadUnit":"kg","loadStep":2.5,"loadMin":2.5,"loadMax":100.0,
           "settingDefinitions":[
             {"key":"hoehe","label":"Höhe","kind":"number",
              "minValue":1,"maxValue":20,"stepValue":1,"unit":null,"allowedValues":null},
             {"key":"griff","label":"Griffposition","kind":"enum",
              "minValue":null,"maxValue":null,"stepValue":null,"unit":null,
              "allowedValues":["eng","weit","neutral"]},
             {"key":"sitz","label":"Sitz","kind":"number",
              "minValue":1,"maxValue":8,"stepValue":1,"unit":null,"allowedValues":null}]},
         "exercises":[{"id":"e1","name":"Kabelzug hoch","volumeKind":"reps","targetMin":10,"targetMax":15}]}
        """)
    }

    /// Ein Bootstrap mit einer Kalibrierung, die eine Auswahl enthaelt.
    static func bootstrapMitAuswahl(griff: String) -> BootstrapResponse {
        dekodiere("""
        {"member":{"displayName":null,"goals":{"weeklyDays":null,"targetWeight":null}},"studios":[],"machines":[],
         "calibrations":[{"machineId":"m1","exerciseId":"e1","settingValues":{"hoehe":7,"griff":"\(griff)","sitz":3},
           "schemaVersion":1,"createdAt":"2026-09-01T10:00:00Z"}],"lastSets":[]}
        """)
    }

    static func maschine(loadMax: String) -> BootstrapResponse.Machine {
        dekodiere("""
        {"id":"m1","studioId":"s1","label":"Gerät 7","locationNote":"Fensterseite",
         "status":"active","tokenHashes":[],"visitCount":2,
         "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":"Technogym",
           "category":"kraft","photoPath":null,"loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":\(loadMax),
           "settingDefinitions":[{"key":"sitz","label":"Sitzposition","kind":"number",
             "minValue":1,"maxValue":8,"stepValue":1,"unit":null,"allowedValues":null}]},
         "exercises":[{"id":"e1","name":"Beidbeinig","volumeKind":"reps","targetMin":8,"targetMax":12}]}
        """)
    }

    /// Zwei Uebungen an einem Geraet -- fuer den Uebungswechsel-Test:
    /// tag-context.ts liefert calibration/suggestion nur fuer eine der beiden.
    static var maschineMitZweiUebungen: BootstrapResponse.Machine {
        dekodiere("""
        {"id":"m1","studioId":"s1","label":"Gerät 7","locationNote":"Fensterseite",
         "status":"active","tokenHashes":[],"visitCount":2,
         "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":"Technogym",
           "category":"kraft","photoPath":null,"loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
           "settingDefinitions":[{"key":"sitz","label":"Sitzposition","kind":"number",
             "minValue":1,"maxValue":8,"stepValue":1,"unit":null,"allowedValues":null}]},
         "exercises":[{"id":"e1","name":"Beidbeinig","volumeKind":"reps","targetMin":8,"targetMax":12},
                      {"id":"e2","name":"Einbeinig","volumeKind":"reps","targetMin":6,"targetMax":10}]}
        """)
    }

    /// Das Laufband aus Spec Abschnitt 9: km/h in halben Schritten,
    /// Neigung als Nebenbelastung, Dauerlauf 15 bis 20 Minuten. Die zweite
    /// Uebung zaehlt Meter -- fuer den Wechsel der Umfangsart.
    static var laufband: BootstrapResponse.Machine { laufband(neigung: true) }
    static var laufbandOhneNeigung: BootstrapResponse.Machine { laufband(neigung: false) }

    private static func laufband(neigung: Bool) -> BootstrapResponse.Machine {
        let neben = neigung
            ? #""secondaryUnit":"pct","secondaryStep":0.5,"secondaryMin":0,"secondaryMax":15,"#
            : #""secondaryUnit":null,"secondaryStep":null,"secondaryMin":null,"secondaryMax":null,"#
        return dekodiere("""
        {"id":"m9","studioId":"s1","label":"Laufband 2","locationNote":null,
         "status":"active","tokenHashes":[],"visitCount":2,
         "equipmentModel":{"id":"em9","name":"Laufband","manufacturer":"Technogym",
           "category":"cardio","photoPath":null,"loadUnit":"kmh","loadStep":0.5,"loadMin":0,"loadMax":20,
           \(neben)
           "settingDefinitions":[]},
         "exercises":[{"id":"e9","name":"Dauerlauf","volumeKind":"seconds","targetMin":900,"targetMax":1200},
                      {"id":"e10","name":"Intervall","volumeKind":"meters","targetMin":2000,"targetMax":5000}]}
        """)
    }

    /// Ergometer mit Stufenanzeige (Spec Abschnitt 9): die Stufe ist die
    /// Belastung, die Trittfrequenz die Nebenbelastung.
    static var ergometerMitStufen: BootstrapResponse.Machine {
        dekodiere("""
        {"id":"m8","studioId":"s1","label":"Ergometer 1","locationNote":null,
         "status":"active","tokenHashes":[],"visitCount":0,
         "equipmentModel":{"id":"em8","name":"Ergometer","manufacturer":null,
           "category":"cardio","photoPath":null,"loadUnit":"level","loadStep":1,"loadMin":1,"loadMax":20,
           "secondaryUnit":"rpm","secondaryStep":5,"secondaryMin":50,"secondaryMax":120,
           "settingDefinitions":[]},
         "exercises":[{"id":"e8","name":"Grundlage","volumeKind":"seconds","targetMin":1200,"targetMax":1800}]}
        """)
    }

    /// Letzte Saetze mit Nebenbelastung: (Geraet, Uebung, Belastung,
    /// Nebenbelastung, Umfang).
    static func bootstrap(laufbandSaetze: [(String, String, Double, Double, Int)]) -> BootstrapResponse {
        let saetze = laufbandSaetze.map { eintrag in
            """
            {"machineId":"\(eintrag.0)","exerciseId":"\(eintrag.1)",
             "load":\(eintrag.2),"secondaryLoad":\(eintrag.3),"volume":\(eintrag.4),"rir":null,
             "performedAt":"2026-09-20T10:00:00Z"}
            """
        }.joined(separator: ",")
        return dekodiere("""
        {"member":{"displayName":null,"goals":{"weeklyDays":null,"targetWeight":null}},"studios":[],"machines":[],"calibrations":[],"lastSets":[\(saetze)]}
        """)
    }

    /// Der Kontext zum Laufband. `neben` ist die Nebenbelastung, bei der
    /// der Vorschlag gilt -- die Regel steigert sie nie, sie gibt sie mit.
    static func laufbandKontext(vorschlag: Double?, bisher: Double?, neben: Double?) -> TagContextResponse {
        func json(_ wert: Double?) -> String { wert.map { "\($0)" } ?? "null" }
        return dekodiere("""
        {"machine":{"id":"m9","label":"Laufband 2","locationNote":null},
         "equipmentModel":{"id":"em9","name":"Laufband","manufacturer":"Technogym",
           "photoUrl":null,"loadUnit":"kmh","loadStep":0.5,"loadMin":0,"loadMax":20,
           "secondaryUnit":"pct","secondaryStep":0.5,"secondaryMin":0,"secondaryMax":15},
         "settingDefinitions":[],
         "exercises":[{"id":"e9","name":"Dauerlauf","description":null,
           "volumeKind":"seconds","targetMin":900,"targetMax":1200,"instructionVideoUrl":null},
           {"id":"e10","name":"Intervall","description":null,
           "volumeKind":"meters","targetMin":2000,"targetMax":5000,"instructionVideoUrl":null}],
         "selectedExerciseId":"e9","calibration":null,
         "history":[],
         "suggestion":{"algoVersion":"2.0.0","resultLoad":\(json(vorschlag)),
           "resultSecondaryLoad":\(json(neben)),
           "reasonCode":"korridor_oben_erreicht","inputs":{"targetMin":900,"targetMax":1200,
             "loadStep":0.5,"loadMin":0,"loadMax":20,
             "currentLoad":\(json(bisher)),"currentSecondaryLoad":\(json(neben)),"consideredBlocks":2}}}
        """)
    }

    static func bootstrap(
        lastSets: [(String, String, Double, Int)],
        mitKalibrierung: Bool = false,
        kalibrierungExerciseId: String = "e1",
        kalibrierungSitzWert: Int = 4
    ) -> BootstrapResponse {
        let saetze = lastSets.map { eintrag in
            """
            {"machineId":"\(eintrag.0)","exerciseId":"\(eintrag.1)",
             "load":\(eintrag.2),"volume":\(eintrag.3),"rir":null,
             "performedAt":"2026-09-01T10:00:00Z"}
            """
        }.joined(separator: ",")
        let kalibrierungen = mitKalibrierung
            ? #"{"machineId":"m1","exerciseId":"\#(kalibrierungExerciseId)","settingValues":{"sitz":\#(kalibrierungSitzWert)},"schemaVersion":1,"createdAt":"2026-09-01T10:00:00Z"}"#
            : ""
        return dekodiere("""
        {"member":{"displayName":null,"goals":{"weeklyDays":null,"targetWeight":null}},"studios":[],"machines":[],"calibrations":[\(kalibrierungen)],"lastSets":[\(saetze)]}
        """)
    }

    static func kontext(vorschlag: Double, kalibrierungSitzWert: Int? = nil) -> TagContextResponse {
        let kalibrierung = kalibrierungSitzWert.map {
            #"{"settingValues":{"sitz":\#($0)},"schemaVersion":1,"source":"self","createdAt":"2026-09-01T10:00:00Z"}"#
        } ?? "null"
        return dekodiere("""
        {"machine":{"id":"m1","label":"Gerät 7","locationNote":"Fensterseite"},
         "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":"Technogym",
           "photoUrl":null,"loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0},
         "settingDefinitions":[{"key":"sitz","label":"Sitzposition","kind":"number",
           "minValue":1,"maxValue":8,"stepValue":1,"unit":null,"allowedValues":null}],
         "exercises":[{"id":"e1","name":"Beidbeinig","description":null,
           "volumeKind":"reps","targetMin":8,"targetMax":12,"instructionVideoUrl":null},
           {"id":"e2","name":"Einbeinig","description":null,
           "volumeKind":"reps","targetMin":6,"targetMax":10,"instructionVideoUrl":null}],
         "selectedExerciseId":"e1","calibration":\(kalibrierung),
         "history":[{"performedOn":"2026-09-01","load":77.5,"volume":[11,11,10]}],
         "suggestion":{"algoVersion":"v1","resultLoad":\(vorschlag),
           "reasonCode":"steigerung","inputs":{"targetMin":8,"targetMax":12,
             "loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
             "currentLoad":77.5,"consideredBlocks":1}}}
        """)
    }
}
