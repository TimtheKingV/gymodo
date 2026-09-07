import Foundation

enum AuthError: Error, Equatable {
    case invalidCredentials
    case network
    case unknown

    static func map(_ error: Error) -> AuthError {
        if error is URLError { return .network }
        return .invalidCredentials
    }
}
