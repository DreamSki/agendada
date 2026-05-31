// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Agendada",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Agendada", targets: ["Agendada"]),
        .library(name: "AgendadaCore", targets: ["AgendadaCore"])
    ],
    targets: [
        .target(
            name: "AgendadaCore"
        ),
        .executableTarget(
            name: "Agendada",
            dependencies: ["AgendadaCore"],
            resources: [
                .copy("Resources/BlockNoteEditor")
            ]
        ),
        .testTarget(
            name: "AgendadaTests",
            dependencies: ["Agendada", "AgendadaCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
