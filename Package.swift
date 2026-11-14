// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StatGithub",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "StatGithub", path: "Sources/StatGithub")
    ]
)
