// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ComicsViewer",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "ComicsViewer",
            targets: ["ComicsViewer"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/weichsel/ZIPFoundation.git",
            .upToNextMinor(from: "0.9.20")
        ),
    ],
    targets: [
        .target(
            name: "ComicsViewer",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ]),
        .testTarget(
            name: "ComicsViewerTests",
            dependencies: [
                "ComicsViewer",
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ]),
    ]
)
