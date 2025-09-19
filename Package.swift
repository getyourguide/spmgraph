// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "spmgraph",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(
      name: "spmgraph",
      targets: ["SPMGraphExecutable"]
    ),
    .library(
      name: "SPMGraphKit",
      targets: [
        "SPMGraphVisualize",
        "SPMGraphLint",
        "SPMGraphTests",
      ]
    ),
    .library(
      name: "SPMGraphDescriptionInterface",
      type: .dynamic,
      targets: [
        "SPMGraphDescriptionInterface"
      ]
    ),
  ],
  dependencies: [
    .package(
      url: "https://github.com/tuist/GraphViz.git",
      // a few commits ahead of the deprecated GraphViz original repo. It also includes Xcode 16 fixes.
      revision: "083bccf9e492fd5731dd288a46741ea80148f508"
    ),
    .package(
      url: "https://github.com/apple/swift-argument-parser.git",
      .upToNextMinor(from: "1.2.2")
    ),

    // TODO: Review which tag / Swift release to use
    // - Initially it may be strict and sometimes "enforce" specific Xcode/Swift toolchains
    // - For now pinned to the 6.0 release / Xcode 16.0
    //
    // It auto exports SwiftToolsSupport, so no need to directly depend on the former 🙏
    .package(
      url: "https://github.com/apple/swift-package-manager",
      revision: "swift-6.0-RELEASE"
    ),
    .package(
      url: "https://github.com/aus-der-Technik/FileMonitor",
      revision: "1.2.0"
    ),
  ],
  targets: [
    // MARK: - Functionality

    .target(
      name: "SPMGraphVisualize",
      dependencies: [
        .target(name: "Core"),
        .product(
          name: "GraphViz",
          package: "GraphViz"
        ),
        .product(
          name: "SwiftPMDataModel",
          package: "swift-package-manager"
        ),
      ]
    ),
    .target(
      name: "SPMGraphLint",
      dependencies: [
        .target(name: "Core"),
        .target(name: "SPMGraphDescriptionInterface"),
      ]
    ),
    .target(
      name: "SPMGraphTests",
      dependencies: [
        .target(name: "Core"),
        .target(name: "SPMGraphDescriptionInterface"),
      ]
    ),
    .target(
      name: "SPMGraphConfigSetup",
      dependencies: [
        .target(name: "Core"),
        .product(
          name: "FileMonitor",
          package: "FileMonitor"
        ),
      ],
      resources: [
        .copy("Resources")
      ]
    ),

    // MARK: - Interface for dynamically loaded lint rules

    .target(
      name: "SPMGraphDescriptionInterface",
      dependencies: [
        .product(
          name: "SwiftPMDataModel",
          package: "swift-package-manager"
        )
      ]
    ),

    // MARK: - Core

    .target(
      name: "Core",
      dependencies: [
        .product(
          name: "SwiftPMDataModel",
          package: "swift-package-manager"
        )
      ]
    ),

    // MARK: - Argument parser / CLI

    .executableTarget(
      name: "SPMGraphExecutable",
      dependencies: [
        .target(name: "SPMGraphVisualize"),
        .target(name: "SPMGraphLint"),
        .target(name: "SPMGraphTests"),
        .target(name: "SPMGraphConfigSetup"),
        .product(
          name: "ArgumentParser",
          package: "swift-argument-parser"
        ),
      ]
    ),
  ]
)
