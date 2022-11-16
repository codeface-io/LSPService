// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "LSPService",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "LSPService", targets: ["LSPService"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git",
                 from: "4.57.0"),
        .package(url: "https://github.com/codeface-io/SwiftLSP.git",
                 exact: "0.3.2"),
        .package(url: "https://github.com/flowtoolz/FoundationToolz.git",
                 exact: "0.1.1"),
        .package(url: "https://github.com/flowtoolz/SwiftyToolz.git",
                 exact: "0.1.1")
    ],
    targets: [
        .executableTarget(
            name: "LSPService",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "FoundationToolz", package: "FoundationToolz"),
                .product(name: "SwiftLSP", package: "SwiftLSP"),
                .product(name: "SwiftyToolz", package: "SwiftyToolz")
            ],
            path: "Sources",
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .testTarget(
            name: "LSPServiceTests",
            dependencies: [
                .target(name: "LSPService"),
                .product(name: "XCTVapor", package: "vapor"),
            ],
            path: "Tests"
        )
    ]
)
