<p align="center"><img src="logo.png" alt="ShegerPay" width="200" /></p>

# ShegerPay Swift / iOS SDK

[![Version](https://img.shields.io/badge/version-2.2.0-blue)](https://github.com/shegerpay/sdk-swift/releases)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![iOS](https://img.shields.io/badge/iOS-14%2B-blue)](https://developer.apple.com)

Official Swift SDK for ShegerPay — verify Ethiopian bank payments (CBE, Telebirr, BOA, Awash).

## Install (Swift Package Manager)

In Xcode: **File → Add Package Dependencies** → enter:
```
https://github.com/shegerpay/sdk-swift
```

Or in `Package.swift`:
```swift
.package(url: "https://github.com/shegerpay/sdk-swift", from: "2.2.0")
```

## Quick Start

```swift
import ShegerPaySDK

let client = ShegerPay(apiKey: "sk_live_YOUR_API_KEY")

// Verify a payment
let result = try await client.verify(
    transactionId: "FT26062K7WMY",
    amount: 1000,
    provider: "cbe"
)
print(result.verified) // true/false

// Verify without amount (lookup only)
let result2 = try await client.verify(transactionId: "FT26062K7WMY", provider: "telebirr")
print(result2.status)

// Verify from receipt screenshot
let imageData = UIImage(named: "receipt")!.jpegData(compressionQuality: 0.8)!
let imageBase64 = imageData.base64EncodedString()
let imgResult = try await client.verifyImage(imageBase64, provider: "cbe")
print(imgResult.verified)

// Create payment link
let link = try await client.createPaymentLink(title: "Order #1234", amount: 1000, currency: "ETB")
print(link.url)

// Get supported providers
let providers = try await client.getProviders()
```

## Supported Providers
`cbe` · `telebirr` · `boa` · `awash` · `ebirr_kaafi` · `ebirr_coop`

## Requirements
- iOS 14+
- Swift 5.5+
- Xcode 13+


## Support
- 📚 Docs: https://shegerpay.com/docs
- 💬 Telegram: [@shegerpay_0](https://t.me/shegerpay_0)
- 📧 Email: support@shegerpay.com
