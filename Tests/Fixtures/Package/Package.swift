// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "FixturePackage",
  products: [
    .library(
      name: "Library",
      targets: [
        "TargetA",
        "TargetB",
      ]
    ),
  ],
  targets: [
    .target(
      name: "TargetA",
      dependencies: [
        "TargetB"
      ]
    ),
    .target(
      name: "TargetB"
    ),

    .testTarget(
      name: "TargetATests",
      dependencies: [
        "TargetA"
      ]
    ),
    .testTarget(
      name: "TargetBTests",
      dependencies: [
        "TargetB"
      ]
    ),
  ]
)
