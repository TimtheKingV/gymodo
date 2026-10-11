import Foundation
import Testing
@testable import FitnessMember

/// Uebungsvideos fuer Liste und Uebungszeilen (Testnotiz 11.10., #1, #5, #7):
/// was ankommt, wird zur Zuordnung Uebung -> Quelle, jeder Fehler endet
/// leer -- wie bei den Geraetefotos.
struct UebungsVideosTests {

    private struct Fake: UebungsvideosLoading {
        let ergebnis: Result<ExerciseVideosResponse, APIError>
        func exerciseVideos() async throws(APIError) -> ExerciseVideosResponse {
            try ergebnis.get()
        }
    }

    @Test func dekodiertDieAntwortDesServers() throws {
        let json = #"{"videos":[{"exerciseId":"u1","url":"https://example.test/u1.mp4?token=a","pfad":"gymtavo/u1.mp4"}]}"#
        let antwort = try JSONDecoder().decode(ExerciseVideosResponse.self, from: Data(json.utf8))
        #expect(antwort.videos.first?.pfad == "gymtavo/u1.mp4")
    }

    @Test func ordnetQuelleDerUebungZu() async {
        let antwort = ExerciseVideosResponse(videos: [
            .init(exerciseId: "u1", url: "https://example.test/u1.mp4", pfad: "gymtavo/u1.mp4"),
        ])
        let videos = await UebungsVideos.laden(von: Fake(ergebnis: .success(antwort)))
        #expect(videos == ["u1": UebungsVideo(url: URL(string: "https://example.test/u1.mp4")!, pfad: "gymtavo/u1.mp4")])
    }

    @Test func offlineGibtKeineVideosStattEinesFehlers() async {
        let videos = await UebungsVideos.laden(von: Fake(ergebnis: .failure(.offline)))
        #expect(videos.isEmpty)
    }
}

/// Die Dateiablage haelt die Schleifen auf der Platte: eine signierte URL
/// lebt 15 Minuten, ein Keller hat keinen Empfang.
struct VideoAblageTests {

    /// Zaehlt Abrufe und liefert je URL feste Bytes.
    private actor Zaehler {
        var abrufe: [URL] = []
        var scheitert = false
        func laden(_ url: URL) -> Data? {
            abrufe.append(url)
            return scheitert ? nil : Data(url.absoluteString.utf8)
        }
        func scheitern() { scheitert = true }
    }

    private func ordner() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("videoablage-\(UUID().uuidString)")
    }

    private func quelle(_ pfad: String, token: String = "a") -> UebungsVideo {
        UebungsVideo(url: URL(string: "https://example.test/\(pfad)?token=\(token)")!, pfad: pfad)
    }

    @Test func laedtEinmalUndLiefertDanachDieDatei() async throws {
        let zaehler = Zaehler()
        let ablage = VideoAblage(ordner: ordner()) { await zaehler.laden($0) }

        let erste = await ablage.datei(exerciseId: "u1", quelle: quelle("a/u1.mp4"))
        // Neue Signatur, derselbe Pfad: die Datei liegt schon da.
        let zweite = await ablage.datei(exerciseId: "u1", quelle: quelle("a/u1.mp4", token: "b"))

        #expect(erste != nil)
        #expect(erste == zweite)
        #expect(await zaehler.abrufe.count == 1)
        #expect(FileManager.default.fileExists(atPath: try #require(erste).path))
    }

    @Test func einErsetztesVideoWirdNeuGeladen() async {
        let zaehler = Zaehler()
        let ablage = VideoAblage(ordner: ordner()) { await zaehler.laden($0) }

        let alt = await ablage.datei(exerciseId: "u1", quelle: quelle("a/u1.mp4"))
        let neu = await ablage.datei(exerciseId: "u1", quelle: quelle("a/u1-neu.mp4"))

        #expect(alt != neu)
        #expect(await zaehler.abrufe.count == 2)
    }

    @Test func ohneQuelleFindetSieDieZuletztAbgelegteDatei() async {
        // Offline nach einem Neustart: der Vorrat ist leer, die Datei nicht.
        let ziel = ordner()
        let zaehler = Zaehler()
        let erste = VideoAblage(ordner: ziel) { await zaehler.laden($0) }
        let abgelegt = await erste.datei(exerciseId: "u1", quelle: quelle("a/u1.mp4"))

        let nachNeustart = VideoAblage(ordner: ziel) { await zaehler.laden($0) }
        let gefunden = await nachNeustart.datei(exerciseId: "u1", quelle: nil)

        #expect(gefunden == abgelegt)
        #expect(await zaehler.abrufe.count == 1)
    }

    @Test func einFehlgeschlagenerAbrufGibtNil() async {
        let zaehler = Zaehler()
        await zaehler.scheitern()
        let ablage = VideoAblage(ordner: ordner()) { await zaehler.laden($0) }

        #expect(await ablage.datei(exerciseId: "u1", quelle: quelle("a/u1.mp4")) == nil)
        #expect(await ablage.datei(exerciseId: "u2", quelle: nil) == nil)
    }

    @Test func gleichzeitigeAnfragenLadenNurEinmal() async {
        let zaehler = Zaehler()
        let ablage = VideoAblage(ordner: ordner()) { await zaehler.laden($0) }

        async let a = ablage.datei(exerciseId: "u1", quelle: quelle("a/u1.mp4"))
        async let b = ablage.datei(exerciseId: "u1", quelle: quelle("a/u1.mp4"))
        let ergebnisse = await [a, b]

        #expect(ergebnisse[0] == ergebnisse[1])
        #expect(await zaehler.abrufe.count == 1)
    }
}
