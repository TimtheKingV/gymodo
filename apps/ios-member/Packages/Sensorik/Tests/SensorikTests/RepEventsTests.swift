import Foundation
import Testing
@testable import Sensorik

struct RepEventsTests {
    private func wdh(_ n: Int, _ b: Double, _ u: Double, _ e: Double) -> ZaehlerEreignis {
        .wiederholung(Wiederholung(nummer: n, beginn: b, umkehr: u, ende: e,
                                   ausschlag: 112.437, sicherheit: 0.9349, pauseDavor: nil))
    }

    @Test func zeitenSindRelativZumSatzbeginnUndGerundet() {
        let events = RepEvents(algo: "langhantel/1", befestigungsart: .langhantel,
                               ereignisse: [wdh(1, 103.421, 104.6149, 105.98)], satzbeginn: 100)
        #expect(events.wiederholungen == [.init(beginn: 3.42, umkehr: 4.61, ende: 5.98,
                                                 ausschlag: 112.44, sicherheit: 0.93)])
        #expect(events.unsicher == nil)
    }

    @Test func derUnsicherGrundWirdUebernommen() {
        let events = RepEvents(algo: "stapel/1", befestigungsart: .stapel,
                               ereignisse: [wdh(1, 1, 2, 3), .unsicher(.luecke), .zuende], satzbeginn: 0)
        #expect(events.unsicher == .luecke)
        #expect(events.wiederholungen.count == 1)
    }

    /// Der Server (Zod, Spec B 6.2) erwartet `unsicher` immer als Schluessel,
    /// auch wenn er null ist -- ein fehlender Schluessel waere eine zweite
    /// Bedeutung von "nichts".
    @Test func jsonHatDieSchluesselDesServers() throws {
        let events = RepEvents(algo: "langhantel/1", befestigungsart: .langhantel,
                               ereignisse: [wdh(1, 3.42, 4.61, 5.98)], satzbeginn: 0)
        let json = try #require(String(data: SensorikJSON.encoder().encode(events), encoding: .utf8))
        #expect(json.contains("\"unsicher\" : null"))
        #expect(json.contains("\"befestigungsart\" : \"langhantel\""))
        #expect(json.contains("\"algo\" : \"langhantel/1\""))
        let zurueck = try SensorikJSON.decoder().decode(RepEvents.self, from: Data(json.utf8))
        #expect(zurueck == events)
    }

    @Test func dieRohwerteDerBefestigungsartenSindFest() {
        #expect(Befestigungsart.allCases.map(\.rawValue)
                == ["stapel", "langhantel", "kurzhantel", "hebelarm", "kabelgriff", "koerper"])
        #expect(Befestigungsart.freigegeben.isEmpty)
    }

    @Test func phasendauernSindAbgeleitet() {
        let w = Wiederholung(nummer: 1, beginn: 1, umkehr: 2.5, ende: 4, ausschlag: 1, sicherheit: 1, pauseDavor: nil)
        #expect(w.dauerKonzentrisch == 1.5)
        #expect(w.dauerExzentrisch == 1.5)
    }

    /// Ein Ereignis kann durch die 30-ms-Buendelung knapp vor dem Satzbeginn
    /// liegen; der Server lehnt negative Zeiten ab und der Satz waere nie speicherbar.
    @Test func zeitenVorDemSatzbeginnWerdenNull() throws {
        let events = RepEvents(algo: "langhantel/1", befestigungsart: .langhantel,
                               ereignisse: [wdh(1, 99.99, 100.5, 101.5)], satzbeginn: 100)
        #expect(events.wiederholungen[0].beginn == 0)
        #expect(events.wiederholungen[0].umkehr == 0.5)
        let json = try #require(String(data: SensorikJSON.encoder().encode(events), encoding: .utf8))
        #expect(!json.contains("-"))
    }

    @Test func nanUndUnendlichWerdenNullUndLassenSichKodieren() throws {
        let w = ZaehlerEreignis.wiederholung(Wiederholung(nummer: 1, beginn: 1, umkehr: 2, ende: 3,
                                                          ausschlag: .nan, sicherheit: .infinity, pauseDavor: nil))
        let events = RepEvents(algo: "stapel/1", befestigungsart: .stapel, ereignisse: [w], satzbeginn: 0)
        #expect(events.wiederholungen[0].ausschlag == 0)
        #expect(events.wiederholungen[0].sicherheit == 0)
        _ = try SensorikJSON.encoder().encode(events)
    }

    @Test func sicherheitBleibtImBereichNullBisEins() {
        let w = ZaehlerEreignis.wiederholung(Wiederholung(nummer: 1, beginn: 1, umkehr: 2, ende: 3,
                                                          ausschlag: 5, sicherheit: 1.3, pauseDavor: nil))
        let events = RepEvents(algo: "stapel/1", befestigungsart: .stapel, ereignisse: [w], satzbeginn: 0)
        #expect(events.wiederholungen[0].sicherheit == 1)
    }
}
