// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "FledgeWalletConnectSwift",
    platforms: [
        .macOS(.v10_14), .iOS(.v11),
    ],
    products: [
        .library(
            name: "FledgeWalletConnectSwift",
            targets: ["FledgeWalletConnectSwift"])
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", .upToNextMinor(from: "1.4.0")),
        .package(url: "https://github.com/daltoniam/Starscream.git", .upToNextMinor(from: "3.1.0"))
    ],
    targets: [
        .target(
            name: "FledgeWalletConnectSwift", 
            dependencies: ["CryptoSwift", "Starscream"],
            path: "Sources"),
//        .testTarget(name: "WalletConnectSwiftTests", dependencies: ["WalletConnectSwift"], path: "Tests"),
    ],
    swiftLanguageVersions: [.v5]
)
