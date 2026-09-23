// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CatchMouse",
    platforms: [.macOS(.v12)],
    products: [.executable(name: "CatchMouse", targets: ["CatchMouse"])],
    targets: [
        .target(name: "CatchMouseCore"),
        .executableTarget(name: "CatchMouse", dependencies: ["CatchMouseCore"]),
        .testTarget(name: "CatchMouseCoreTests", dependencies: ["CatchMouseCore"]),
        .testTarget(name: "CatchMouseTests", dependencies: ["CatchMouse", "CatchMouseCore"])
    ]
)
