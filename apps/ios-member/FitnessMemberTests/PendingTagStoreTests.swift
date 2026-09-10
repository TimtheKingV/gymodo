import Foundation
import Testing
@testable import FitnessMember

@Suite("PendingTagStore")
struct PendingTagStoreTests {
    @Test("haelt einen gueltigen Token, bis er verbraucht wird")
    func haeltToken() {
        let store = PendingTagStore()
        store.capture("abcdefghij0123456789AB")

        #expect(store.istOffen)
        #expect(store.token == "abcdefghij0123456789AB")
        #expect(store.consume() == .token("abcdefghij0123456789AB"))
        #expect(!store.istOffen)
        #expect(store.consume() == nil)
    }

    /// Der Fall, der bis M1 still verschwand: eine URL erreichte die App und
    /// wurde von TagLink abgelehnt. Sie muss anliegen wie ein gueltiger
    /// Eingang, damit der Training-Tab sie ueberhaupt beantworten kann.
    @Test("haelt einen abgelehnten Link als eigenen Zustand")
    func haeltUngueltig() {
        let store = PendingTagStore()
        store.captureUngueltig()

        #expect(store.istOffen)
        #expect(store.consume() == .ungueltig)
        #expect(!store.istOffen)
    }

    /// Das Banner auf LoginMailView verspricht, dass es nach dem Anmelden
    /// direkt zum Geraet geht. Ueber einem abgelehnten Link waere das
    /// gelogen -- deshalb liefert token dort nichts.
    @Test("token liefert bei einem abgelehnten Link nichts")
    func ungueltigIstKeinToken() {
        let store = PendingTagStore()
        store.captureUngueltig()

        #expect(store.token == nil)
    }

    @Test("ein zweiter Eingang ersetzt den ersten")
    func zweiterEingangErsetzt() {
        let store = PendingTagStore()
        store.capture("abcdefghij0123456789AB")
        store.capture("ZZZZZZZZZZ0123456789AB")

        #expect(store.consume() == .token("ZZZZZZZZZZ0123456789AB"))
    }
}
