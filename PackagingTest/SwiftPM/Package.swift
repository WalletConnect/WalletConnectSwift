// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "WalletConnectSwiftSwiftPM",
        platforms: [
        .iOS(.v12),
    ],
    products: [
        .library(
            name: "WalletConnectSwiftSwiftPM",
            targets: ["WalletConnectSwiftSwiftPM"])
    ],
    dependencies: [
        .package(url: "https://github.com/gnosis/WalletConnectSwift.git", .branch("feature/GH-6-packaging"))
    ],
    targets: [
        .target(
            name: "WalletConnectSwiftSwiftPM",
            dependencies: ["WalletConnectSwift"]
        )
    ]
)
