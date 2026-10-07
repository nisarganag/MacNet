// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacNet",
    // Liquid Glass (`glassEffect`, `GlassEffectContainer`) is macOS 26+, and
    // the whole panel is built from it, so there is no older fallback path.
    platforms: [.macOS("26.0")],
    targets: [
        .target(name: "MacNetCore"),
        .executableTarget(name: "MacNet", dependencies: ["MacNetCore"]),
        .testTarget(
            name: "MacNetCoreTests",
            dependencies: ["MacNetCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
