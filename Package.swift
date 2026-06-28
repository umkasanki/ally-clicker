// swift-tools-version: 5.9
import PackageDescription

// AllyClickerCore — the pure, platform-independent core of AllyClicker.
//
// This package contains ONLY the logic that has no macOS dependency: the
// DwellEngine state machine, the Settings model, persistence, and the port
// protocols. It builds and tests on any platform (including Linux/WSL).
//
// The macOS application itself lives in App/AllyClicker.xcodeproj and consumes
// this package as a local Swift Package dependency.

let package = Package(
    name: "AllyClickerCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AllyClickerCore", targets: ["AllyClickerCore"])
    ],
    targets: [
        .target(
            name: "AllyClickerCore",
            path: "Sources/AllyClickerCore"
        ),
        .testTarget(
            name: "AllyClickerTests",
            dependencies: ["AllyClickerCore"],
            path: "Tests/AllyClickerTests"
        )
    ]
)
