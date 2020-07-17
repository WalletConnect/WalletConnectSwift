// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "WalletConnectSwift",
    platforms: [
        .macOS(.v10_15), .iOS(.v11),
    ],
    products: [
        .library(
            name: "WalletConnectSwift",
            targets: ["WalletConnectSwift"])
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", .upToNextMinor(from: "1.2.0")),
        .package(url: "https://github.com/daltoniam/Starscream.git", .upToNextMinor(from: "3.1.0"))
    ],
    targets: [
        .target(
            name: "WalletConnectSwift", 
            dependencies: ["CryptoSwift", "Starscream"],
            path: "Sources"),
        .testTarget(name: "WalletConnectSwiftTests", dependencies: ["WalletConnectSwift"], path: "Tests"),
    ],
    swiftLanguageVersions: [.v5]
)
