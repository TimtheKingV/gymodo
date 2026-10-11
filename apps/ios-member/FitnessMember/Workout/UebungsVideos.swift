import Foundation
import Observation

/// Was die Uebungsvideos vom Netz brauchen -- eine schmale Fassade wie
/// GeraetefotosLoading, damit die Zuordnung ohne APIClient pruefbar bleibt.
protocol UebungsvideosLoading: Sendable {
    func exerciseVideos() async throws(APIError) -> ExerciseVideosResponse
}

extension APIClient: UebungsvideosLoading {}

/// Woher das Video einer Uebung kommt.
struct UebungsVideo: Equatable, Sendable {
    let url: URL
    /// Schluessel der Datei in der VideoAblage.
    let pfad: String
}

enum UebungsVideos {
    /// Uebung -> Quelle. Je Uebung, weil der Server je Uebung ein Video
    /// waehlt (eigenes vor Katalog).
    static func zuordnung(_ antwort: ExerciseVideosResponse) -> [String: UebungsVideo] {
        var videos: [String: UebungsVideo] = [:]
        for video in antwort.videos {
            guard let url = URL(string: video.url) else { continue }
            videos[video.exerciseId] = UebungsVideo(url: url, pfad: video.pfad)
        }
        return videos
    }

    /// Jeder Fehler endet leer: die Videos sind Zugabe, die Liste
    /// funktioniert ohne sie aus dem Prefetch.
    static func laden(von loader: any UebungsvideosLoading) async -> [String: UebungsVideo] {
        guard let antwort = try? await loader.exerciseVideos() else { return [:] }
        return zuordnung(antwort)
    }
}

/// Die Videoquellen des Training-Tabs, geteilt von Liste, Geraeteseite und
/// Satzseite (Testnotiz 11.10., #1, #5, #7).
///
/// Lebt an der Wurzel wie der VorschauLader: die Liste wird bei jedem
/// Geraet neu geoeffnet, die Dateien sollen dabei bleiben.
@MainActor @Observable
final class UebungsVideoVorrat {
    private(set) var quellen: [String: UebungsVideo] = [:]
    @ObservationIgnored let ablage: VideoAblage

    init(ablage: VideoAblage = VideoAblage()) {
        self.ablage = ablage
    }

    /// Ein leeres Ergebnis (offline) laesst die alten Quellen stehen: die
    /// Dateien liegen schon auf der Platte, nur die Signaturen sind alt.
    func laden(von loader: any UebungsvideosLoading) async {
        let neu = await UebungsVideos.laden(von: loader)
        if !neu.isEmpty { quellen = neu }
    }

    func datei(exerciseId: String) async -> URL? {
        await ablage.datei(exerciseId: exerciseId, quelle: quellen[exerciseId])
    }
}
