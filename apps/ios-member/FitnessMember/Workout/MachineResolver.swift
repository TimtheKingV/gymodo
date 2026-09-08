import CryptoKit
import Foundation

/// Token -> Geraet, lokal aus dem Prefetch.
///
/// M1-Spec SS8.1 Schritt 3: Der Prefetch enthaelt je Geraet den token_hash,
/// die App hat den Token aus der URL und hasht ihn selbst. Dadurch rendert
/// der Screen sofort, auch ohne Empfang.
///
/// Unbedenklich, weil Tag-Tokens oeffentliche Locator sind und Hashes keine
/// Tokens verraten. Der Token selbst wird nie gespeichert und nie
/// protokolliert (M1-Spec SS10.4/SS10.6).
enum MachineResolver {
    /// Muss byteweise zu packages/domain/src/tags.ts hashTagToken passen:
    /// sha256 ueber die UTF-8-Bytes, Hex in Kleinbuchstaben.
    static func hash(token: String) -> String {
        SHA256.hash(data: Data(token.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func maschine(
        fuerToken token: String,
        in bootstrap: BootstrapResponse
    ) -> BootstrapResponse.Machine? {
        let gesucht = hash(token: token)
        return bootstrap.machines.first { $0.tokenHashes.contains(gesucht) }
    }
}
