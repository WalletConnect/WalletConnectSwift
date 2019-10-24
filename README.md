# WalletConnectSwift

Swift SDK implementing WalletConnect 1.0.0 protocol for native iOS Dapps and Wallets.

# Features

- Server (wallet)
  - Create, reconnect, disconnect, and update session
  - Flexible, extendable request handling with `Codable` support via JSON RPC 2.0
  - Example App:
    - Connecting via QR code reader
    - Connecting via deep link ("wc" scheme)
    - Reconnecting after restart
    - Examples of request handlers

- Client (native dapp)
  - Create, reconnect, disconnect, and update session
  - Default implementation of [WalletConnect SDK API](https://docs.walletconnect.org/json-rpc/ethereum)
    - `personal_sign`
    - `eth_sign`
    - `eth_signTypedData`
    - `eth_sendTransaction`
    - `eth_signTransaction`
    - `eth_sendRawTransaction`
  - Send custom RPC requests with `Codable` support via JSON RPC 2.0
  - Example App:
    - Generating QR-code with WC URL
    - Connecting via deep link
    - Reconnecting after restart
    - WalletConnect SDK requests
    - Custom request (Ethereum JSON RPC)

## Usage in a Wallet

To start connections, you need to create and retain a `Server` object to which you provide a delegate:

```Swift
let server = Server(delegate: self)
```

The library handles WalletConnect-specific session requests for you - `wc_sessionRequest` and `wc_sessionUpdate`. 

To register for the important session update events, implement the delegate methods `shouldStart`, `didConnect`, `didDisconnect` and `didFailToConnect`.

By default, the server cannot handle any other reqeusts - you need to provide your implementation.

You do this by registering request handlers. You have the flexibility to register one handler per request method, or a catch-all request handler.


```Swift
server.register(handler: PersonalSignHandler(for: self, server: server, wallet: wallet))
```

Handlers are asked (in order of registration) whether they can handle each request. First handler that returns `true` from `canHandle(request:)` method will get the `hanlde(request:)` call. All other handlers will be skipped.

In the request handler, check the incoming request's method in `canHandle` implementation, and handle actual request in the `handle(request:)` implementation.

```Swift
func canHandle(request: Request) -> Bool {
   return request.method == "eth_signTransaction"
}
```

You can send back response for the request through the server using `send` method:

```Swift
func handle(request: Request) {
  // do you stuff here ...
  
  // error response - rejected by user
  server.send(.reject(request))

  // or send actual response - assuming the request.id exists, and MyCodableStruct type defined
  try server.send(Response(url: request.url, value: MyCodableStruct(value: "Something"), id: request.id!))
}
```

For more details, see the `ServerExample` app.


## Usage in a Dapp

To start connections, you need to create and keep alive a `Client` object to which you provide `DappInfo` and a delegate:

```Swift
let client = Client(delegate: self, dAppInfo: dAppInfo)
```

The delegate then will receive calls when connection established, failed, or disconnected.

Upon successful connection, you can invoke various API methods on the `Client`.

```Swift
try? client.personal_sign(url: session.url, message: "Hi there!", account: session.walletInfo!.accounts[0]) {
      [weak self] response in
      // handle the response from Wallet here
  }
```

You can also send a custom request. The request ID required by JSON RPC is generated and handled by the library internally.

```Swift
try? client.send(Request(url: url, method: "eth_gasPrice")) { [weak self] response in
    // handle the response
}
```

You can convert the received response result to a `Decodable` type.

```Swift
let nonceString = try response.result(as: String.self)
```

You can also check if the wallet responded with error:

```Swift
if let error = response.error { // NSError
  // handle error
}
```

For more details, see the `ClientExample` app.

# Running Example Apps

Please initialize submodules before running the example apps:

```
git submodule update --init
```

After that, open `WalletConnectSwift.xcodeproj` and select `ClientExample` or `ServerExample` target to run in Simulator or on your device.

# Installation

## Prerequisites

- iOS 11.0 or macOS 10.14
- Xcode 10.3
- Swift 5

## Manual

Add this repository as a submodule:

```
git submodule add https://github.com/WalletConnect/WalletConnectSwift.git
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

## CocoaPods

You can use CocoaPods

    platform :ios, '11.0'
    use_frameworks!

    target 'MyApp' do
      pod 'WalletConnectSwift'
    end

## Carthage

You can use Carthage. In your `Cartfile`:

    github "WalletConnect/WalletConnectSwift"

Run `carthage update` to build the framework and drag the WalletConnectSwift.framework in your Xcode project.

## Swift Package Manager

You can use Swift Package Manager and add dependency in your `Package.swift`:

    dependencies: [
        .package(url: "https://github.com/WalletConnect/WalletConnectSwift.git", .upToNextMinor(from: "1.0.0"))
    ]

# Acknowledgments

We'd like to thank [Trust Wallet](https://github.com/trustwallet/wallet-connect-swift) team for inspiration in imlpementing this library.

# Contributors

* Andrey Scherbovich ([sche](https://github.com/sche))
* Dmitry Bespalov ([DmitryBespalov](https://github.com/DmitryBespalov))

# License

MIT License (see the LICENSE file).
