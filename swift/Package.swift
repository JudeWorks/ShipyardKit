// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShipyardKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "ShipyardKit",
            targets: ["ShipyardKit"]
        )
    ],
    targets: [
        .target(
            name: "ShipyardKit",
            path: "Sources/ShipyardKit"
        ),
        .testTarget(
            name: "ShipyardKitTests",
            dependencies: ["ShipyardKit"],
            path: "Tests/ShipyardKitTests"
        )
    ]
)
