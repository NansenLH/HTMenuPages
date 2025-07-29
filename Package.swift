// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HTMenuPages",
    platforms: [ 
        .iOS(.v15),  
    ],
    products: [
        .library(
            name: "HTMenuPages",
            targets: ["HTMenuPages"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/SnapKit/SnapKit.git", .upToNextMajor(from: "5.0.1")),
    ],
    targets: [
        .target(
            name: "HTMenuPages",
            dependencies: [
                .product(name: "SnapKit", package: "SnapKit"),
            ]
        ),
        .testTarget(
            name: "HTMenuPagesTests",
            dependencies: ["HTMenuPages"]
        ),
    ]
)
