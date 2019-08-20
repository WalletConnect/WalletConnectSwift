Pod::Spec.new do |spec|
  spec.name         = "WalletConnectSwift"
  spec.version      = "0.0.1"
  spec.summary      = "A delightful way to integrate the WallletConnect into your app."
  spec.description  = <<-DESC
  WalletConnect v1 protocol implementation for enabling communication between dapps and
  wallets. This library provides both client and server parts so that you can integrate
  it in your wallet, or in your dapp - whatever you are working on.
                   DESC
  spec.homepage     = "https://github.com/gnosis/WalletConnectSwift"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author             = { "Andrey Scherbovich" => "andrey@gnosis.pm", "Dmitry Bespalov" => "dmitry.bespalov@gnosis.pm" }
  spec.cocoapods_version = '>= 1.4.0'
  spec.platform     = :ios, "12.0"
  spec.swift_version = "5.0"
  spec.source       = { :git => "https://github.com/gnosis/WalletConnectSwift.git", :tag => "#{spec.version}" }
  spec.source_files  = "Sources/**/*.swift"
  spec.requires_arc = true
  spec.dependency "CryptoSwift", "~> 1.0"
  spec.dependency "Starscream", "~> 3.1"
end
