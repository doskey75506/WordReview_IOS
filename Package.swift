// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "WordReviewKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "WordReviewKit", targets: ["WordReviewKit"]),
    ],
    targets: [
        .target(
            name: "WordReviewKit"
        ),
        .testTarget(
            name: "WordReviewTests",
            dependencies: ["WordReviewKit"]
        ),
    ]
)
