// swift-tools-version: 6.0
import PackageDescription

// Grundtypen fuer erkannte Koerper-Skelette und das Dateiformat fuer
// Skelettfolgen. Eigenes Package wie Sensorik: laeuft mit `swift test` auf dem
// Mac, ohne Simulator. Die Targets KoerperErkennung und skelette-rechnen
// kommen spaeter dazu.
let package = Package(
    name: "Koerperbild",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Koerperbild", targets: ["Koerperbild"])],
    dependencies: [.package(path: "../Sensorik")],
    targets: [
        .target(name: "Koerperbild", dependencies: [.product(name: "Sensorik", package: "Sensorik")]),
        .testTarget(name: "KoerperbildTests", dependencies: ["Koerperbild"]),
    ]
)
