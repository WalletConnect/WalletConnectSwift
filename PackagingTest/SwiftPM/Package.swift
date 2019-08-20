// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "WalletConnectSwiftSwiftPM",
        platforms: [
            .macOS(.v10_14), .iOS(.v12),
    ],
    products: [
        .library(
            name: "WalletConnectSwiftSwiftPM",
            targets: ["WalletConnectSwiftSwiftPM"])
    ],
    dependencies: [
        .package(url: "https://github.com/gnosis/WalletConnectSwift.git", .upToNextMinor("1.0.0"))
    ],
    targets: [
        .target(
            name: "WalletConnectSwiftSwiftPM",
            dependencies: ["WalletConnectSwift"],
            path: "Sources"
        )
    ],
    swiftLanguageVersions: [.v5]
)
