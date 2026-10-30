// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KeyboardCombo",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "KeyboardCombo", targets: ["KeyboardCombo"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
    ],
    targets: [
        .executableTarget(
            name: "KeyboardCombo",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "KeyboardCombo/KeyboardCombo"
        ),
        .testTarget(
            name: "KeyboardComboTests",
            dependencies: [
                "KeyboardCombo",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "KeyboardCombo/KeyboardComboTests"
        )
    ]
)
