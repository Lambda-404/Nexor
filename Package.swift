// swift-tools-version: 5.9
import PackageDescription
import Foundation

var targets: [Target] = [
    .executableTarget(
        name: "Nexor",
        dependencies: [],
        path: "Sources/Nexor",
        linkerSettings: [
            .linkedFramework("SwiftUI"),
            .linkedFramework("Network"),
            .linkedFramework("CoreBluetooth"),
            .linkedFramework("CoreLocation"),
            .linkedFramework("AppKit", .when(platforms: [.macOS])),
            .linkedFramework("CoreWLAN", .when(platforms: [.macOS])),
            .linkedFramework("SystemConfiguration", .when(platforms: [.macOS])),
            .linkedFramework("ServiceManagement", .when(platforms: [.macOS])),
            .linkedFramework("IOBluetooth", .when(platforms: [.macOS]))
        ]
    )
]

var products: [Product] = [
    .executable(
        name: "Nexor",
        targets: ["Nexor"]
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

let package = Package(
    name: "Nexor",
    platforms: [
        .macOS(.v14),
        .watchOS(.v10)
    ],
    products: products,
    dependencies: [],
    targets: targets
)
