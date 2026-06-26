// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OllamaKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "OllamaKit",
            targets: ["OllamaKit"]
        ),
        .executable(
            name: "ollama-tracer",
            targets: ["OllamaTracer"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "OllamaKit"
        ),
        .executableTarget(
            name: "OllamaTracer",
            dependencies: ["OllamaKit"]
        ),
        .testTarget(
            name: "OllamaKitTests",
            dependencies: ["OllamaKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
