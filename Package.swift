// swift-tools-version: 5.9
// ShegerPay iOS SDK Package

import PackageDescription

let package = Package(
    name: "ShegerPaySDK",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "ShegerPaySDK",
            targets: ["ShegerPaySDK"]
        ),
    ],
    targets: [
        .target(
            name: "ShegerPaySDK",
            path: "Sources"
        ),
        .testTarget(
            name: "ShegerPaySDKTests",
            dependencies: ["ShegerPaySDK"],
            path: "Tests"
        ),
    ]
)
