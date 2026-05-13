/**
 * ShegerPay iOS/Swift SDK v2.2.0
 * Official iOS SDK for ShegerPay Payment Verification Gateway
 *
 * Installation (Swift Package Manager):
 *   https://github.com/shegerpay/ios-sdk.git
 *
 * Usage:
 *   import ShegerPaySDK
 *   let client = try ShegerPay(apiKey: "sk_test_xxx")
 *   let result = try await client.verify(transactionId: "FT123456", amount: 100)
 *   let imageResult = try await client.verifyImage("base64_or_url", provider: "cbe", amount: 100)
 */

import Foundation
#if canImport(CommonCrypto)
import CommonCrypto
#endif

// MARK: - Errors

public enum ShegerPayError: Error, LocalizedError {
    case invalidApiKey
    case missingApiKey
    case authenticationFailed
    case validationError(String)
    case networkError(Error)
    case invalidResponse
    case rateLimitExceeded
    case serverError(Int, String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidApiKey: return "Invalid API key format. Use sk_test_* or sk_live_*"
        case .missingApiKey: return "API key is required"
        case .authenticationFailed: return "Authentication failed - check your API key"
        case .validationError(let msg): return msg
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .invalidResponse: return "Invalid response from server"
        case .rateLimitExceeded: return "Rate limit exceeded. Please slow down."
        case .serverError(let code, let msg): return "Server error (\(code)): \(msg)"
        }
    }
}

// MARK: - Models

public struct VerificationResult: Codable, Sendable {
    public let verified: Bool?
    public let valid: Bool
    public let status: String
    public let provider: String?
    public let transactionId: String?
    public let amount: Double?
    public let reason: String?
    public let mode: String?
    public let payer: String?
    public let timestamp: String?
    
    enum CodingKeys: String, CodingKey {
        case verified, valid, status, provider, amount, reason, mode, payer, timestamp
        case transactionId = "transaction_id"
    }
}

public struct PaymentLink: Codable, Sendable {
    public let id: String
    public let shortCode: String
    public let paymentUrl: String
    public let qrCodeBase64: String?
    public let status: String
    public let amount: Double?
    public let currency: String?
    
    enum CodingKeys: String, CodingKey {
        case id, status, amount, currency
        case shortCode = "short_code"
        case paymentUrl = "payment_url"
        case qrCodeBase64 = "qr_code_base64"
    }
}

public struct CryptoPaymentIntent: Codable, Sendable {
    public let referenceId: String
    public let walletAddress: String
    public let paymentAmount: String
    public let currency: String
    public let network: String
    public let qrCode: String?
    public let expiresAt: String?
    
    enum CodingKeys: String, CodingKey {
        case walletAddress, currency, network
        case referenceId = "reference_id"
        case paymentAmount = "payment_amount"
        case qrCode = "qr_code"
        case expiresAt = "expires_at"
    }
}

public struct WebhookEvent: Codable, Sendable {
    public let id: String
    public let event: String
    public let data: [String: AnyCodable]
    public let timestamp: String
}

// MARK: - AnyCodable Helper

public struct AnyCodable: Codable, Sendable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let strVal = try? container.decode(String.self) {
            value = strVal
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            value = dictVal
        } else if let arrVal = try? container.decode([AnyCodable].self) {
            value = arrVal
        } else {
            value = NSNull()
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intVal = value as? Int {
            try container.encode(intVal)
        } else if let doubleVal = value as? Double {
            try container.encode(doubleVal)
        } else if let boolVal = value as? Bool {
            try container.encode(boolVal)
        } else if let strVal = value as? String {
            try container.encode(strVal)
        } else {
            try container.encodeNil()
        }
    }
}

// MARK: - Provider Enum

public enum PaymentProvider: String, Sendable {
    case cbe = "cbe"
    case telebirr = "telebirr"
    case awash = "awash"
    case boa = "boa"
    case ebirr = "ebirr"
    
    public static func detect(from transactionId: String) -> PaymentProvider {
        let upperId = transactionId.uppercased()
        let lowerId = transactionId.lowercased()
        if lowerId.contains("cs.bankofabyssinia.com/slip/?trx=") { return .boa }
        if upperId.hasPrefix("FT") { return .cbe }
        if upperId.hasPrefix("AW") { return .awash }
        if upperId.hasPrefix("BOA") { return .boa }
        return .telebirr
    }
}

// MARK: - ShegerPay Client

@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
public final class ShegerPay: Sendable {
    private let apiKey: String
    private let baseURL: String
    public let mode: String
    public let isTestMode: Bool
    
    private static let defaultBaseURL = "https://api.shegerpay.com"
    private static let sdkVersion = "2.2.0"
    
    public init(apiKey: String, baseURL: String? = nil) throws {
        guard !apiKey.isEmpty else {
            throw ShegerPayError.missingApiKey
        }
        
        guard apiKey.hasPrefix("sk_test_") || apiKey.hasPrefix("sk_live_") else {
            throw ShegerPayError.invalidApiKey
        }
        
        self.apiKey = apiKey
        self.baseURL = (baseURL ?? Self.defaultBaseURL).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.mode = apiKey.hasPrefix("sk_test_") ? "test" : "live"
        self.isTestMode = apiKey.hasPrefix("sk_test_")
    }
    
    // MARK: - Ethiopian Payment Verification
    
    /// Verify an Ethiopian bank payment (CBE, Telebirr, Awash, etc.)
    public func verify(
        transactionId: String,
        amount: Double? = nil,
        provider: PaymentProvider? = nil,
        merchantName: String? = nil,
        senderAccount: String? = nil
    ) async throws -> VerificationResult {
        let detectedProvider = provider ?? {
            if transactionId.lowercased().contains("cs.bankofabyssinia.com/slip/?trx=") {
                return .boa
            }
            return nil
        }()
        guard let detectedProvider else {
            throw ShegerPayError.validationError("provider is required for ambiguous transaction references. Pass provider explicitly or use quickVerify().")
        }
        
        var params: [String: Any] = [
            "provider": detectedProvider.rawValue,
            "transaction_id": transactionId,
            "merchant_name": merchantName ?? "ShegerPay Verification"
        ]
        if let amount { params["amount"] = amount }
        if let senderAccount, !senderAccount.isEmpty {
            params["sender_account"] = senderAccount
        }
        
        return try await post(path: "/api/v1/verify", json: params)
    }
    
    /// Quick verification with auto-detected provider
    public func quickVerify(
        transactionId: String,
        amount: Double? = nil,
        expectedProvider: PaymentProvider? = nil,
        senderAccount: String? = nil
    ) async throws -> VerificationResult {
        var params: [String: Any] = [
            "transaction_id": transactionId
        ]
        if let amount { params["amount"] = amount }
        if let expectedProvider {
            params["expected_provider"] = expectedProvider.rawValue
        }
        if let senderAccount, !senderAccount.isEmpty {
            params["sender_account"] = senderAccount
        }
        return try await post(path: "/api/v1/quick-verify", json: params)
    }
    
    // MARK: - Image Verification

    /// Verify payment from a receipt screenshot (base64 encoded string or public URL)
    public func verifyImage(
        _ image: String,
        provider: String? = nil,
        amount: Double? = nil,
        merchantName: String = "ShegerPay Verification"
    ) async throws -> VerificationResult {
        var body: [String: Any] = ["image": image, "merchant_name": merchantName]
        if let provider { body["provider"] = provider }
        if let amount { body["amount"] = amount }
        return try await post(path: "/api/v1/verify/image", json: body)
    }

    // MARK: - Providers

    /// Get list of supported payment providers and their status
    public func getProviders() async throws -> [String: Any] {
        let url = URL(string: baseURL + "/api/v1/providers")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ShegerPayError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ShegerPayError.serverError(httpResponse.statusCode, message)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ShegerPayError.invalidResponse
        }
        return json
    }

    // MARK: - Payment Links
    
    /// Create a shareable payment link
    public func createPaymentLink(
        title: String,
        amount: Double,
        currency: String = "ETB",
        description: String? = nil,
        enableCBE: Bool = true,
        enableTelebirr: Bool = true,
        enableCrypto: Bool = false
    ) async throws -> PaymentLink {
        var params: [String: Any] = [
            "title": title,
            "amount": amount,
            "currency": currency,
            "enable_cbe": enableCBE,
            "enable_telebirr": enableTelebirr,
            "enable_crypto": enableCrypto
        ]
        
        if let desc = description {
            params["description"] = desc
        }
        
        return try await post(path: "/api/v1/payment-links", json: params)
    }
    
    /// List all payment links
    public func listPaymentLinks(limit: Int = 50, offset: Int = 0) async throws -> [PaymentLink] {
        struct Response: Codable {
            let links: [PaymentLink]
        }
        let result: Response = try await get(path: "/api/v1/payment-links?limit=\(limit)&offset=\(offset)")
        return result.links
    }

    // MARK: - Promo Codes

    public func createPromoCode(_ params: [String: Any]) async throws -> [String: Any] {
        try await requestDictionary(method: "POST", path: "/api/v1/promo-codes/", json: promoPayload(params))
    }

    public func listPromoCodes() async throws -> [[String: Any]] {
        try await requestArray(method: "GET", path: "/api/v1/promo-codes/", json: nil)
    }

    public func updatePromoCode(_ codeId: String, params: [String: Any]) async throws -> [String: Any] {
        try await requestDictionary(method: "PATCH", path: "/api/v1/promo-codes/\(codeId)", json: promoPayload(params))
    }

    public func deletePromoCode(_ codeId: String) async throws -> [String: Any] {
        try await requestDictionary(method: "DELETE", path: "/api/v1/promo-codes/\(codeId)", json: nil)
    }

    public func validatePromoCode(code: String, amount: Double, options: [String: Any] = [:]) async throws -> [String: Any] {
        var body = options
        body["code"] = code
        body["amount"] = amount
        return try await requestDictionary(method: "POST", path: "/api/v1/promo-codes/validate", json: body)
    }

    public func redeemPromoCode(code: String, amount: Double, transactionId: String, options: [String: Any] = [:]) async throws -> [String: Any] {
        var body = options
        body["code"] = code
        body["amount"] = amount
        body["transaction_id"] = transactionId
        return try await requestDictionary(method: "POST", path: "/api/v1/promo-codes/redeem", json: body)
    }

    public func applyPaymentLinkCoupon(shortCode: String, code: String, amount: Double? = nil, quantity: Int = 1, provider: String? = nil, customerIdentifier: String? = nil) async throws -> [String: Any] {
        var body: [String: Any] = ["code": code, "quantity": quantity]
        if let amount { body["amount"] = amount }
        if let provider { body["provider"] = provider }
        if let customerIdentifier { body["customer_identifier"] = customerIdentifier }
        return try await requestDictionary(method: "POST", path: "/api/v1/payment-links/\(shortCode)/apply-coupon", json: body)
    }

    public func getPaymentLinkOrderStatus(shortCode: String, orderId: String) async throws -> [String: Any] {
        return try await requestDictionary(
            method: "GET",
            path: "/api/v1/payment-links/\(shortCode)/orders/\(orderId)/status",
            json: nil
        )
    }
    
    // MARK: - Crypto Payments
    
    /// Generate a crypto payment intent
    public func generateCryptoIntent(
        amountUsd: Double,
        walletAddress: String,
        currency: String = "USDT",
        chain: String = "TRON"
    ) async throws -> CryptoPaymentIntent {
        let params: [String: Any] = [
            "amount_usd": amountUsd,
            "currency": currency,
            "wallet_address": walletAddress,
            "chain": chain
        ]
        return try await post(path: "/api/v1/crypto/generate-intent", json: params)
    }
    
    /// Verify a crypto payment by reference ID
    public func verifyCrypto(referenceId: String) async throws -> VerificationResult {
        let params: [String: Any] = ["reference_id": referenceId]
        return try await post(path: "/api/v1/crypto/verify-reference", json: params)
    }
    
    // MARK: - Webhooks (Static)
    
    /// Verify webhook signature (HMAC-SHA256)
    public static func verifyWebhookSignature(payload: String, signature: String, secret: String) -> Bool {
        #if canImport(CommonCrypto)
        guard let keyData = secret.data(using: .utf8),
              let payloadData = payload.data(using: .utf8) else {
            return false
        }
        
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        keyData.withUnsafeBytes { keyBytes in
            payloadData.withUnsafeBytes { dataBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
                       keyBytes.baseAddress, keyData.count,
                       dataBytes.baseAddress, payloadData.count,
                       &digest)
            }
        }
        
        let expected = "sha256=" + digest.map { String(format: "%02x", $0) }.joined()
        return expected == signature
        #else
        return false
        #endif
    }

    public static func verifyRedirectSignature(params: [String: Any], signature: String, secret: String) -> Bool {
        #if canImport(CommonCrypto)
        let amountValue = Double("\(params["amount"] ?? "0")") ?? 0
        let amount = String(format: "%.2f", amountValue)
        let payload = [
            "\(params["checkout_session_id"] ?? params["checkoutSessionId"] ?? "")",
            "\(params["order_id"] ?? params["orderId"] ?? "")",
            "\(params["short_code"] ?? params["shortCode"] ?? "")",
            amount,
            "\(params["currency"] ?? "ETB")",
            "\(params["status"] ?? "paid")"
        ].joined(separator: "|")
        guard let keyData = secret.data(using: .utf8),
              let payloadData = payload.data(using: .utf8) else {
            return false
        }
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        keyData.withUnsafeBytes { keyBytes in
            payloadData.withUnsafeBytes { dataBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
                       keyBytes.baseAddress, keyData.count,
                       dataBytes.baseAddress, payloadData.count,
                       &digest)
            }
        }
        let expected = digest.map { String(format: "%02x", $0) }.joined()
        return expected == signature.replacingOccurrences(of: "sha256=", with: "")
        #else
        return false
        #endif
    }
    
    // MARK: - Private HTTP Methods
    
    private func get<T: Decodable>(path: String) async throws -> T {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        return try await execute(request)
    }
    
    private func post<T: Decodable>(path: String, json: [String: Any]) async throws -> T {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
        addHeaders(to: &request)
        return try await execute(request)
    }

    private func requestDictionary(method: String, path: String, json: [String: Any]?) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let json, method != "GET", method != "DELETE" {
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        }
        addHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ShegerPayError.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200...299:
            if httpResponse.statusCode == 204 { return [:] }
            return (try JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        case 401:
            throw ShegerPayError.authenticationFailed
        case 429:
            throw ShegerPayError.rateLimitExceeded
        default:
            throw ShegerPayError.serverError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "Unknown error")
        }
    }

    private func requestArray(method: String, path: String, json: [String: Any]?) async throws -> [[String: Any]] {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let json, method != "GET", method != "DELETE" {
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        }
        addHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ShegerPayError.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200...299:
            return (try JSONSerialization.jsonObject(with: data)) as? [[String: Any]] ?? []
        case 401:
            throw ShegerPayError.authenticationFailed
        case 429:
            throw ShegerPayError.rateLimitExceeded
        default:
            throw ShegerPayError.serverError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "Unknown error")
        }
    }

    private func promoPayload(_ params: [String: Any]) -> [String: Any] {
        Dictionary(uniqueKeysWithValues: params.map { (snakeCase($0.key), $0.value) })
    }

    private func snakeCase(_ value: String) -> String {
        value.reduce(into: "") { output, character in
            if character.isUppercase {
                output.append("_")
                output.append(character.lowercased())
            } else {
                output.append(character)
            }
        }
    }
    
    private func addHeaders(to request: inout URLRequest) {
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("ShegerPay-iOS-SDK/\(Self.sdkVersion)", forHTTPHeaderField: "User-Agent")
    }
    
    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ShegerPayError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        case 401:
            throw ShegerPayError.authenticationFailed
        case 429:
            throw ShegerPayError.rateLimitExceeded
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ShegerPayError.serverError(httpResponse.statusCode, message)
        }
    }
}
