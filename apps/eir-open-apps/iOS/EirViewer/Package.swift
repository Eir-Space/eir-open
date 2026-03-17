// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EirViewer",
    platforms: [.iOS(.v17)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", revision: "e33eba8513595bde535719c48fedcb10ade5af57"),
    ],
    targets: [
        .executableTarget(
            name: "EirViewer",
            dependencies: [
                "Yams",
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            ],
            path: "Sources/EirViewer"
        ),
        .testTarget(
            name: "EirViewerTests",
            dependencies: ["EirViewer", "Yams"],
            path: "Tests/EirViewerTests"
        ),
    ]
)
