// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "WalletConnectSwift",
    platforms: [
        .macOS(.v10_14), .iOS(.v13),
    ],
    products: [
        .library(
            name: "WalletConnectSwift",
            targets: ["WalletConnectSwift"])
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", .upToNextMinor(from: "1.5.1"))
    ],
    targets: [
        .target(
            name: "WalletConnectSwift", 
            dependencies: ["CryptoSwift"],
            path: "Sources"),
        .testTarget(name: "WalletConnectSwiftTests", dependencies: ["WalletConnectSwift"], path: "Tests"),
    ],
    swiftLanguageVersions: [.v5]
)
