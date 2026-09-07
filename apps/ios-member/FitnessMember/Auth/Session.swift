import Foundation

/// Eigener, schlanker Session-Typ statt Supabase.Session direkt durch die
/// App zu reichen -- entkoppelt SessionStore und alle Screens vom SDK-Typ.
struct Session: Equatable, Sendable {
    let accessToken: String
    let userId: String
    let email: String
    let expiresAt: Date
}
