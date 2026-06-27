// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AllyClicker",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic — DwellEngine state machine + settings model.
        // No macOS UI APIs, fully unit-testable.
        .target(
            name: "AllyClickerCore",
            path: "Sources/AllyClickerCore"
        ),
        // Main app — AppKit panel, CGEvent injection, settings UI.
        .executableTarget(
            name: "AllyClicker",
            dependencies: ["AllyClickerCore"],
            path: "Sources/AllyClicker"
        ),
        .testTarget(
            name: "AllyClickerTests",
            dependencies: ["AllyClickerCore"],
            path: "Tests/AllyClickerTests"
        )
    ]
)
