// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EirViewer",
    platforms: [.iOS(.v17)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "EirViewer",
            dependencies: ["Yams"],
            path: "Sources/EirViewer"
        ),
    ]
)
