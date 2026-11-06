// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Pickel",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "Pickel",
            targets: ["Pickel"]
        ),
    ],
    targets: [
        .target(
            name: "Pickel"
        ),
        .testTarget(
            name: "PickelTests",
            dependencies: ["Pickel"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
