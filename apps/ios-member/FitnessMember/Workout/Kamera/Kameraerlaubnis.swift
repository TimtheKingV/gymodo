import AVFoundation

/// Stand der Kamera-Erlaubnis; `.verweigert` schliesst `.restricted` ein.
enum Kameraerlaubnis: Equatable {
    case offen, erlaubt, verweigert

    static var aktuell: Kameraerlaubnis {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .erlaubt
        case .notDetermined: .offen
        case .denied, .restricted: .verweigert
        @unknown default: .verweigert
        }
    }

    /// Fragt nur beim ersten Mal; sonst gilt der gespeicherte Stand.
    static func anfragen() async -> Kameraerlaubnis {
        if aktuell == .offen { _ = await AVCaptureDevice.requestAccess(for: .video) }
        return aktuell
    }
}
