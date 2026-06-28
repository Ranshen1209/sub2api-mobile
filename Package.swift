// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SakrylleSwift",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "SakrylleShared", targets: ["SakrylleShared"]),
        .executable(name: "SakrylleServer", targets: ["SakrylleServer"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.100.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0")
    ],
    targets: [
        .target(name: "SakrylleShared"),
        .executableTarget(
            name: "SakrylleServer",
            dependencies: [
                "SakrylleShared",
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(name: "SakrylleSharedTests", dependencies: ["SakrylleShared"]),
        .testTarget(
            name: "SakrylleServerTests",
            dependencies: [
                "SakrylleServer",
                .product(name: "XCTVapor", package: "vapor")
            ]
        )
    ]
)
