#if DEBUG
import Foundation
import Testing
@testable import FitnessMember

struct WitMotionBefehlTests {
    @Test func bytesDerVierBefehle() {
        #expect(WitMotionBefehl.rate(.hz20).bytes == Data([0xFF, 0xAA, 0x03, 0x07, 0x00]))
        #expect(WitMotionBefehl.rate(.hz50).bytes == Data([0xFF, 0xAA, 0x03, 0x08, 0x00]))
        #expect(WitMotionBefehl.rate(.hz100).bytes == Data([0xFF, 0xAA, 0x03, 0x09, 0x00]))
        #expect(WitMotionBefehl.akkuLesen.bytes == Data([0xFF, 0xAA, 0x27, 0x64, 0x00]))
    }

    @Test func kenntWederKalibrierenNochSpeichern() {
        // Ein Kalibrier-Befehl am schraeg haengenden Sensor verfaelscht alle
        // folgenden Daten, ein Speichern macht einen Fehlversuch dauerhaft
        // (Spec 2). Der Test haelt fest, dass niemand sie nachruestet.
        let verboten = [Data([0xFF, 0xAA, 0x01, 0x01, 0x00]), Data([0xFF, 0xAA, 0x00, 0x00, 0x00])]
        for befehl in WitMotionBefehl.alle {
            #expect(!verboten.contains(befehl.bytes))
        }
        #expect(WitMotionBefehl.alle.count == 4)
    }

    @Test func akkuInProzent() {
        #expect(Akkustand.prozent(hundertstelVolt: 410) == 100)
        #expect(Akkustand.prozent(hundertstelVolt: 396) == 90)
        #expect(Akkustand.prozent(hundertstelVolt: 380) == 50)
        #expect(Akkustand.prozent(hundertstelVolt: 369) == 15)
        #expect(Akkustand.prozent(hundertstelVolt: 300) == 0)
    }
}
#endif
