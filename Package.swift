// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NnShellKit",
    products: [
        .library(
            name: "NnShellKit",
            targets: ["NnShellKit"]),
        .library(
            name: "NnShellTesting",
            targets: ["NnShellTesting"])
    ],
    targets: [
        .target(
            name: "NnShellKit"),
        .target(
            name: "NnShellTesting",
            dependencies: [
                "NnShellKit"
            ]
        ),
        .testTarget(
            name: "NnShellKitTests",
            dependencies: [
                "NnShellKit",
                "NnShellTesting"
            ]
        )
    ]
)
