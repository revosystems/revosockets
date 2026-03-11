// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "RevoSockets",
    platforms: [
        .iOS(.v13),
	.macOS(.v10_15)
    ],
    products: [
        .library(
            name: "RevoSockets",
            targets: ["RevoSockets"]
        )
    ],
    targets: [
        .target(
            name: "RevoSockets",
            path: "RevoSockets/src"
        ),
        .testTarget(
            name: "RevoSocketsTests",
            dependencies: ["RevoSockets"]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
