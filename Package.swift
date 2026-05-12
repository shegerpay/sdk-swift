// swift-tools-version:5.5
import PackageDescription
let package = Package(
    name: "ShegerPaySDK",
    platforms: [.iOS(.v14)],
    products: [.library(name: "ShegerPaySDK", targets: ["ShegerPaySDK"])],
    targets: [.target(name: "ShegerPaySDK", path: "Sources/ShegerPaySDK")]
)
