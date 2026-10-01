// swift-tools-version: 5.9
import PackageDescription
import Foundation

var targets: [Target] = [
    .executableTarget(
        name: "TeamworkNetworkUtilities",
        dependencies: [],
        path: "Sources/TeamworkNetworkUtilities",
        linkerSettings: [
            .linkedFramework("SwiftUI"),
            .linkedFramework("AppKit"),
            .linkedFramework("CoreWLAN"),
            .linkedFramework("SystemConfiguration"),
            .linkedFramework("Network"),
            .linkedFramework("ServiceManagement"),
            .linkedFramework("CoreBluetooth"),
            .linkedFramework("IOBluetooth"),
            .linkedFramework("CoreLocation")
        ]
    )
]

var products: [Product] = [
    .executable(
        name: "Teamwork_NetworkUtilities",
        targets: ["TeamworkNetworkUtilities"]
    )
]

// Conditionally register HelperDaemon target if directory exists (Milestone 2)
if FileManager.default.fileExists(atPath: "Sources/HelperDaemon") {
    targets.append(
        .executableTarget(
            name: "HelperDaemon",
            dependencies: [],
            path: "Sources/HelperDaemon"
        )
    )
    products.append(
        .executable(
            name: "HelperDaemon",
            targets: ["HelperDaemon"]
        )
    )
}

// Conditionally register E2ETests target if directory exists (Milestone 6)
if FileManager.default.fileExists(atPath: "Tests/E2ETests") {
    var excludes: [String] = []
    let potentialExcludes = ["run_tests.sh", "test_runner", "test_runner.dSYM", "Fixtures"]
    for item in potentialExcludes {
        if FileManager.default.fileExists(atPath: "Tests/E2ETests/\(item)") {
            excludes.append(item)
        }
    }
    targets.append(
        .testTarget(
            name: "E2ETests",
            dependencies: ["TeamworkNetworkUtilities"],
            path: "Tests/E2ETests",
            exclude: excludes
        )
    )
}

let package = Package(
    name: "TeamworkNetworkUtilities",
    platforms: [
        .macOS(.v14)
    ],
    products: products,
    dependencies: [],
    targets: targets
)
