import AVFoundation
import Koerperbild
import Testing
@testable import FitnessMember

struct FlowAnzeigeTests {
    @Test func uhrKurzZeigtMinutenUndSekunden() {
        #expect(FlowAnzeige.uhrKurz(14) == "0:14")
        #expect(FlowAnzeige.uhrKurz(75) == "1:15")
        #expect(FlowAnzeige.uhrKurz(0) == "0:00")
    }

    @Test func pausenzeileNurBeiKamera() {
        let tempo = Uebungstempo(senken: 1, halten: 0, heben: 1, beginntMit: .senken)
        let vorgabe = Kameravorgabe(profil: .stuetzBoden, signal: .ellbogen, seite: .beide)!
        let start = KameraStart(exerciseId: "e1", name: "Liegestütz", geraet: nil, vorgabe: vorgabe,
                                tempo: tempo, sollWiederholungen: nil, satzZiel: 1)
        #expect(FlowAnzeige.pausenzeile(ansicht: .kamera(start)) == "Stell dich seitlich zur Kamera")
        #expect(FlowAnzeige.pausenzeile(ansicht: .video(exerciseId: "e1")) == nil)
        #expect(FlowAnzeige.pausenzeile(ansicht: .ring) == nil)
    }

    @Test func pausenzeileFuerBlickRichtungenUndOhneKamera() {
        let tempo = Uebungstempo(senken: 1, halten: 0, heben: 1, beginntMit: .senken)
        func start(_ profil: Kameraprofil, signal: Gelenkwinkel?) -> FlowSchrittAnsicht {
            let vorgabe = Kameravorgabe(profil: profil, signal: signal, seite: .beide)!
            return .kamera(KameraStart(exerciseId: "e", name: "U", geraet: nil, vorgabe: vorgabe, tempo: tempo,
                                       sollWiederholungen: nil, satzZiel: 1))
        }
        #expect(FlowAnzeige.pausenzeile(ansicht: start(.oberkoerper, signal: .ellbogen)) == "Schau zur Kamera")
        #expect(FlowAnzeige.pausenzeile(ansicht: start(.ohneKamera, signal: nil)) == nil)
    }
}

private func schritte(_ n: Int) -> [FlowSchritt] {
    (0..<n).map { FlowSchritt(position: $0 + 1, name: "S\($0 + 1)", beschreibung: nil, workS: 40, restS: 20,
                              istWarmup: false, exerciseId: "e\($0)") }
}

struct FlowVideoPlanTests {
    @Test func seitenJePhase() {
        let s = schritte(3)
        #expect(FlowVideoPlan.seite(zustand: .countdown(restS: 4), schritte: s)
            == FlowVideoSeite(schrittIndex: 0, ueberschrift: "GLEICH GEHT'S LOS", zeile: "Als Nächstes", restS: 4,
                              mitBlickzeile: true, naechsterName: nil))
        #expect(FlowVideoPlan.seite(zustand: .arbeit(schritt: 1, restS: 30), schritte: s)
            == FlowVideoSeite(schrittIndex: 1, ueberschrift: "SCHRITT 2 VON 3", zeile: nil, restS: 30,
                              mitBlickzeile: false, naechsterName: "S3"))
        #expect(FlowVideoPlan.seite(zustand: .arbeit(schritt: 2, restS: 30), schritte: s)?.naechsterName == nil)
        #expect(FlowVideoPlan.seite(zustand: .pause(naechster: 2, restS: 9), schritte: s)
            == FlowVideoSeite(schrittIndex: 2, ueberschrift: "PAUSE", zeile: "Als Nächstes", restS: 9,
                              mitBlickzeile: true, naechsterName: nil))
        #expect(FlowVideoPlan.seite(zustand: .fertig, schritte: s) == nil)
        #expect(FlowVideoPlan.seite(zustand: .countdown(restS: 3), schritte: []) == nil)
    }

    @Test func benoetigteSchritteSindGezeigterUndFolgender() {
        #expect(FlowVideoPlan.benoetigteSchritte(phase: .countdown, anzahl: 3) == [0, 1])
        #expect(FlowVideoPlan.benoetigteSchritte(phase: .arbeit(1), anzahl: 3) == [1, 2])
        #expect(FlowVideoPlan.benoetigteSchritte(phase: .pause(2), anzahl: 3) == [2])
        #expect(FlowVideoPlan.benoetigteSchritte(phase: .fertig, anzahl: 3).isEmpty)
    }

    @Test func eintreffenInLaufenderPhaseGiltErstSpaeter() {
        let asset = AVURLAsset(url: URL(fileURLWithPath: "/x.mp4"))
        var stand = FlowVideoStand()
        stand.eingetroffen("e0", asset: asset, in: .arbeit(0))
        #expect(stand.asset(fuer: "e0", in: .arbeit(0)) == nil)
        #expect(stand.asset(fuer: "e0", in: .pause(1)) === asset)
        #expect(stand.asset(fuer: "e9", in: .pause(1)) == nil)
        #expect(stand.asset(fuer: nil, in: .pause(1)) == nil)
    }

    @Test func vorgeladenesVideoGiltSofort() {
        let asset = AVURLAsset(url: URL(fileURLWithPath: "/x.mp4"))
        let stand = FlowVideoStand(vorgeladen: ["e0": asset])
        #expect(stand.asset(fuer: "e0", in: .countdown) === asset)
    }

    @Test func fehlendeNurFuerGebrauchteSchritteMitVideo() {
        let s = schritte(3)
        let ansichten: [FlowSchrittAnsicht] = [.video(exerciseId: "e0"), .ring, .video(exerciseId: "e2")]
        let asset = AVURLAsset(url: URL(fileURLWithPath: "/x.mp4"))
        #expect(FlowVideoStand.fehlende(schritte: s, ansichten: ansichten, phase: .countdown, stand: FlowVideoStand())
            == ["e0"])
        #expect(FlowVideoStand.fehlende(schritte: s, ansichten: ansichten, phase: .arbeit(1), stand: FlowVideoStand())
            == ["e2"])
        #expect(FlowVideoStand.fehlende(schritte: s, ansichten: ansichten, phase: .countdown,
                                        stand: FlowVideoStand(vorgeladen: ["e0": asset])).isEmpty)
    }
}
