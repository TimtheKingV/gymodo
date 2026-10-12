import AVFoundation
import Testing
@testable import FitnessMember

@Suite("AudioSitzung")
struct AudioSitzungTests {
    @Test("die App mischt sich unter fremde Musik statt sie zu unterbrechen")
    func mischtMitFremderMusik() throws {
        try AudioSitzung.einrichten()
        let sitzung = AVAudioSession.sharedInstance()
        #expect(sitzung.category == .ambient)
        #expect(sitzung.categoryOptions.contains(.duckOthers) == false)
    }
}
