import CoreNFC
import Observation
import OSLog

/// Der aktive NFC-Scan -- das Gegenstueck zu QRScannerController im selben
/// Ordner.
///
/// Bis M1 gab es NFC nur passiv: iOS liest den Tag im Hintergrund, zeigt ein
/// Systembanner, und erst ein Tippen darauf oeffnet die App. Zwei Schritte,
/// wo einer reicht -- und beim Test war genau das der Stolperstein. Dieser
/// Leser oeffnet das native iOS-Blatt direkt aus der App heraus.
///
/// Der passive Weg bleibt daneben bestehen. Er haengt an den Associated
/// Domains, nicht an diesem Entitlement, und funktioniert weiterhin, ohne
/// dass die App offen ist.
@MainActor
@Observable
final class NFCTagLeser {
    /// Falsch auf iPads, aelteren iPhones und im Simulator. Die Knoepfe
    /// blenden sich dann aus, statt ins Leere zu greifen.
    static var verfuegbar: Bool { NFCNDEFReaderSession.readingAvailable }

    /// Der zuletzt aufgetretene Fehler, vom Aufrufer zu lesen und
    /// anzuzeigen. Abbruch und regulaeres Ende stehen hier nie drin.
    private(set) var fehler: String?

    /// Solange eine Sitzung laeuft, startet ein zweiter Tap keine weitere.
    private(set) var laeuft = false

    private var session: NFCNDEFReaderSession?
    private var delegat: Delegat?

    func starten(beiTreffer: @escaping (String) -> Void) {
        guard Self.verfuegbar, !laeuft else { return }
        fehler = nil

        // Der Delegat haelt sich selbst nicht: NFCNDEFReaderSession haelt ihn
        // stark, aber die Sitzung endet und gibt ihn frei. Deshalb liegt er
        // zusaetzlich hier, damit er nicht zwischen begin() und dem ersten
        // Callback verschwindet.
        let delegat = Delegat(
            beiURL: { [weak self] roh in
                self?.laeuft = false
                beiTreffer(roh)
            },
            beiEnde: { [weak self] meldung in
                self?.laeuft = false
                self?.fehler = meldung
            }
        )
        self.delegat = delegat

        let session = NFCNDEFReaderSession(delegate: delegat, queue: nil, invalidateAfterFirstRead: true)
        session.alertMessage = "Halt die Oberkante deines iPhones an den Aufkleber."
        self.session = session
        laeuft = true
        session.begin()
    }

    func fehlerQuittieren() {
        fehler = nil
    }

    /// Getrennt von NFCTagLeser, weil NFCNDEFReaderSessionDelegate eine
    /// NSObject-Klasse verlangt und seine Callbacks nebenlaeufig kommen --
    /// @MainActor und @Observable haetten hier beides nicht.
    private final class Delegat: NSObject, NFCNDEFReaderSessionDelegate, @unchecked Sendable {
        private let beiURL: @MainActor (String) -> Void
        private let beiEnde: @MainActor (String?) -> Void

        init(beiURL: @escaping @MainActor (String) -> Void, beiEnde: @escaping @MainActor (String?) -> Void) {
            self.beiURL = beiURL
            self.beiEnde = beiEnde
        }

        func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {}

        func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
            // wellKnownTypeURIPayload() loest den URI-Praefixcode selbst auf
            // (0x04 -> "https://"). Von Hand nachgebaut waere das eine
            // zweite Stelle, an der die Tabelle falsch sein kann.
            let url = messages
                .flatMap(\.records)
                .compactMap { $0.wellKnownTypeURIPayload() }
                .first

            guard let url else {
                TagProtokoll.log.error("NFC: NDEF ohne URI-Datensatz gelesen")
                Task { @MainActor [beiEnde] in
                    beiEnde("Auf diesem Aufkleber steht kein gymodo-Code.")
                }
                return
            }

            TagProtokoll.log.info("NFC gelesen: \(url.absoluteString, privacy: .public)")
            Task { @MainActor [beiURL] in beiURL(url.absoluteString) }
        }

        func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
            let meldung = Self.meldung(fuer: error)
            if meldung != nil {
                TagProtokoll.log.error("NFC abgebrochen: \(error.localizedDescription, privacy: .public)")
            }
            Task { @MainActor [beiEnde] in beiEnde(meldung) }
        }

        /// nil heisst: kein Fehler, der das Mitglied etwas angeht.
        private static func meldung(fuer error: Error) -> String? {
            guard let leserFehler = error as? NFCReaderError else {
                return "Der Aufkleber liess sich nicht lesen. Versuch es noch einmal."
            }
            switch leserFehler.code {
            case .readerSessionInvalidationErrorUserCanceled,
                 .readerSessionInvalidationErrorFirstNDEFTagRead:
                // Abbruch und regulaeres Ende nach dem ersten Treffer sind
                // der Normalfall, kein Fehler.
                return nil
            case .readerSessionInvalidationErrorSessionTimeout:
                return "Kein Aufkleber erkannt. Halt die Oberkante deines iPhones direkt an das gymodo-Zeichen."
            default:
                // Dieselbe neutrale Antwort wie fuer einen unbekannten Tag
                // (M1-Spec SS10.4): der Weg dahinter unterscheidet nicht,
                // also unterscheidet der Leser hier auch nicht.
                return "Der Aufkleber liess sich nicht lesen. Versuch es noch einmal."
            }
        }
    }
}
