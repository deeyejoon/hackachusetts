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
        ),
        // iOS-only integrations (CoreBluetooth, UserNotifications, ReplayKit, Vision).
        // Lives in its own target because these frameworks are unavailable on macOS,
        // where PulseCore + the tests + PulseDemo must still build and run.
        .library(
            name: "PulseKit",
            targets: ["PulseKit"]
        ),
        .executable(
            name: "PulseDemo",
            targets: ["PulseDemo"]
        )
    ],
    targets: [
        .target(
            name: "PulseCore",
            dependencies: []
        ),
        .target(
            name: "PulseKit",
            dependencies: ["PulseCore"]
        ),
        .executableTarget(
            name: "PulseDemo",
            dependencies: ["PulseCore"]
        ),
        .testTarget(
            name: "PulseCoreTests",
            dependencies: ["PulseCore"]
        )
    ]
)
