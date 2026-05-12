# ShegerPay iOS Swift SDK

Official Swift SDK for ShegerPay — Ethiopian payment verification.

## Install (Swift Package Manager)

```swift
.package(url: "https://github.com/shegerpay/sdk-swift", from: "2.2.0")
```

## Quick Start

```swift
import ShegerPaySDK

let client = ShegerPay(apiKey: "sk_live_...")
let result = try await client.verify(transactionId: "FT26062K7WMY", amount: 1000, provider: "cbe")
```

## Requirements

- iOS 14+
- Swift 5.5+

## License

MIT
