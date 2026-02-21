// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EirViewer",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/jkrukowski/SQLiteVec", from: "0.0.9"),
    ],
    targets: [
        .executableTarget(
            name: "EirViewer",
            dependencies: [
                "Yams",
                .product(name: "SQLiteVec", package: "SQLiteVec"),
            ],
            path: "Sources/EirViewer",
            resources: [.process("Resources/")],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "EirViewerTests",
            dependencies: [
                "EirViewer",
                "Yams",
                .product(name: "SQLiteVec", package: "SQLiteVec"),
            ],
            path: "Tests/EirViewerTests"
        ),
    ]
)
