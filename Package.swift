// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CodeScanner",
    platforms: [
        .iOS(.v16),
        .macCatalyst(.v16),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "CodeScanner", targets: ["CodeScanner"])
    ],
    targets: [
        .target(
            name: "CodeScanner",
            path: "Sources/CodeScanner",
            resources: [
                .copy("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
