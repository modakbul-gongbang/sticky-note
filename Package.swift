// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "StickyNotes",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "StickyNotesCore", targets: ["StickyNotesCore"]),
        .executable(name: "StickyNotes", targets: ["StickyNotesApp"]),
    ],
    targets: [
        .target(
            name: "StickyNotesCore",
            path: "Sources/StickyNotesCore"
        ),
        .executableTarget(
            name: "StickyNotesApp",
            dependencies: ["StickyNotesCore"],
            path: "Sources/StickyNotesApp"
        ),
        .testTarget(
            name: "StickyNotesTests",
            dependencies: ["StickyNotesCore", "StickyNotesApp"],
            path: "Tests/StickyNotesTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
