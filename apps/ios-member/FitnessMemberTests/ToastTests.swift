import Foundation
import Testing
@testable import FitnessMember

/// Der kurze Hinweis nach "Training beenden" ohne Satz (Testnotiz 11.10.,
/// #8): er geht von selbst, statt bis zum Verlassen des Tabs stehen zu
/// bleiben.
struct ToastTests {
    private let start = Date(timeIntervalSince1970: 1_000)

    @Test func bleibtDreiSekundenSichtbar() {
        let toast = Toastmeldung(text: "Verworfen", ab: start)
        #expect(toast.sichtbar(jetzt: start))
        #expect(toast.sichtbar(jetzt: start.addingTimeInterval(2.9)))
    }

    @Test func gehtNachDreiSekundenVonSelbst() {
        let toast = Toastmeldung(text: "Verworfen", ab: start)
        #expect(!toast.sichtbar(jetzt: start.addingTimeInterval(3)))
    }

    /// Zweimal derselbe Text hintereinander ist ein neuer Hinweis: der
    /// Ablauf beginnt von vorn, sonst verschwaende der zweite sofort.
    @Test func gleicherTextSpaeterIstEinNeuerHinweis() {
        let erster = Toastmeldung(text: "Verworfen", ab: start)
        let zweiter = Toastmeldung(text: "Verworfen", ab: start.addingTimeInterval(10))
        #expect(erster != zweiter)
    }
}
