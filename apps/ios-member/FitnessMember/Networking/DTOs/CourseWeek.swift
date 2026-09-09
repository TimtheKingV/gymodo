import Foundation

/// Deckt CourseWeekSession aus packages/domain/src/courses.ts Feld fuer
/// Feld -- ein Tippfehler hier scheitert erst beim Dekodieren zur
/// Laufzeit, nicht schon beim Uebersetzen.
struct CourseWeekSession: Codable, Equatable, Identifiable {
    var id: String { sessionId }

    let sessionId: String
    let templateId: String
    let name: String
    let description: String?
    /// ISO 8601, UTC. Fuer die Anzeige in der Studio-Zeitzone: KursZeit.
    let startsAt: String
    let localDay: String
    let durationMin: Int
    let capacity: Int
    let room: String?
    let instructorName: String?
    /// "planned" | "cancelled" (courses.ts).
    let status: String
    let bookedCount: Int
    let waitlistCount: Int
    let freeSeats: Int
    /// "booked" | "waitlisted" | nil.
    let ownStatus: String?
    let ownBookingId: String?
    let ownWaitlistPosition: Int?
}

/// Der Wochenplan eines Studios (courses.ts CourseWeek). Codable statt nur
/// Decodable -- Aufgabe 8 schreibt die eigenen Buchungen auf Platte.
struct CourseWeek: Codable, Equatable {
    let from: String
    let to: String
    let timezone: String
    /// studios.cancellation_deadline_hours -- je Studio verschieden, kommt
    /// deshalb mit statt geraten zu werden (courses.ts Kommentar).
    let cancellationDeadlineHours: Int
    let sessions: [CourseWeekSession]
}

/// Anfrage-Rumpf fuer PUT course-sessions/{sessionId}/booking. Die Route
/// (apps/web/app/api/v1/course-sessions/[sessionId]/booking/route.ts)
/// verlangt bookingId zwingend im Rumpf und antwortet sonst mit
/// 422 validation_failed -- der Server erzeugt sie nicht selbst.
struct BookingWrite: Encodable {
    let bookingId: String
}

/// Antwort von PUT course-sessions/{sessionId}/booking (courses.ts
/// BookOutcome).
struct BookOutcome: Decodable, Equatable {
    /// "booked" | "waitlisted".
    let result: String
    let created: Bool
    let bookingId: String
    let waitlistPosition: Int?
    let freeSeats: Int
}

/// Antwort von DELETE course-sessions/{sessionId}/booking (courses.ts
/// CancelOutcome).
///
/// Die Antwort traegt ausserdem `promotedUserId` -- die Kennung des
/// Mitglieds, das durch diese Stornierung von der Warteliste nachgerueckt
/// ist. Sie steht hier bewusst NICHT: was der Client nicht braucht, soll
/// er nicht halten. Kein Screen liest sie, und ein unbenanntes Feld
/// dekodiert Codable ohnehin nicht -- damit liegt die Kennung eines
/// anderen Mitglieds nicht einmal voruebergehend im Speicher dieser App.
struct CancelOutcome: Decodable, Equatable {
    let promoted: Bool
}
