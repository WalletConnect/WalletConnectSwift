# WalletConnectSwift

An SDK implementing WalletConnect 1.0.0 protocol for iOS.

# Installation

Add this repository as a submodule:

```
git submodule add https://github.com/gnosis/WalletConnectSwift.git
```

Fetch the dependencies

```
cd WalletConnectSwift
git submodule update --init
```

Dependencies of the WalletCnonectSwift library:
- CryptoSwift - for cryptography operations
- Starscream - for WebSocket operations prior to iOS 13

Dependencies of the ServerExample app:
- CryptoEthereumSwift
- EthereumKit

Drag and drop the `WalletConnectSwift.xcodeproj` in your project and link the
`WalletConnectSwift` static library.

# Contributors

* Andrey Scherbovich ([sche](https://github.com/sche))
* Dmitry Bespalov ([DmitryBespalov](https://github.com/DmitryBespalov))

# License

MIT License (see the LICENSE file).
