// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "the-orchestra",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.5.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui.git", from: "2.4.0")
    ],
    targets: [
        .executableTarget(
            name: "the-orchestra",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ],
            path: "Sources",
            resources: [
                .process("Resources/Assets.xcassets"),
                .copy("Resources/Icons"),
                .copy("Resources/web"),
                .copy("bin")
            ]
        )
    ]
)
