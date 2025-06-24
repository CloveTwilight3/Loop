// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "DiscordBot",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/MahdiBM/DiscordBM.git", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.19.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.19.0")
    ],
    targets: [
        .executableTarget(
            name: "DiscordBot",
            dependencies: [
                .product(name: "DiscordBM", package: "DiscordBM"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Logging", package: "swift-log")
            ]
        )
    ]
)