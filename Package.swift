// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AscendCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "AscendCore", targets: ["AscendCore"])],
    targets: [
        .target(name: "AscendCore", path: "ASCEND/Core/Domain"),
        .testTarget(name: "AscendCoreTests", dependencies: ["AscendCore"], path: "Tests/Core")
    ]
)
