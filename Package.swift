// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MusicRouter",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MusicRouter",
            path: "Sources/MusicRouter"
        ),
        .testTarget(
            name: "MusicRouterTests",
            dependencies: ["MusicRouter"],
            path: "Tests/MusicRouterTests"
        ),
    ]
)
