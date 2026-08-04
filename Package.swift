// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "calen",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "CalenCore", targets: ["CalenCore"]),
    .executable(name: "calen", targets: ["calen"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/apple/swift-argument-parser.git",
      from: "1.8.2"
    )
  ],
  targets: [
    .target(
      name: "CalenCore",
      linkerSettings: [
        .linkedFramework("CoreGraphics"),
        .linkedFramework("CoreLocation"),
        .linkedFramework("EventKit"),
      ]
    ),
    .executableTarget(
      name: "calen",
      dependencies: [
        "CalenCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      exclude: ["Resources/Info.plist"],
      linkerSettings: [
        .unsafeFlags([
          "-Xlinker", "-sectcreate",
          "-Xlinker", "__TEXT",
          "-Xlinker", "__info_plist",
          "-Xlinker", "Sources/calen/Resources/Info.plist",
        ])
      ]
    ),
    .testTarget(
      name: "CalenCoreTests",
      dependencies: ["CalenCore"]
    ),
  ]
)
