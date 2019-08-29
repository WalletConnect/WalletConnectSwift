//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import XCTest
@testable import WalletConnectSwift

class WCURLTests: XCTestCase {

    let string = "wc:topic@1?bridge=https%3A%2F%2Fexample.org%2F&key=key"

    func test_absoluteString() {
        let url = WCURL(topic: "topic", version: "1", bridgeURL: URL(string: "https://example.org/")!, key: "key")
        XCTAssertEqual(url.absoluteString, string)
    }

    func test_init() {
        XCTAssertNil(WCURL("gs://"))

        let emptyTopic = WCURL("wc:@1?bridge=https%3A%2F%2Fexample.org%2F&key=key")
        XCTAssertEqual(emptyTopic?.topic, "")

        let noTopic = WCURL("wc:1?bridge=https%3A%2F%2Fexample.org%2F&key=key")
        XCTAssertNil(noTopic)

        let noVersion = WCURL("wc:topic?bridge=https%3A%2F%2Fexample.org%2F&key=key")
        XCTAssertNil(noVersion)

        let withSlashes = WCURL("wc://topic@1?bridge=https%3A%2F%2Fexample.org%2F&key=key")
        XCTAssertEqual(withSlashes?.absoluteString, string)

        let noQuery = WCURL("wc:topic@1")
        XCTAssertNil(noQuery)

        let noBridgeKey = WCURL("wc:topic@1?key=key")
        XCTAssertNil(noBridgeKey)

        let bridgeNotURL = WCURL("wc:topic@1?bridge=&key=key")
        XCTAssertNil(bridgeNotURL)

        let noKey = WCURL("wc:topic@1?bridge=https%3A%2F%2Fexample.org%2F")
        XCTAssertNil(noKey)
    }

}
