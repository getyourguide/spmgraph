//
//
//  Copyright (c) 2025 GetYourGuide GmbH
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//

import Basics
import Core
import FileMonitor
import Foundation

// MARK: - Input & Error

public struct SPMGraphEditInput {
  /// Directory path of the Package.swift file
  let spmPackageDirectory: AbsolutePath
  /// A custom build directory for the package used to edit and load the SPMGraphConfig.
  let buildDirectory: AbsolutePath
  /// Show extra logging for troubleshooting purposes
  let verbose: Bool

  /// Makes an instance of ``SPMGraphLintInput``
  public init(
    spmPackageDirectory: String,
    configBuildDirectory: String?,
    verbose: Bool
  ) throws {
    self.spmPackageDirectory = try AbsolutePath.packagePath(spmPackageDirectory)
    self.buildDirectory = try AbsolutePath.configBuildDirectory(configBuildDirectory)
    self.verbose = verbose
  }
}

public enum SPMGraphEditError: Error {
  case unableToLoadTemplates(bundle: Bundle)
  case failedToCreateOrLoadConfigFile(underlying: Error)
  case failedToCreateEditPackage(underlying: Error)
  case failedToCopyTemplateFile(underlying: Error)
  case failedToOpenEditPackageForEditing(underlying: Error)
  case failedToObserveConfigFileChanges(underlying: Error)
}

// MARK: - Abstraction and Implementation

/// Represents a type that edits a spmgraph configuration
public protocol SPMGraphEditProtocol {
  func run() async throws(SPMGraphEditError)
}

/// A type that edits a spmgraph configuration
public final class SPMGraphEdit: SPMGraphEditProtocol {
  private let input: SPMGraphEditInput
  private let system: SystemProtocol
  private let buildDirectory: AbsolutePath

  private var verbose: Bool {
    input.verbose
  }

  private lazy var editPackageDirectory: AbsolutePath = buildDirectory.appending("spmgraph-config")
  private lazy var editPackageSourcesDirectory =
    editPackageDirectory
    .appending("Sources")
    .appending("SPMGraphConfig")

  public init(
    input: SPMGraphEditInput,
    system: SystemProtocol = System.shared
  ) throws {
    self.input = input
    self.system = system
    self.buildDirectory = input.buildDirectory
  }

  public func run() async throws(SPMGraphEditError) {
    try createEditPackage()

    // Load template files
    let bundle = Bundle.module
    guard
      let templatePackageDotSwiftFileURL = bundle.url(
        forResource: "Resources/Package",
        withExtension: "txt"
      ),
      let templateConfigFileURL = bundle.url(
        forResource: "Resources/SPMGraphConfig",
        withExtension: "txt"
      )
    else {
      throw .unableToLoadTemplates(bundle: bundle)
    }

    // Copy the template Package.swift into the edit package
    try copyTemplatePackageDotSwift(templatePackageDotSwiftFileURL: templatePackageDotSwiftFileURL)

    // The config file should be in the same dir as the root of their package
    let userConfigFile = input.spmPackageDirectory.appending("SPMGraphConfig.swift")

    // Create or load the user's `SPMGraphConfig.swift` file
    try createOrLoadTheUserConfigFile(
      templateConfigFileURL: templateConfigFileURL,
      userConfigFile: userConfigFile,
      spmPackageDirectory: input.spmPackageDirectory
    )

    // Open the config edit package for editing
    try openEditPackage()

    // Observe changes on the editing config file
    try await observeEditingConfigFile(updating: userConfigFile)
  }
}

private extension SPMGraphEdit {
  func openEditPackage() throws(SPMGraphEditError) {
    guard !ProcessInfo.isRunningTests else {
      print("Skipped opening the edit package in tests...")
      return
    }

    if verbose {
      print("Opening the edit package...")
    }

    do {
      try system.run(
        "xed",
        ".",
        workingDirectory: TSCAbsolutePath(editPackageDirectory),
        verbose: verbose
      )
    } catch {
      throw .failedToOpenEditPackageForEditing(underlying: error)
    }
  }

  func createOrLoadTheUserConfigFile(
    templateConfigFileURL: URL,
    userConfigFile: AbsolutePath,
    spmPackageDirectory: AbsolutePath
  ) throws(SPMGraphEditError) {
    do {
      let templateConfigFile = try AbsolutePath(validating: templateConfigFileURL.path())
      let configFileDestination = editPackageSourcesDirectory.appending("SPMGraphConfig.swift")

      // Check if the user already has a `SPMGraphConfig.swift` in the same directory as their Package.swift
      let hasConfigFile = try localFileSystem.getDirectoryContents(spmPackageDirectory)
        .contains("SPMGraphConfig.swift")

      if !hasConfigFile {
        // Create a user config file from the template file
        try localFileSystem.copy(
          from: templateConfigFile,
          to: userConfigFile
        )

        if verbose {
          print("Created a SPMGraphConfig.swift for the user")
        }
      }

      // Copy the user SPMGraphConfig.swift into the edit package
      try localFileSystem.copy(
        from: userConfigFile,
        to: configFileDestination
      )

      if verbose {
        print("Loaded the user SPMGraphConfig.swift into the edit package")
      }
    } catch {
      throw .failedToCreateOrLoadConfigFile(underlying: error)
    }
  }

  func copyTemplatePackageDotSwift(templatePackageDotSwiftFileURL: URL) throws(SPMGraphEditError) {
    do {
      let templatePackageDotSwiftFile = try AbsolutePath(
        validating: templatePackageDotSwiftFileURL.path()
      )
      let packageDotSwiftDestinationPath = editPackageDirectory.appending(
        component: "Package.swift"
      )

      // Copy the template Package.swift file into the edit package
      try localFileSystem.copy(
        from: templatePackageDotSwiftFile,
        to: packageDotSwiftDestinationPath
      )
    } catch {
      throw .failedToCopyTemplateFile(underlying: error)
    }
  }

  func createEditPackage() throws(SPMGraphEditError) {
    print(
      """
      Generating a package for editing your SPMGraphConfig.swift.
      Inspect the symbols and look at the examples to build a configuration that works for you. Build to make ensure it compiles.
      Press CTRL+C once you finish editing it...
      """
    )

    if verbose {
      print("Package generated at \(buildDirectory.pathString)")
    }

    do {
      try localFileSystem.removeFileTree(editPackageDirectory)
      try localFileSystem.createDirectory(editPackageSourcesDirectory, recursive: true)

      if verbose {
        print("Edit package directory created at \(editPackageDirectory.pathString)")
      }
    } catch {
      throw .failedToCreateEditPackage(underlying: error)
    }
  }

  func observeEditingConfigFile(
    updating userConfigFile: AbsolutePath
  ) async throws(SPMGraphEditError) {
    do {
      let monitor = try FileMonitor(directory: editPackageSourcesDirectory.asURL)
      try monitor.start()
      for await event in monitor.stream {
        switch event {
        case .changed(let file):
          // Skip if the file is under an editing state
          guard !file.path().contains("~") else {
            break
          }

          let fileContents =
            try localFileSystem
            .readFileContents(try AbsolutePath(validating: file.absoluteString))
          try fileContents.withData { data in
            try localFileSystem.withLock(on: TSCAbsolutePath(userConfigFile)) {
              try localFileSystem.writeIfChanged(
                path: userConfigFile,
                data: data
              )
            }
          }

          if verbose {
            print("Detected an update on the editing SPMGraphConfig.swift file at \(file.path)")
          }
        case .added, .deleted:
          break
        }
      }
    } catch {
      throw .failedToObserveConfigFileChanges(underlying: error)
    }
  }
}

extension FileChange: @retroactive @unchecked Sendable {}
