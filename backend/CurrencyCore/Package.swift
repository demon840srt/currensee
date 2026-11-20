// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CurrencyCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "CurrencyCore", targets: ["CurrencyCore"])
    ],
    targets: [
        .target(name: "CurrencyCore"),
        .testTarget(name: "CurrencyCoreTests", dependencies: ["CurrencyCore"])
    ],
    swiftLanguageModes: [.v6]
)
