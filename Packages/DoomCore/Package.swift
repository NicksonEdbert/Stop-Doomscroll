// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DoomCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "DoomCore", targets: ["DoomCore"]),
    ],
    targets: [
        .target(name: "DoomCore"),
        .testTarget(name: "DoomCoreTests", dependencies: ["DoomCore"]),
    ]
)
