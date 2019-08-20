# WalletConnectSwift

An SDK implementing WalletConnect 1.0.0 protocol for iOS.

# Installation

## Manual

Add this repository as a submodule:

```
git submodule add https://github.com/gnosis/WalletConnectSwift.git
```

Fetch the dependencies

```
cd WalletConnectSwift
git submodule update --init
```

Drag and drop the `WalletConnectSwift.xcodeproj` in your project and link the
`WalletConnectSwift` static library.

## CocoaPods

You can use CocoaPods

    platform :ios, '12.0'
    use_frameworks!

    target 'MyApp' do
      pod 'WalletConnectSwift'
    end

## Carthage

You can use Carthage. In your `Cartfile`:

    github "gnosis/WalletConnectSwift"

Run `carthage` to build the framework and drag the WalletConnectSwift.framework in your Xcode project.

## Swift Package Manager

You can use Swift Package Manager and add dependency in your `Package.swift`:

    dependencies: [
        .package(url: "https://github.com/gnosis/WalletConnectSwift.git", .upToNextMinor(from: "1.0.0"))
    ]

# Contributors

* Andrey Scherbovich ([sche](https://github.com/sche))
* Dmitry Bespalov ([DmitryBespalov](https://github.com/DmitryBespalov))

# License

MIT License (see the LICENSE file).
