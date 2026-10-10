// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Pickel",
    platforms: [
        .iOS(.v17)
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
