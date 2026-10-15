import Foundation
import Observation

/// Was die Uebungsvideos vom Netz brauchen -- eine schmale Fassade wie
/// GeraetefotosLoading, damit die Zuordnung ohne APIClient pruefbar bleibt.
protocol UebungsvideosLoading: Sendable {
    func exerciseVideos() async throws(APIError) -> ExerciseVideosResponse
}

extension APIClient: UebungsvideosLoading {}

/// Woher eine Datei der Medienablage kommt -- Video einer Uebung oder
/// Foto eines Geraets.
struct Medienquelle: Equatable, Sendable {
    let url: URL
    /// Schluessel der Datei in der Medienablage.
    let pfad: String
}

enum UebungsVideos {
    /// Uebung -> Quelle. Je Uebung, weil der Server je Uebung ein Video
    /// waehlt (eigenes vor Katalog).
    static func zuordnung(_ antwort: ExerciseVideosResponse) -> [String: Medienquelle] {
        var videos: [String: Medienquelle] = [:]
        for video in antwort.videos {
            guard let url = URL(string: video.url) else { continue }
            videos[video.exerciseId] = Medienquelle(url: url, pfad: video.pfad)
        }
        return videos
    }

    /// Die Quelle fuer die Einweisung: der Vorrat zuerst, sonst die URL aus
    /// dem Geraetekontext (Testnotiz 11.10., #7). Deren Pfad ohne Token ist
    /// der Schluessel -- er wechselt nicht mit jeder Signatur.
    static func quelle(vorrat: Medienquelle?, kontextURL: URL?) -> Medienquelle? {
        if let vorrat { return vorrat }
        return kontextURL.map { Medienquelle(url: $0, pfad: $0.path) }
    }

    /// Jeder Fehler endet leer: die Videos sind Zugabe, die Liste
    /// funktioniert ohne sie aus dem Prefetch.
    static func laden(von loader: any UebungsvideosLoading) async -> [String: Medienquelle] {
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
    private(set) var quellen: [String: Medienquelle] = [:]
    @ObservationIgnored let ablage: Medienablage

    @ObservationIgnored private let istOnline: @MainActor () -> Bool
    @ObservationIgnored private var vorladen: Task<Void, Never>?

    init(ablage: Medienablage = Medienablage(), istOnline: @escaping @MainActor () -> Bool = { true }) {
        self.ablage = ablage
        self.istOnline = istOnline
    }

    /// Ein leeres Ergebnis (offline) laesst die alten Quellen stehen: die
    /// Dateien liegen schon auf der Platte, nur die Signaturen sind alt.
    func laden(von loader: any UebungsvideosLoading) async {
        let neu = await UebungsVideos.laden(von: loader)
        if !neu.isEmpty {
            quellen = neu
            vorladenStarten()
        }
    }

    /// Holt alle Schleifen, die noch nicht auf der Platte liegen -- die erste
    /// Einweisung an einem Geraet ist sonst genau die, die im Keller kein
    /// Video hat (Offline-Spec 3d). Nacheinander, niedrige Prioritaet, auch
    /// ueber Mobilfunk (~35 KB je Video). Offline bricht es ab; der naechste
    /// erfolgreiche Abruf der Quellen startet es neu.
    private func vorladenStarten() {
        guard vorladen == nil else { return }
        let liste = quellen.sorted { $0.key < $1.key }
        vorladen = Task(priority: .background) { @MainActor [weak self] in
            for (exerciseId, quelle) in liste {
                guard let self, !Task.isCancelled, self.istOnline() else { break }
                _ = await self.ablage.datei(schluessel: exerciseId, quelle: quelle)
            }
            self?.vorladen = nil
        }
    }

    /// Nur fuer Tests: wartet, bis das Vorladen durch ist.
    func vorladenAbwarten() async {
        await vorladen?.value
    }

    func datei(exerciseId: String, ersatz: URL? = nil) async -> URL? {
        await ablage.datei(schluessel: exerciseId,
                           quelle: UebungsVideos.quelle(vorrat: quellen[exerciseId], kontextURL: ersatz))
    }
}
