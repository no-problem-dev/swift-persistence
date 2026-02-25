// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-persistence",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PersistenceCore", targets: ["PersistenceCore"]),
        .library(name: "PersistenceUserDefaults", targets: ["PersistenceUserDefaults"]),
        .library(name: "PersistenceKeychain", targets: ["PersistenceKeychain"]),
        .library(name: "PersistenceFileSystem", targets: ["PersistenceFileSystem"]),
        .library(name: "PersistenceTesting", targets: ["PersistenceTesting"]),
    ],
    targets: [
        // Layer 0: Protocols + Error types (Foundation only)
        .target(name: "PersistenceCore"),

        // Layer 1: Concrete implementations
        .target(name: "PersistenceUserDefaults", dependencies: ["PersistenceCore"]),
        .target(name: "PersistenceKeychain", dependencies: ["PersistenceCore"]),
        .target(name: "PersistenceFileSystem", dependencies: ["PersistenceCore"]),

        // Layer 1: Test doubles
        .target(name: "PersistenceTesting", dependencies: ["PersistenceCore"]),

        // Tests
        .testTarget(
            name: "PersistenceUserDefaultsTests",
            dependencies: ["PersistenceUserDefaults", "PersistenceCore"]
        ),
        .testTarget(
            name: "PersistenceKeychainTests",
            dependencies: ["PersistenceKeychain", "PersistenceCore"]
        ),
        .testTarget(
            name: "PersistenceFileSystemTests",
            dependencies: ["PersistenceFileSystem", "PersistenceCore"]
        ),
        .testTarget(
            name: "PersistenceTestingTests",
            dependencies: ["PersistenceTesting", "PersistenceCore"]
        ),
    ]
)
