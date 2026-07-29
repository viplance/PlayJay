// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PlayJay",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PlayJay", targets: ["PlayJay"])
    ],
    targets: [
        .executableTarget(
            name: "PlayJay",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "PlayJayTests"
        )
    ]
)
