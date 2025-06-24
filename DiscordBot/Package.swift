// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "DiscordBot",
    platforms: [
        .macOS(.v12),
        .iOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.9.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0")
    ],
    targets: [
        .executableTarget(
            name: "DiscordBot",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Logging", package: "swift-log")
            ]
        )
    ]
)