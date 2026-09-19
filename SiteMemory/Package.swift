// swift-tools-version: 5.9
import PackageDescription

// SiteMemory is a self-contained Swift package.
//
// It is deliberately split into a portable, framework-free core and thin,
// platform-specific adapters. That boundary is what lets the same code either
// be embedded into the existing FieldReport app or shipped as a standalone
// product — nothing in `SiteMemoryCore` imports UIKit, SwiftUI, Vision or
// ARKit, so it compiles and unit-tests on any platform, and the Apple-only
// capabilities live behind protocols that the adapter targets implement.
let package = Package(
    name: "SiteMemory",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13) // Core + tests build here so CI does not need a simulator.
    ],
    products: [
        // Pure domain + geometry + protocols. Foundation only.
        .library(name: "SiteMemoryCore", targets: ["SiteMemoryCore"]),
        // Local-first persistence (file + in-memory). No network, no accounts.
        .library(name: "SiteMemoryPersistence", targets: ["SiteMemoryPersistence"]),
        // On-device semantic photo search via the Vision framework.
        .library(name: "SiteMemoryVision", targets: ["SiteMemoryVision"]),
        // LiDAR / ARKit spatial anchors (the v2 "point the phone at the wall" story).
        .library(name: "SiteMemoryARKit", targets: ["SiteMemoryARKit"]),
        // Optional SwiftUI surface: capture flow + "behind this wall" overlay.
        .library(name: "SiteMemoryUI", targets: ["SiteMemoryUI"])
    ],
    dependencies: [
        // Intentionally empty. No third-party dependencies keeps the privacy
        // story ("no data leaves the device") auditable and App-Store simple.
    ],
    targets: [
        .target(name: "SiteMemoryCore"),
        .target(
            name: "SiteMemoryPersistence",
            dependencies: ["SiteMemoryCore"]
        ),
        .target(
            name: "SiteMemoryVision",
            dependencies: ["SiteMemoryCore"]
        ),
        .target(
            name: "SiteMemoryARKit",
            dependencies: ["SiteMemoryCore"]
        ),
        .target(
            name: "SiteMemoryUI",
            dependencies: ["SiteMemoryCore"]
        ),
        .testTarget(
            name: "SiteMemoryCoreTests",
            dependencies: ["SiteMemoryCore"]
        )
    ]
)
