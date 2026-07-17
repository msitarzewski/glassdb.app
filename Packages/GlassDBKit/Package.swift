// swift-tools-version: 6.2
// GlassDBKit — Database protocol abstraction for glassdb.app

import PackageDescription

let package = Package(
    name: "GlassDBKit",
    platforms: [
        .visionOS(.v26),
        .macOS(.v26),
        .iOS(.v26)
    ],
    products: [
        .library(name: "GlassDBKit", targets: ["GlassDBKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/mysql-nio.git", from: "1.0.0"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.33.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.14.0"),
        .package(path: "../Citadel"),
    ],
    targets: [
        .target(
            name: "GlassDBKit",
            dependencies: [
                .product(name: "MySQLNIO", package: "mysql-nio"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "Citadel", package: "Citadel"),
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .testTarget(
            name: "GlassDBKitTests",
            dependencies: [
                "GlassDBKit",
                .product(name: "MySQLNIO", package: "mysql-nio"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
            ]
        ),
    ]
)
