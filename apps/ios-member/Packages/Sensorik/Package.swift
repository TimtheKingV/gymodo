// swift-tools-version: 6.0
import PackageDescription

// Eigenes Package statt Ordner im App-Target (Sensor-Spec B 5.1): die
// Zaehler-Iterationen laufen mit `swift test` auf dem Mac in Sekunden,
// ohne Simulator und ohne einen xcodebuild, der parallele Sessions blockiert.
let package = Package(
    name: "Sensorik",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Sensorik", targets: ["Sensorik"])],
    targets: [
        .target(name: "Sensorik"),
        .testTarget(name: "SensorikTests", dependencies: ["Sensorik"]),
    ]
)
