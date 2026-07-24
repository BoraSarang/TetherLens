// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TetherLens",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TetherLens", targets: ["TetherLens"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
    ],
    targets: [
        .executableTarget(
            name: "TetherLens",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            exclude: ["Info.plist"],
            linkerSettings: [
                .linkedFramework("CoreWLAN"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("Network"),
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
