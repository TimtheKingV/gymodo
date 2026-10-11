import Testing
@testable import FitnessMember

/// Was die Kachel einer Geraetezeile zeigt und was unter dem Namen steht
/// (Testnotiz 11.10., #2, #3).
struct GeraeteKachelTests {

    @Test func einGeraetMitEinerUebungZeigtDerenVideo() {
        #expect(GeraeteAuswahl.videoUebung(uebungsIds: ["u1"]) == "u1")
    }

    @Test func einGeraetMitMehrerenUebungenZeigtDasFoto() {
        // Welches der Videos stuende fuer das Geraet? Keins -- bis ein
        // eigenes Bild nachgereicht ist, bleibt es beim Foto.
        #expect(GeraeteAuswahl.videoUebung(uebungsIds: ["u1", "u2", "u3"]) == nil)
    }

    @Test func einGeraetOhneUebungZeigtDasFoto() {
        #expect(GeraeteAuswahl.videoUebung(uebungsIds: []) == nil)
    }

    @Test func zahlDerUebungenImSingularUndPlural() {
        #expect(GeraeteAuswahl.uebungsanzahlText(1) == "1 Übung")
        #expect(GeraeteAuswahl.uebungsanzahlText(4) == "4 Übungen")
    }

    @Test func ohneUebungSagtDieZeileNichts() {
        #expect(GeraeteAuswahl.uebungsanzahlText(0) == nil)
    }
}
