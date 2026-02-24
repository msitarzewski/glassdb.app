// swift-tools-version: 6.2
// GlassDBKit — Database protocol abstraction for glassdb.app

import PackageDescription

let package = Package(
    name: "GlassDBKit",
    platforms: [
        .visionOS(.v2),
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(name: "GlassDBKit", targets: ["GlassDBKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/mysql-nio.git", from: "1.0.0"),
        .package(path: "../Citadel"),
        // Phase 2: .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.21.0"),
    ],
    targets: [
        .target(
            name: "GlassDBKit",
            dependencies: [
                .product(name: "MySQLNIO", package: "mysql-nio"),
                .product(name: "Citadel", package: "Citadel"),
            ]
        ),
        .testTarget(
            name: "GlassDBKitTests",
            dependencies: ["GlassDBKit"]
        ),
    ]
)
