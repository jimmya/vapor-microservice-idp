// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "idp",
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
        .package(url: "https://github.com/vapor/jwt.git", from: "3.0.0"),
        .package(url: "https://github.com/vapor/fluent-postgresql.git", from: "1.0.0"),
        .package(url: "https://github.com/LiveUI/S3.git", from: "3.0.0-RC3.1")
    ],
    targets: [
        .target(name: "App", dependencies: ["FluentPostgreSQL", "JWT", "Vapor", "S3"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)

