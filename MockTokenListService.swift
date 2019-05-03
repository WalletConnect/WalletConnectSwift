//
//  Copyright © 2018 Gnosis Ltd. All rights reserved.
//

import Foundation
import MultisigWalletDomainModel
import Common
import CommonTestSupport

public final class MockTokenListService: TokenListDomainService {

    public var shouldThrow = false
    public var didReturnItems = false

    public init() {}

    public var json = TokenListTestResponse.json
    public func items() throws -> [TokenListItem] {
        if shouldThrow {
            throw TestError.error
        }
        let data = json.data(using: .utf8)!
        Timer.wait(0.2)
        didReturnItems = true
        let results = try JSONDecoder().decode(TokenList.self, from: data).results
        return results
    }
}

// swiftlint:disable line_length
fileprivate struct TokenListTestResponse {

    static let json = """
{
  "count": 152,
  "next": null,
  "previous": null,
  "results": [
    {
      "address": "0xB98d4C97425d9908E66E53A6fDf673ACcA0BE986",
      "logoUri": "https://raw.githubusercontent.com/rmeissner/crypto_resources/master/tokens/mainnet/icons/0xB98d4C97425d9908E66E53A6fDf673ACcA0BE986.png",
      "default": true,
      "name": "ArcBlock Token",
      "symbol": "ABT",
      "description": "An open source protocol that provides an abstract layer for accessing underlying blockchains, enabling your application to work on different blockchains.",
      "decimals": 18,
      "websiteUri": "https://www.arcblock.io",
      "gas": false,
      "priceOracles": []
    },
    {
      "address": "0x5CA9a71B1d01849C0a95490Cc00559717fCF0D1d",
      "logoUri": "https://raw.githubusercontent.com/rmeissner/crypto_resources/master/tokens/mainnet/icons/0x5CA9a71B1d01849C0a95490Cc00559717fCF0D1d.png",
      "default": false,
      "name": "aeternity",
      "symbol": "AE",
      "description": "Scalable smart contracts interfacing with real world data.",
      "decimals": 18,
      "websiteUri": "https://www.aeternity.com/",
      "gas": false,
      "priceOracles": []
    },
    {
      "address": "0x8eB24319393716668D768dCEC29356ae9CfFe285",
      "logoUri": "https://raw.githubusercontent.com/rmeissner/crypto_resources/master/tokens/mainnet/icons/0x8eB24319393716668D768dCEC29356ae9CfFe285.png",
      "default": true,
      "name": "SingularityNET",
      "symbol": "AGI",
      "description": "Decentralized Marketplace for AI.",
      "decimals": 8,
      "websiteUri": "https://singularitynet.io",
      "gas": false,
      "priceOracles": []
    },
    {
      "address": "0x4CEdA7906a5Ed2179785Cd3A40A69ee8bc99C466",
      "logoUri": "https://raw.githubusercontent.com/rmeissner/crypto_resources/master/tokens/mainnet/icons/0x4CEdA7906a5Ed2179785Cd3A40A69ee8bc99C466.png",
      "default": true,
      "name": "Aion",
      "symbol": "AION",
      "description": "A multi-tier blockchain system designed to address unsolved questions of scalability, privacy, and interoperability in blockchain networks",
      "decimals": 8,
      "websiteUri": "https://aion.network/",
      "gas": false,
      "priceOracles": []
    },
    {
      "address": "0x4DC3643DbC642b72C158E7F3d2ff232df61cb6CE",
      "logoUri": "https://raw.githubusercontent.com/rmeissner/crypto_resources/master/tokens/mainnet/icons/0x4DC3643DbC642b72C158E7F3d2ff232df61cb6CE.png",
      "default": false,
      "name": "Amber Token",
      "symbol": "AMB",
      "description": "Combining high-tech sensors, blockchain protocol and smart contracts, we are building a universally verifiable, community-driven ecosystem to assure the quality, safety & origins of products.",
      "decimals": 18,
      "websiteUri": "https://ambrosus.com/index.html",
      "gas": false,
      "priceOracles": []
    },
    {
      "address": "0x960b236A07cf122663c4303350609A66A7B288C0",
      "logoUri": "https://raw.githubusercontent.com/rmeissner/crypto_resources/master/tokens/mainnet/icons/0x960b236A07cf122663c4303350609A66A7B288C0.png",
      "default": false,
      "name": "ANT",
      "symbol": "ANT",
      "description": "Create and manage unstoppable organizations. Aragon lets you manage entire organizations using the blockchain. This makes Aragon organizations more efficient than their traditional counterparties.",
      "decimals": 18,
      "websiteUri": "https://aragon.one/network",
      "gas": false,
      "priceOracles": []
    },
    {
      "address": "0x9ab165D795019b6d8B3e971DdA91071421305e5a",
      "logoUri": "https://raw.githubusercontent.com/rmeissner/crypto_resources/master/tokens/mainnet/icons/0x9ab165D795019b6d8B3e971DdA91071421305e5a.png",
      "default": false,
      "name": "Aurora",
      "symbol": "AOA",
      "description": "Aurora Chain offers intelligent application isolation and enables multi-chain parallel expansion to create an extremely high TPS with security maintain.",
      "decimals": 18,
      "websiteUri": "https://www.aurorachain.io/",
      "gas": false,
      "priceOracles": []
    },
    {
      "address": "0x4C0fBE1BB46612915E7967d2C3213cd4d87257AD",
      "logoUri": "https://raw.githubusercontent.com/rmeissner/crypto_resources/master/tokens/mainnet/icons/0x4C0fBE1BB46612915E7967d2C3213cd4d87257AD.png",
      "default": false,
      "name": "APIS",
      "symbol": "APIS",
      "description": "Key currency of masternode coin & the first masternode mediation.",
      "decimals": 18,
      "websiteUri": "https://apisplatform.io",
      "gas": false,
      "priceOracles": []
    }]
}
"""
}
