import AVFoundation

/// Die App macht keinen Ton -- und darf deshalb die Musik des Mitglieds
/// nie anhalten.
///
/// Die Standardkategorie soloAmbient unterbricht fremde Wiedergabe, sobald
/// irgendein AVPlayer spielt, auch stumm und ohne Tonspur: Spotify
/// verstummte beim Durchklicken der Uebungsvideos. Im Studio hoeren fast
/// alle Musik ueber Kopfhoerer.
enum AudioSitzung {
    static func einrichten() throws {
        // ambient mischt sich ohne Option unter fremde Wiedergabe und
        // duckt sie nicht.
        try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
    }
}
