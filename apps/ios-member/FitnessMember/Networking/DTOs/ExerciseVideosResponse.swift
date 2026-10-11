import Foundation

/// Signierte Uebungsvideos aus `GET /me/exercise-videos` (Testnotiz 11.10.,
/// #1). `pfad` ist der Speicherpfad: die URL wechselt mit jeder Signatur,
/// der Pfad erst, wenn das Video ersetzt wird.
struct ExerciseVideosResponse: Decodable, Equatable, Sendable {
    struct Video: Decodable, Equatable, Sendable {
        let exerciseId: String
        let url: String
        let pfad: String
    }
    let videos: [Video]
}
