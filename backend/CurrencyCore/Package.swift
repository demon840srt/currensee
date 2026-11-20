// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CurrencyCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "CurrencyCore", targets: ["CurrencyCore"]),
        // Test-only mocks (ADR-0011). Never link this into the app target.
        .library(name: "CurrencyCoreTestSupport", targets: ["CurrencyCoreTestSupport"])
    ],
    targets: [
        .target(
            name: "CurrencyCore",
            resources: [.process("Catalog/currencies.json")]
        ),
        .target(name: "CurrencyCoreTestSupport", dependencies: ["CurrencyCore"]),
        .testTarget(
            name: "CurrencyCoreTests",
            dependencies: ["CurrencyCore", "CurrencyCoreTestSupport"],
            resources: [.copy("Fixtures")]
        )
    ],
    swiftLanguageModes: [.v6]
)
