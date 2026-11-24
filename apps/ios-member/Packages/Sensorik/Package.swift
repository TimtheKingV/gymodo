// swift-tools-version: 6.0
import PackageDescription

// Eigenes Package statt Ordner im App-Target (Sensor-Spec B 5.1): laeuft mit
// `swift test` auf dem Mac, ohne Simulator und ohne einen xcodebuild, der
// parallele Sessions blockiert. Gemessen am 24.11.2026: die ganze Suite (225
// Tests) braucht 157–260 s, je nach Last; die Berichte ueber alle Aufnahmen
// (Guete-, Takt- und Tempobericht) bestimmen die Dauer. Einzelne Iterationen
// mit `--filter` laufen in Sekunden.
let package = Package(
    name: "Sensorik",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Sensorik", targets: ["Sensorik"])],
    targets: [
        .target(name: "Sensorik"),
        .testTarget(name: "SensorikTests", dependencies: ["Sensorik"]),
    ]
)
