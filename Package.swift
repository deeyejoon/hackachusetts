// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PulseCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PulseCore",
            targets: ["PulseCore"]
        )
    ],
    targets: [
        .target(
            name: "PulseCore",
            dependencies: []
        ),
        .testTarget(
            name: "PulseCoreTests",
            dependencies: ["PulseCore"]
        )
    ]
)
