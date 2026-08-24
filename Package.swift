// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RayDepthStudio",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "RayDepthStudio", targets: ["RayDepthStudio"]),
        .executable(name: "raydepth-checks", targets: ["RayDepthStudioChecks"])
    ],
    targets: [
        .target(name: "RayDepthStudio", path: "Sources/RayDepthStudio"),
        // 无 XCTest 环境下的轻量断言检查（等装了 Xcode 可换回 swift test）
        .executableTarget(
            name: "RayDepthStudioChecks",
            dependencies: ["RayDepthStudio"],
            path: "Sources/RayDepthStudioChecks"
        )
    ]
)
