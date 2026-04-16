// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VoiceInput",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VoiceInput", targets: ["VoiceInputApp"])
    ],
    targets: [
        .executableTarget(
            name: "VoiceInputApp",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Speech")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
