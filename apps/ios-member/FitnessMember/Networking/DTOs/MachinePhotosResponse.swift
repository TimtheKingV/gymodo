import Foundation

/// Signierte Geraetefotos aus `GET /me/machine-photos` (Aufgabe 3). Je
/// Modell eine URL, nicht je Geraet -- der Server signiert pro
/// equipmentModel, zwei Geraete desselben Modells teilen sich ein Foto.
struct MachinePhotosResponse: Decodable, Equatable, Sendable {
    struct Photo: Decodable, Equatable, Sendable {
        let equipmentModelId: String
        let url: String
    }
    let photos: [Photo]
}
