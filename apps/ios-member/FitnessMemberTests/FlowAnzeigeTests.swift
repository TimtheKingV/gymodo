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
}
