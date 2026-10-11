import Foundation

/// Die Aufnahmen liegen im Repo, nicht im Testbundle: sie wachsen mit jedem
/// Training, und `swift test` soll immer den aktuellen Stand lesen, ohne
/// dass jemand Ressourcen nachpflegt.
enum Pfade {
    /// .../apps/ios-member/Packages/Sensorik/Tests/SensorikTests/Pfade.swift -> Repo-Wurzel
    static let repo: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // SensorikTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // Sensorik
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // ios-member
        .deletingLastPathComponent() // apps
        .deletingLastPathComponent() // Repo

    static let aufnahmen = repo.appendingPathComponent("data/sensoraufnahmen")

    /// Das verbindliche Beispiel aus Spec A 6 bleibt bei den App-Tests liegen
    /// (AbspielSensorQuelleTests liest es als Bundle-Ressource).
    static let beispiel = repo.appendingPathComponent(
        "apps/ios-member/FitnessMemberTests/Fixtures/sensoraufnahme-beispiel")
}
