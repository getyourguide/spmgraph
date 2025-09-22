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

public struct SPMGraphLoadInput {
  /// Directory path of the `SPMGraphConfig.swift` file, which is the same as the `Package.swift` file
  let directory: AbsolutePath
  /// A custom build directory for the package used to edit and load the SPMGraphConfig.
  let configBuildDirectory: AbsolutePath
  /// Show extra logging for troubleshooting purposes
  let verbose: Bool

  /// Makes an instance of ``SPMGraphConfigInput``
  public init(
    directory: String,
    configBuildDirectory: String?,
    verbose: Bool
  ) throws {
    self.directory = try AbsolutePath.packagePath(directory)
    self.configBuildDirectory = try AbsolutePath.configBuildDirectory(configBuildDirectory)
    self.verbose = verbose
  }
}

public enum SPMGraphLoadError: Error {
  case failedToReadTheConfig(underlying: Error)
  case failedToLoadTheConfigIntoSpmgraph(localizedDescription: String)
  case failedToSetupDynamicLoading(underlying: Error)
}

// MARK: - Abstraction and Implementation

/// Represents a type that loads a spmgraph configuration
public protocol SPMGraphLoadProtocol {
  func run() async throws(SPMGraphLoadError)
}

/// A type that loads a spmgraph configuration
public final class SPMGraphLoad: SPMGraphLoadProtocol {
  private let input: SPMGraphLoadInput
  private let configBuildDirectory: AbsolutePath

  private var verbose: Bool {
    input.verbose
  }

  private lazy var editPackageDirectory: AbsolutePath = configBuildDirectory.appending("spmgraph-config")
  private lazy var dynamicLoadingFileDestination: AbsolutePath =
    editPackageDirectory
    .appending(component: "Sources")
    .appending(component: "SPMGraphConfig")
    .appending(component: "DoNotEdit_DynamicLoading")
    .appending(extension: "swift")

  public init(input: SPMGraphLoadInput) throws(SPMGraphLoadError) {
    self.input = input
    self.configBuildDirectory = input.configBuildDirectory
  }

  public func run() throws(SPMGraphLoadError) {
    // Defines the path to the user configuration file
    let userConfigFile = input.directory.appending("SPMGraphConfig.swift")

    try load(userConfigFile: userConfigFile)
  }
}

private extension SPMGraphLoad {
  func load(userConfigFile: AbsolutePath) throws(SPMGraphLoadError) {
    print("Loading your SPMGraphConfig.swift into spmgraph... please await")

    try includeDynamicLoadingFile()

    do {
      if verbose {
        try System.shared.run(
          "swift",
          "build",
          "--package-path",
          editPackageDirectory.pathString,
          verbose: verbose
        )
      } else {
        try System.shared.runAndCapture(
          "swift",
          "build",
          "--package-path",
          editPackageDirectory.pathString
        )
      }
    } catch {
      throw .failedToLoadTheConfigIntoSpmgraph(
        localizedDescription: error.localizedDescription
      )
    }

    defer { try? removeDynamicLoadingFile() }

    print("Finished loading")
  }

  func includeDynamicLoadingFile() throws(SPMGraphLoadError) {
    do {
      guard
        let dynamicLoadingTemplateURL = Bundle.module.url(
          forResource: "Resources/DoNotEdit_DynamicLoading",
          withExtension: "txt"
        )
      else {
        throw SPMGraphLoadError.failedToLoadTheConfigIntoSpmgraph(
          localizedDescription: "Unable to read the dynamic loading template"
        )
      }

      let dynamicLoadingTemplateFile = try AbsolutePath(
        validating: dynamicLoadingTemplateURL.path()
      )
      // Copy the template DoNotEdit_DynamicLoading.swift file into the edit package
      try localFileSystem.copy(
        from: dynamicLoadingTemplateFile,
        to: dynamicLoadingFileDestination
      )
    } catch {
      throw .failedToSetupDynamicLoading(underlying: error)
    }
  }

  func removeDynamicLoadingFile() throws(SPMGraphLoadError) {
    do {
      try FileManager.default.removeItem(at: dynamicLoadingFileDestination.asURL)
    } catch {
      throw .failedToSetupDynamicLoading(underlying: error)
    }
  }
}
