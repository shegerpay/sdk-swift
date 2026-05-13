# ShegerPay iOS SDK

Official iOS/Swift SDK for ShegerPay Payment Verification Gateway.

## 📦 Installation

### Swift Package Manager (Recommended)

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/shegerpay/ios-sdk.git", from: "2.2.0")
]
```

Or in Xcode:

1. File → Add Packages...
2. Enter: `https://github.com/shegerpay/ios-sdk.git`
3. Click "Add Package"

### CocoaPods

```ruby
pod 'ShegerPaySDK', '~> 2.2'
```

### Manual Installation

Copy `Sources/ShegerPaySDK/ShegerPay.swift` into your project.

---

## 🚀 Quick Start

```swift
import ShegerPaySDK

// Initialize client
let client = try ShegerPay(apiKey: "sk_test_xxx")

// Verify Ethiopian payment
let result = try await client.verify(
    transactionId: "FT24352648751234",
    amount: 100.00,
    provider: .cbe
)

if result.valid {
    print("✅ Payment verified!")
    print("Payer: \(result.payer ?? "Unknown")")
}
```

---

## 💳 Ethiopian Payment Verification

### Auto-Detect Provider

```swift
// Use quickVerify() when the provider is ambiguous.
let result = try await client.quickVerify(
    transactionId: "FT24352648751234",
    amount: 100.00
)
```

### BOA Verification

```swift
let result = try await client.verify(
    transactionId: "https://cs.bankofabyssinia.com/slip/?trx=FT26091B1X5152078",
    amount: 100.00,
    provider: .boa,
    merchantName: "My Shop",
    senderAccount: "52078"
)
```

### Specify Provider

```swift
let result = try await client.verify(
    transactionId: "FT24352648751234",
    amount: 100.00,
    provider: .cbe,
    merchantName: "My Shop"
)
```

### Supported Providers

| Provider | ID Format        | Example             |
| -------- | ---------------- | ------------------- |
| CBE      | `FT` prefix      | `FT24352648751234`  |
| Telebirr | Reference number | `123456789`         |
| Awash    | `AW` prefix      | `AW24352648751234`  |
| BoA      | Receipt URL / full `trx` | `https://cs.bankofabyssinia.com/slip/?trx=FT26091B1X5152078` |
| E-Birr   | Reference code   | `EB123456`          |

---

## 🖼 Receipt Image Verification

```swift
// Verify from base64-encoded screenshot
let result = try await client.verifyImage(
    "iVBORw0KGgoAAAANSUhEUgAA...",  // base64 string
    provider: "cbe",
    amount: 150.00,
    merchantName: "My Shop"
)

if result.valid {
    print("Payment verified from receipt image!")
}

// Or verify from a public URL
let result2 = try await client.verifyImage(
    "https://example.com/receipt.png",
    merchantName: "My Shop"
)
```

---

## 📋 Get Supported Providers

```swift
let providers = try await client.getProviders()
print(providers)
```

---

## 🔗 Payment Links

### Create Payment Link

```swift
let link = try await client.createPaymentLink(
    title: "Product Purchase",
    amount: 500.00,
    currency: "ETB",
    description: "Premium subscription",
    enableCBE: true,
    enableTelebirr: true,
    enableCrypto: false
)

print("Payment URL: \(link.paymentUrl)")
print("QR Code: \(link.qrCodeBase64 ?? "N/A")")
```

### List Payment Links

```swift
let links = try await client.listPaymentLinks(limit: 50)
for link in links {
    print("\(link.title): \(link.status)")
}
```

---

## 🪙 Crypto Payments

### Generate Payment Intent

```swift
let intent = try await client.generateCryptoIntent(
    amountUsd: 50.00,
    walletAddress: "TJCnKsPa7y5okkXvQAidZBzqx3QyQ6sxMW",
    currency: "USDT",
    chain: "TRON"
)

print("Send \(intent.paymentAmount) to \(intent.walletAddress)")
print("Reference: \(intent.referenceId)")
```

### Verify Crypto Payment

```swift
let result = try await client.verifyCrypto(referenceId: "SHGR-TRO-ABC123")
if result.valid {
    print("Crypto payment confirmed!")
}
```

---

## 🔔 Webhook Verification

```swift
// In your webhook endpoint
func handleWebhook(payload: String, headers: [String: String]) -> Bool {
    guard let signature = headers["X-ShegerPay-Signature"] else {
        return false
    }

    let isValid = ShegerPay.verifyWebhookSignature(
        payload: payload,
        signature: signature,
        secret: "whsec_your_webhook_secret"
    )

    return isValid
}
```

---

## ⚙️ Configuration

### Custom Base URL

```swift
let client = try ShegerPay(
    apiKey: "sk_test_xxx",
    baseURL: "https://custom-api.example.com"
)
```

### Check Test Mode

```swift
if client.isTestMode {
    print("Running in test mode")
}
```

---

## 🧪 Test Mode

Use `sk_test_*` API keys for testing:

| Transaction ID | Result     |
| -------------- | ---------- |
| `FT123456`     | ✅ Success |
| `FAIL_TEST`    | ❌ Failed  |
| `PENDING_123`  | ⏳ Pending |

---

## 📄 License

MIT © 2026 ShegerPay
