// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "LanguageServiceHost",
    platforms: [
       .macOS(.v10_15)
    ],
    products: [
        .executable(name: "LanguageServiceHost", targets: ["LanguageServiceHost"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/flowtoolz/FoundationToolz.git", .branch("master")),
        .package(url: "https://github.com/flowtoolz/SwiftyToolz.git", .branch("master"))
    ],
    targets: [
        .target(
            name: "LanguageService",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "FoundationToolz", package: "FoundationToolz"),
                .product(name: "SwiftyToolz", package: "SwiftyToolz")
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .target(
            name: "LanguageServiceHost",
            dependencies: [
                .target(name: "LanguageService")
            ]
        ),
        .testTarget(
            name: "LanguageServiceTests",
            dependencies: [
                .target(name: "LanguageService"),
                .product(name: "XCTVapor", package: "vapor"),
            ]
        )
    ]
)
