#if DEBUG
import AVFoundation
import Speech

/// Die Aufnahme ist der Beleg, das Transkript Komfort.
@MainActor
@Observable
final class Aufnahme {
    enum Erlaubnis { case offen, erteilt, verweigert }

    private(set) var erlaubnis: Erlaubnis = .offen
    private(set) var laeuft = false
    private(set) var datei: URL?
    private(set) var fehler: String?
    @ObservationIgnored private var rekorder: AVAudioRecorder?

    /// Erster Tipp fragt nach dem Mikrofon -- nicht beim App-Start.
    func umschalten() async {
        if laeuft {
            stoppen()
            return
        }
        if erlaubnis == .offen {
            let mikrofon = await AVAudioApplication.requestRecordPermission()
            // Ohne Spracherkennung wird trotzdem aufgenommen; nur das
            // Transkript fehlt dann.
            _ = await Self.spracherkennungErlauben()
            erlaubnis = mikrofon ? .erteilt : .verweigert
        }
        guard erlaubnis == .erteilt else { return }
        do {
            try starten()
        } catch {
            fehler = "Aufnahme ließ sich nicht starten: \(error.localizedDescription)"
        }
    }

    /// Uebergibt die Datei an die Ablage; danach gehoert sie nicht mehr hierher.
    func abgeben() -> URL? {
        stoppen()
        let ergebnis = datei
        datei = nil
        return ergebnis
    }

    func verwerfen() {
        stoppen()
        if let datei { try? FileManager.default.removeItem(at: datei) }
        datei = nil
    }

    private func starten() throws {
        if let datei { try? FileManager.default.removeItem(at: datei) }
        let sitzung = AVAudioSession.sharedInstance()
        try sitzung.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try sitzung.setActive(true)
        let ziel = FileManager.default.temporaryDirectory.appendingPathComponent("testnotiz-\(UUID().uuidString).m4a")
        let einstellungen: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let neu = try AVAudioRecorder(url: ziel, settings: einstellungen)
        guard neu.record() else {
            throw CocoaError(.fileWriteUnknown)
        }
        rekorder = neu
        datei = ziel
        laeuft = true
        fehler = nil
    }

    private func stoppen() {
        guard laeuft else { return }
        rekorder?.stop()
        rekorder = nil
        laeuft = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// nonisolated: der Callback kommt auf einer beliebigen Queue. Aus dem
    /// MainActor heraus geschrieben erbte die Closure dessen Isolation, und
    /// Swift 6 bricht beim Aufruf ab.
    nonisolated private static func spracherkennungErlauben() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { fortsetzung in
            SFSpeechRecognizer.requestAuthorization { fortsetzung.resume(returning: $0) }
        }
    }
}

enum Transkription {
    /// Nur auf dem Geraet: die Aufnahme verlaesst das Telefon nicht. Ohne
    /// deutsches On-Device-Modell nil.
    static func transkribieren(_ audio: URL) async -> String? {
        guard let erkenner = SFSpeechRecognizer(locale: Locale(identifier: "de-DE")),
              erkenner.isAvailable, erkenner.supportsOnDeviceRecognition
        else { return nil }
        let anfrage = SFSpeechURLRecognitionRequest(url: audio)
        anfrage.requiresOnDeviceRecognition = true
        anfrage.shouldReportPartialResults = false
        return await withCheckedContinuation { fortsetzung in
            // Der Callback kommt mehrfach; die Continuation darf genau einmal laufen.
            var erledigt = false
            erkenner.recognitionTask(with: anfrage) { ergebnis, fehler in
                guard !erledigt else { return }
                if let ergebnis, ergebnis.isFinal {
                    erledigt = true
                    fortsetzung.resume(returning: ergebnis.bestTranscription.formattedString)
                } else if fehler != nil {
                    erledigt = true
                    fortsetzung.resume(returning: nil)
                }
            }
        }
    }
}
#endif
