Pod::Spec.new do |spec|
  spec.name         = "WalletConnectSwift"
  spec.version      = "1.6.0"
  spec.summary      = "A delightful way to integrate WalletConnect into your app."
  spec.description  = <<-DESC
  WalletConnect protocol implementation for enabling communication between dapps and
  wallets. This library provides both client and server parts so that you can integrate
  it in your wallet, or in your dapp - whatever you are working on.
                   DESC
  spec.homepage     = "https://github.com/WalletConnect/WalletConnectSwift"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author             = { "Andrey Scherbovich" => "andrey@gnosis.io", "Dmitry Bespalov" => "dmitry.bespalov@gnosis.io" }
  spec.cocoapods_version = '>= 1.4.0'
  spec.platform     = :ios, "11.0"
  spec.swift_version = "5.0"
  spec.source       = { :git => "https://github.com/WalletConnect/WalletConnectSwift.git", :tag => "#{spec.version}" }
  spec.source_files  = "Sources/**/*.swift"
  spec.requires_arc = true
  spec.dependency "CryptoSwift", "~> 1.4"
  spec.dependency "Starscream", "~> 3.1"
end
