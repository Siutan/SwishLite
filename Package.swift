// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SwishLite",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "SwishLite", targets: ["SwishLite"])
  ],
  dependencies: [
    // No external dependencies
  ],
  targets: [
    .executableTarget(
      name: "SwishLite",
      path: "SwishLite",
      exclude: [
        "Assets.xcassets",
        "Info.plist",
      ],
      linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("ApplicationServices"),
      ],
    )
  ]
)
