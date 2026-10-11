import Foundation
import Testing
@testable import FitnessMember

struct MachineResolverTests {
    @Test func hashtWieDerServer() {
        // packages/domain/src/tags.ts: sha256 des UTF-8-Tokens, Hex,
        // Kleinbuchstaben. Referenzwert: echo -n "abc" | shasum -a 256
        #expect(MachineResolver.hash(token: "abc")
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func findetDasGeraetImPrefetch() {
        let treffer = MachineResolver.maschine(
            fuerToken: "abc",
            in: bootstrapMitTokenHash("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        )
        #expect(treffer?.id == "m1")
    }

    @Test func findetNichtsBeiUnbekanntemToken() {
        #expect(MachineResolver.maschine(fuerToken: "xyz",
                                         in: bootstrapMitTokenHash("deadbeef")) == nil)
    }
}

struct GeraetEinstiegTests {
    // designsystem.md SS8, Zeile fuer Zeile.

    @Test func ohneBesuchKommtDerErkennungsScreen() {
        // "0 -- Erstkontakt: Geraet erkannt -> Einweisung -> ..."
        #expect(GeraetEinstiegRechner.einstieg(visitCount: 0, genutzteUebungen: 0, uebungsanzahl: 3) == .erkannt)
    }

    @Test func nachGenauEinemBesuchBleibenDieOptionenSichtbar() {
        #expect(GeraetEinstiegRechner.einstieg(visitCount: 1, genutzteUebungen: 1, uebungsanzahl: 3) == .erkannt)
    }

    @Test func abZweiBesuchenMitMehrerenUebungenBleibtDieListe() {
        #expect(GeraetEinstiegRechner.einstieg(visitCount: 2, genutzteUebungen: 2, uebungsanzahl: 3) == .erkannt)
    }

    @Test func abZweiBesuchenMitImmerDerselbenUebungGehtEsDirektZumSatz() {
        #expect(GeraetEinstiegRechner.einstieg(visitCount: 2, genutzteUebungen: 1, uebungsanzahl: 3) == .direktZumSatz)
        #expect(GeraetEinstiegRechner.einstieg(visitCount: 9, genutzteUebungen: 1, uebungsanzahl: 3) == .direktZumSatz)
    }

    @Test func ohneBekannteUebungFaelltEsSicherAufDieListeZurueck() {
        // Ohne genau eine genutzte Uebung fehlt die Zielgroesse fuer den
        // Direktsprung -- die Liste ist der sichere Fallback, kein stummer Tap.
        #expect(GeraetEinstiegRechner.einstieg(visitCount: 2, genutzteUebungen: 0, uebungsanzahl: 3) == .erkannt)
    }

    @Test func einGeraetMitNurEinerUebungSpringtSchonBeimErstenMalDirekt() {
        // Testnotiz 11.10., #4: es gibt nichts zu waehlen -- die
        // Uebungsliste waere ein Tipp ohne Entscheidung.
        #expect(GeraetEinstiegRechner.einstieg(visitCount: 0, genutzteUebungen: 0, uebungsanzahl: 1) == .direktZumSatz)
        #expect(GeraetEinstiegRechner.einstieg(visitCount: 1, genutzteUebungen: 1, uebungsanzahl: 1) == .direktZumSatz)
    }

    @Test func einGeraetOhneUebungBleibtBeimErkennungsScreen() {
        #expect(GeraetEinstiegRechner.einstieg(visitCount: 0, genutzteUebungen: 0, uebungsanzahl: 0) == .erkannt)
    }

    @Test func erstkontaktBrauchtWederKalibrierungNochSatz() {
        #expect(GeraetEinstiegRechner.istErstkontakt(hatKalibrierung: false, hatLetztenSatz: false))
        #expect(!GeraetEinstiegRechner.istErstkontakt(hatKalibrierung: true, hatLetztenSatz: false))
        #expect(!GeraetEinstiegRechner.istErstkontakt(hatKalibrierung: false, hatLetztenSatz: true))
        #expect(!GeraetEinstiegRechner.istErstkontakt(hatKalibrierung: true, hatLetztenSatz: true))
    }

    @Test func alteSaetzeAusserhalbDesScanFenstersLoesenKeinenDreischrittAus() {
        // visitCount kann 0 lesen, wenn die Saetze aus dem 2000er-Fenster
        // von getBootstrap gefallen sind. Die Kalibrierung faengt das ab --
        // sie wird ungedeckelt gelesen.
        #expect(!GeraetEinstiegRechner.istErstkontakt(hatKalibrierung: true, hatLetztenSatz: false))
    }

    @Test func brauchtErstkontaktNurOhneKalibrierungOhneSatzUndVorDemErstenSatzDerEinheit() {
        let ohneAlles = bootstrapMitLetztenSaetzen([])
        #expect(GeraetEinstiegRechner.brauchtErstkontakt(
            station: "geraet:m1", exerciseId: "e1", in: ohneAlles, naechsterSetIndex: 1))
        // Schon ein Satz in der laufenden Einheit, den der Bootstrap noch
        // nicht kennt.
        #expect(!GeraetEinstiegRechner.brauchtErstkontakt(
            station: "geraet:m1", exerciseId: "e1", in: ohneAlles, naechsterSetIndex: 2))
        let mitSatz = bootstrapMitLetztenSaetzen([("m1", "e1")])
        #expect(!GeraetEinstiegRechner.brauchtErstkontakt(
            station: "geraet:m1", exerciseId: "e1", in: mitSatz, naechsterSetIndex: 1))
    }

    @Test func zaehltGenutzteUebungenAusDenLetztenSaetzen() {
        let bootstrap = bootstrapMitLetztenSaetzen([("m1", "e1"), ("m1", "e2"), ("m2", "e1")])
        #expect(GeraetEinstiegRechner.genutzteUebungen(station: "geraet:m1", in: bootstrap) == 2)
        #expect(GeraetEinstiegRechner.genutzteUebungen(station: "geraet:m3", in: bootstrap) == 0)
    }

    @Test func letzteUebungLiestDenJuengstenSatzUnabhaengigVonDerReihenfolge() {
        // EIN Ort statt zweier Ableitungen in TrainingRootView -- beide
        // funktionierten vorher nur, weil der Server absteigend sortiert.
        // Hier absichtlich AUFsteigend eingereicht, damit ein sortReihenfolge-
        // Fund erneut auffiele.
        let bootstrap = BootstrapResponse(
            member: .init(displayName: nil),
            studios: [], machines: [maschine(id: "m1", tokenHashes: [])], calibrations: [],
            lastSets: [
                BootstrapResponse.LastSet(machineId: "m1", exerciseId: "e1", load: 40, secondaryLoad: nil, volume: 10,
                                          rir: nil, performedAt: "2026-08-01T10:00:00Z"),
                BootstrapResponse.LastSet(machineId: "m1", exerciseId: "e2", load: 40, secondaryLoad: nil, volume: 10,
                                          rir: nil, performedAt: "2026-09-01T10:00:00Z"),
                BootstrapResponse.LastSet(machineId: "m2", exerciseId: "e3", load: 40, secondaryLoad: nil, volume: 10,
                                          rir: nil, performedAt: "2026-09-05T10:00:00Z"),
            ]
        )
        #expect(GeraetEinstiegRechner.letzteUebung(station: "geraet:m1", in: bootstrap) == "e2")
        #expect(GeraetEinstiegRechner.letzteUebung(station: "geraet:m3", in: bootstrap) == nil)
    }

    @Test func zaehltBesucheUndLetzteUebungJeStationAmTyp() {
        let bootstrap = BootstrapResponse(
            member: .init(displayName: nil), studios: [], machines: [], calibrations: [], lastSets: [],
            lastTypeSets: [
                BootstrapResponse.LastTypeSet(equipmentModelId: "t1", exerciseId: "e1", load: 40, secondaryLoad: nil,
                                              volume: 10, rir: nil, performedAt: "2026-08-01T10:00:00Z"),
                BootstrapResponse.LastTypeSet(equipmentModelId: "t1", exerciseId: "e2", load: 40, secondaryLoad: nil,
                                              volume: 10, rir: nil, performedAt: "2026-09-01T10:00:00Z"),
                BootstrapResponse.LastTypeSet(equipmentModelId: "t2", exerciseId: "e3", load: 40, secondaryLoad: nil,
                                              volume: 10, rir: nil, performedAt: "2026-09-05T10:00:00Z"),
            ])
        #expect(GeraetEinstiegRechner.genutzteUebungen(station: "typ:t1", in: bootstrap) == 2)
        #expect(GeraetEinstiegRechner.letzteUebung(station: "typ:t1", in: bootstrap) == "e2")
        #expect(GeraetEinstiegRechner.letzteUebung(station: "typ:t3", in: bootstrap) == nil)
        #expect(GeraetEinstiegRechner.hatLetztenSatz(station: "typ:t2", exerciseId: "e3", in: bootstrap))
        // Kalibrierungen gibt es nur am Geraet.
        #expect(!GeraetEinstiegRechner.hatKalibrierung(station: "typ:t1", exerciseId: "e1", in: bootstrap))
        // Ein Typsatz zaehlt nicht fuer ein Geraet.
        #expect(GeraetEinstiegRechner.genutzteUebungen(station: "geraet:t1", in: bootstrap) == 0)
    }
}

// MARK: - Testdaten

private func bootstrapMitTokenHash(_ hash: String) -> BootstrapResponse {
    BootstrapResponse(
        member: .init(displayName: nil),
        studios: [],
        machines: [maschine(id: "m1", tokenHashes: [hash])],
        calibrations: [],
        lastSets: []
    )
}

private func bootstrapMitLetztenSaetzen(_ paare: [(String, String)]) -> BootstrapResponse {
    BootstrapResponse(
        member: .init(displayName: nil),
        studios: [],
        machines: [maschine(id: "m1", tokenHashes: [])],
        calibrations: [],
        lastSets: paare.map { paar in
            BootstrapResponse.LastSet(machineId: paar.0, exerciseId: paar.1,
                                      load: 80, secondaryLoad: nil, volume: 10, rir: nil,
                                      performedAt: "2026-09-01T10:00:00Z")
        }
    )
}

private func maschine(id: String, tokenHashes: [String]) -> BootstrapResponse.Machine {
    BootstrapResponse.Machine(
        id: id, studioId: "s1", label: "Gerät 7", locationNote: nil,
        status: "active", tokenHashes: tokenHashes, visitCount: 0,
        equipmentModel: BootstrapResponse.EquipmentModel(
            id: "em1", name: "Beinpresse", manufacturer: nil, photoPath: nil,
            category: .kraft, loadUnit: .kg, loadStep: 2.5, loadMin: 5, loadMax: 150,
            secondaryUnit: nil, secondaryStep: nil, secondaryMin: nil, secondaryMax: nil,
            settingDefinitions: []
        ),
        exercises: []
    )
}
