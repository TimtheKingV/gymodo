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
        #expect(GeraetEinstiegRechner.einstieg(visitCount: 0, genutzteUebungen: 0) == .erkannt)
    }

    @Test func nachGenauEinemBesuchBleibenDieOptionenSichtbar() {
        #expect(GeraetEinstiegRechner.einstieg(visitCount: 1, genutzteUebungen: 1) == .erkannt)
    }

    @Test func abZweiBesuchenMitMehrerenUebungenBleibtDieListe() {
        #expect(GeraetEinstiegRechner.einstieg(visitCount: 2, genutzteUebungen: 2) == .erkannt)
    }

    @Test func abZweiBesuchenMitImmerDerselbenUebungGehtEsDirektZumSatz() {
        #expect(GeraetEinstiegRechner.einstieg(visitCount: 2, genutzteUebungen: 1) == .direktZumSatz)
        #expect(GeraetEinstiegRechner.einstieg(visitCount: 9, genutzteUebungen: 1) == .direktZumSatz)
    }

    @Test func erstkontaktBrauchtWederKalibrierungNochSatz() {
        #expect(GeraetEinstiegRechner.istErstkontakt(hatKalibrierung: false, hatLetztenSatz: false))
        #expect(!GeraetEinstiegRechner.istErstkontakt(hatKalibrierung: true, hatLetztenSatz: false))
        #expect(!GeraetEinstiegRechner.istErstkontakt(hatKalibrierung: false, hatLetztenSatz: true))
    }

    @Test func alteSaetzeAusserhalbDesScanFenstersLoesenKeinenDreischrittAus() {
        // visitCount kann 0 lesen, wenn die Saetze aus dem 2000er-Fenster
        // von getBootstrap gefallen sind. Die Kalibrierung faengt das ab --
        // sie wird ungedeckelt gelesen.
        #expect(!GeraetEinstiegRechner.istErstkontakt(hatKalibrierung: true, hatLetztenSatz: false))
    }

    @Test func zaehltGenutzteUebungenAusDenLetztenSaetzen() {
        let bootstrap = bootstrapMitLetztenSaetzen([("m1", "e1"), ("m1", "e2"), ("m2", "e1")])
        #expect(GeraetEinstiegRechner.genutzteUebungen(machineId: "m1", in: bootstrap) == 2)
        #expect(GeraetEinstiegRechner.genutzteUebungen(machineId: "m3", in: bootstrap) == 0)
    }
}

// MARK: - Testdaten

private func bootstrapMitTokenHash(_ hash: String) -> BootstrapResponse {
    BootstrapResponse(
        studios: [],
        machines: [maschine(id: "m1", tokenHashes: [hash])],
        calibrations: [],
        lastSets: []
    )
}

private func bootstrapMitLetztenSaetzen(_ paare: [(String, String)]) -> BootstrapResponse {
    BootstrapResponse(
        studios: [],
        machines: [maschine(id: "m1", tokenHashes: [])],
        calibrations: [],
        lastSets: paare.map { paar in
            BootstrapResponse.LastSet(machineId: paar.0, exerciseId: paar.1,
                                      weightKg: 80, reps: 10, rir: nil,
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
            weightStepKg: 2.5, minWeightKg: 5, maxWeightKg: 150,
            settingDefinitions: []
        ),
        exercises: []
    )
}
