// swift-tools-version: 6.0
import PackageDescription

// Grundtypen fuer erkannte Koerper-Skelette und das Dateiformat fuer
// Skelettfolgen. Eigenes Package wie Sensorik: laeuft mit `swift test` auf dem
// Mac, ohne Simulator. KoerperErkennung kapselt Apples Vision, damit
// Koerperbild selbst kein Vision importiert; skelette-rechnen ist das
// Mac-Werkzeug, das die Katalogvideos zu Skelett-Dateien rechnet.
let package = Package(
    name: "Koerperbild",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Koerperbild", targets: ["Koerperbild"]),
        .library(name: "KoerperErkennung", targets: ["KoerperErkennung"]),
    ],
    dependencies: [.package(path: "../Sensorik")],
    targets: [
        .target(name: "Koerperbild", dependencies: [.product(name: "Sensorik", package: "Sensorik")]),
        // Modus 5 fuer diese beiden Targets: Vision und AVFoundation sind
        // noch nicht fuer die strenge Nebenlaeufigkeit von Modus 6 annotiert.
        .target(
            name: "KoerperErkennung", dependencies: ["Koerperbild"],
            swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(
            name: "skelette-rechnen", dependencies: ["Koerperbild", "KoerperErkennung"],
            swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "KoerperbildTests", dependencies: ["Koerperbild"]),
    ]
)
