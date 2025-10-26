// swift-tools-version: 6.1

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
      exact: "0.4.2"
    ),
    .package(
      url: "https://github.com/apple/swift-argument-parser.git",
      .upToNextMinor(from: "1.6.2")
    ),

    // - Pinned to the the Swift 6.2 development / Xcode 26
    // It auto exports SwiftToolsSupport, so no need to directly depend it 🙏
    .package(
      url: "https://github.com/apple/swift-package-manager",
      revision: "swift-6.2-RELEASE"
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
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
    .target(
      name: "SPMGraphLint",
      dependencies: [
        .target(name: "Core"),
        .target(name: "SPMGraphDescriptionInterface"),
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
    .target(
      name: "SPMGraphTests",
      dependencies: [
        .target(name: "Core"),
        .target(name: "SPMGraphDescriptionInterface"),
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
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
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),

    // MARK: - Interface for dynamically loaded lint rules

    .target(
      name: "SPMGraphDescriptionInterface",
      dependencies: [
        .product(
          name: "SwiftPMDataModel",
          package: "swift-package-manager"
        ),
        .target(name: "Core"),
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
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
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
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
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),

    // MARK: - Tests

    .testTarget(
      name: "SPMGraphExecutableTests",
      dependencies: [
        .target(name: "SPMGraphExecutable"),
        .target(name: "FixtureSupport"),
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),
    .testTarget(
      name: "SPMGraphDescriptionInterfaceTests",
      dependencies: [
        .target(name: "SPMGraphDescriptionInterface"),
        .target(name: "Core"),
        .target(name: "FixtureSupport"),
        .product(
          name: "ArgumentParser",
          package: "swift-argument-parser"
        ),
      ],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    ),

    // MARK: - Test support

    .target(
      name: "FixtureSupport",
      dependencies: [
        .target(name: "SPMGraphDescriptionInterface"),
        .target(name: "Core"),
        .product(
          name: "ArgumentParser",
          package: "swift-argument-parser"
        ),
      ],
      resources: [.copy("Resources")],
      swiftSettings: [
        .enableExperimentalFeature("StrictConcurrency")
      ]
    )
  ]
)
