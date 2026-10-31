// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CardPickCore",
    products: [
        .library(name: "CardPickCore", targets: ["CardPickCore"])
    ],
    targets: [
        .target(
            name: "CardPickCore",
            resources: [
                .copy("Resources/cards.json")
            ]
        ),
        .testTarget(
            name: "CardPickCoreTests",
            dependencies: ["CardPickCore"]
        )
    ]
)
