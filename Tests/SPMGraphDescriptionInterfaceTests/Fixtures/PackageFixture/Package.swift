// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "LintFixturePackage",
  products: [
    .library(
      name: "LintLibrary",
      targets: [
        "BaseModule",
        "InterfaceModule",
        "FeatureModule",
        "NetworkingLive",
      ]
    ),
  ],
  targets: [
    // Base module - should not depend on Live modules
    .target(
      name: "BaseModule",
      dependencies: []
    ),

    // Interface module - should not depend on Live modules
    .target(
      name: "InterfaceModule",
      dependencies: ["BaseModule"]
    ),

    // Feature module - can depend on Live modules
    .target(
      name: "FeatureModule",
      dependencies: [
        "InterfaceModule",
        "NetworkingLive",
      ]
    ),

    // Live module - should not depend on other Live modules
    .target(
      name: "NetworkingLive",
      dependencies: ["InterfaceModule"]
    ),

    // Another Live module for testing Live -> Live dependency rule
    .target(
      name: "StorageLive",
      dependencies: ["NetworkingLive"] // This violates the rule
    ),

    // Module with unused dependency
    .target(
      name: "ModuleWithUnusedDep",
      dependencies: [
        "BaseModule", // This is unused in the actual code
        "InterfaceModule",
      ]
    ),

    // Test targets (should be excluded)
    .testTarget(
      name: "BaseModuleTests",
      dependencies: ["BaseModule"]
    ),
  ]
)
