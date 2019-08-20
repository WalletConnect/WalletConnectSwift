// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "WalletConnectSwift",
    platforms: [
        .iOS(.v12),
    ],
    products: [
        .library(
            name: "WalletConnectSwift",
            targets: ["WalletConnectSwift"])
    ],
    targets: [
        .target(name: "WalletConnectSwift"),
        .testTarget(name: "Tests", dependencies: ["WalletConnectSwift"]),
    ],
    swiftLanguageVersions: [.v5]
)