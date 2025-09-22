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
import Foundation
import PackageModel
import SPMGraphDescriptionInterface

// MARK: - Input

public struct SPMGraphTestsInput {
  /// "Directory path of Package.swift file"
  let spmPackageDirectory: AbsolutePath
  /// A custom build directory for the package used to edit and load the SPMGraphConfig.
  let configBuildDirectory: AbsolutePath
  /// Comma separated array of suffixes to exclude from the graph e.g. 'Tests','Live','TestSupport'
  let excludedSuffixes: [String]
  /// Optional list of changed files. Otherwise git versioning is used
  let changedFiles: [String]
  /// Base branch to compare the changes against
  let baseBranch: String
  /// The output mode
  let outputMode: SPMGraphTests.OutputMode  // TODO: Check if it make sense in the SPMGraphConfig fle
  /// Show extra logging for troubleshooting purposes
  let verbose: Bool

  /// Makes an instance of ``SPMGraphMapInput``
  public init(
    spmPackageDirectory: String,
    configBuildDirectory: String?,
    excludedSuffixes: [String],
    changedFiles: [String],
    baseBranch: String,
    outputMode: SPMGraphTests.OutputMode,
    verbose: Bool
  ) throws {
    self.spmPackageDirectory = try AbsolutePath.packagePath(spmPackageDirectory)
    self.configBuildDirectory = try AbsolutePath.configBuildDirectory(configBuildDirectory)
    self.excludedSuffixes = excludedSuffixes
    self.changedFiles = changedFiles
    self.baseBranch = baseBranch
    self.outputMode = outputMode
    self.verbose = verbose
  }
}

// MARK: - Abstraction and Implementation

/// Represents a type that, given a set of inputs, maps modules that should be built and tests that should run based on changed files
public protocol SSPMGraphTestsProtocol {
  @discardableResult
  func run() async throws -> [Module]
}

/// A type that maps modules that should be built and tests that should run based on changed files
public final class SPMGraphTests: SSPMGraphTestsProtocol {
  /// Defines how the output is generated
  public enum OutputMode: String, Equatable, CaseIterable {
    /// Dumps the list of test modules to run in a single line, following the `xcodebuild/fastlane scan expected format`
    ///
    /// `Example`: "BookingAssistantLiveTests,ActivityDetailsTests,ActivityDetailsCommonTests,ActivityAvailabilitiesLiveTests"
    case textDump
    /// Saves the list of test modules into an `output.txt` file in the `current dir`, following the `xcodebuild/fastlane scan expected format`
    ///
    /// `Example`: "BookingAssistantLiveTests,ActivityDetailsTests,ActivityDetailsCommonTests,ActivityAvailabilitiesLiveTests"
    case textFile
  }

  private let packageLoader: PackageLoader
  private let gitClient: GitClient
  private let system: SystemProtocol
  // Optional, so that users can leverage selective testing without the need to setup their own `SPMGraphConfig`
  private let config: SPMGraphConfig?
  private let input: SPMGraphTestsInput

  private var excludedSuffixes: [String] {
    // it defaults to the command set value, otherwise it falls back to the `SPMGraphConfig` setting
    if !input.excludedSuffixes.isEmpty {
      return input.excludedSuffixes
    } else {
      return config?.excludedSuffixes ?? []
    }
  }

  /// Makes an instance of ``SPMGraphMap``
  public convenience init(input: SPMGraphTestsInput) throws {
    try self.init(packageLoader: .live, input: input)
  }

  /// Makes an instance of ``SPMGraphMap``
  ///
  /// - Parameters:
  ///   - packageLoader: dependency used to load a Package.swift
  ///   - gitClient: dependency to check for git changes
  ///   - system: dependency used to run shell commands
  public init(
    packageLoader: PackageLoader = .live,
    configLoader: SPMGraphConfigLoading = SPMGraphConfigLoader(),
    gitClient: GitClient = .makeLive(),
    system: SystemProtocol = System.shared,
    input: SPMGraphTestsInput
  ) throws {
    self.packageLoader = packageLoader
    self.gitClient = gitClient
    self.system = system
    self.config = try? configLoader.load(buildDirectory: input.configBuildDirectory)
    self.input = input
  }

  /// Maps the test modules that should run based on a package graph and related git changes
  /// - Returns: An array of test test modules to be run
  @discardableResult
  public func run() async throws -> [Module] {
    // TODO: Abstract away `Module` so that users don't transitively depend on the SPM library

    // check changed files and return in case there are none
    let changedFiles: [AbsolutePath]
    if input.changedFiles.isEmpty {
      changedFiles = try gitClient.listChangedFiles(input.baseBranch)
        .map(AbsolutePath.init(validating:))
    } else {
      let changedFilesString = input.changedFiles
      changedFiles = try changedFilesString.map {
        let relativePath = try RelativePath(validating: $0)
        return AbsolutePath.currentDir.appending(relativePath)
      }
    }

    guard changedFiles.isEmpty == false else {
      if input.verbose {
        try system.echo(
          "There are no changes in the current git revision, skipping map.."
        )
      }
      return []
    }

    if input.verbose {
      try system.echo(
        "changed files are \(changedFiles.map(\.description).joined(separator: "\n"))"
      )
    }

    // if there are changed files, load the package and map the affected modules
    let package = try await packageLoader.load(input.spmPackageDirectory, input.verbose)

    // map affected modules
    let affectedModules = mapAffectedModules(
      package: package,
      changedFiles: changedFiles,
      verbose: input.verbose
    )

    if input.verbose {
      if affectedModules.isEmpty {
        try system.echo(
          "No modules were changed"
        )
      } else {
        try system.echo(
          "The affected modules are: \(affectedModules.map(\.name).joined(separator: "\n"))"
        )
      }
    }

    // map tests modules that should run
    let testModulesToRun = mapTestmodules(for: affectedModules, package: package)

    if testModulesToRun.isEmpty {
      try system.echo(
        "No test modules to run"
      )
    } else {
      try system.echo(
        "The test modules to run are: \(testModulesToRun.map(\.name).joined(separator: "\n"))"
      )
    }

    try generateOutput(testModulesToRun: testModulesToRun, outputMode: input.outputMode)

    return testModulesToRun
  }
}

// MARK: - Private

private extension SPMGraphTests {
  /// Maps and returns the modules that were affected by a set of changed files
  ///
  /// The following is **included**:
  /// - modules that **contain changed files**
  /// - modules that **directly depend** on modules that contain changed files
  ///
  /// The following is **not included**:
  /// - **Package products** affected by the changes
  /// - **Xcode project based modules** affected by package products/modules that changed, such as _App modules_
  ///
  /// **Example**:
  /// - Sources/Routes/RouteA.swift changed
  /// - The module `Routes` **is mapped**
  /// - module `BookingRoute` and `CheckoutRoute` depends on `Routes`, they are **also mapped**
  func mapAffectedModules(
    package: Package,
    changedFiles: [AbsolutePath],
    verbose: Bool = false
  ) -> [Module] {
    var changedModules: [Module] = []
    if changedFiles.contains(where: { $0.extension == "resolved" }) {
      // If a third party dependency has changed, run all tests
      changedModules = package.modules
      if verbose {
        try? system.echo(
          "Package.resolved has changed, running all tests..."
        )
      }
    } else {
      changedModules = changedFiles.compactMap { changedFile in
        package.modules
          .first { module in
            // ie "Modules/ActivityAvailabilities/ActivityAvailabilities/API/ActivityAvailabilitiesAPI.swift" contains Modules/ActivityAvailabilities/ActivityAvailabilities
            // it is simpler than iterating over all sources of each module
            changedFile.isDescendantOfOrEqual(to: module.path)
          }
      }
    }

    /// Maps modules that depend on the affected ones
    /// - note: In the future it could  check if changed code is public and directly used when mapping modules
    let modulesThatDependOnChangedOnes: [Module]
    if changedModules.isEmpty == false {
      modulesThatDependOnChangedOnes = package.modules
        .filter { $0.type != .test && $0.type != .systemModule }
        /// should `snippet` be **filtered out too**??
        .filter { changedModules.contains($0) == false }
        .filter {
          $0.dependencies
            .compactMap(\.module)
            .contains(where: changedModules.contains)
        }
    } else {
      modulesThatDependOnChangedOnes = []
    }

    return changedModules + modulesThatDependOnChangedOnes
  }

  /// Maps the test modules that depend on a set of modules
  func mapTestmodules(
    for modules: [Module],
    package: Package
  ) -> [Module] {
    var allTestModulesToRun = modules.filter(\.type == .test)
    if modules.contains(where: { $0.type != .test }) {
      let allNotTestAffectedModules = modules.filter(\.type != .test)
      let allTestModules = package.modules.filter { $0.type == .test }

      let testModulesToRun = allTestModules.filter {
        $0.dependencies
          .compactMap(\.module)
          .contains(where: allNotTestAffectedModules.contains)
      }

      allTestModulesToRun += testModulesToRun
    }

    // Remove duplicate test modules
    return allTestModulesToRun.spm_uniqueElements()
  }

  /// A function that generates the output with tests to run
  /// - Parameters:
  ///    - testModulesToRun: All modules which tests need to run
  ///    - outputMode: Specifies the output mode
  func generateOutput(testModulesToRun: [Module], outputMode: OutputMode) throws {
    let inlineModuleNames = testModulesToRun.map(\.name).joined(separator: ",")

    switch outputMode {
    case .textDump:
      try system.echo(inlineModuleNames)
    case .textFile:
      let url = AbsolutePath.currentDir.asURL
      var fileURL = url.appendingPathComponent("output")
      fileURL = fileURL.appendingPathExtension("txt")
      do {
        try inlineModuleNames.write(to: fileURL, atomically: true, encoding: .utf8)
        try system.echo(
          "✅ Successfully saved the formatted list of test modules to \(fileURL)"
        )
      } catch {
        throw SPMGraphTests.Error.failedToSaveOutputFile(error: error)
      }
    }
  }
}

// MARK: - Error

extension SPMGraphTests {
  /// Possible Map failure reasons
  public enum Error: LocalizedError {
    case failedToSaveOutputFile(error: Swift.Error)

    public var errorDescription: String? {
      switch self {
      case let .failedToSaveOutputFile(error):
        "Failed to save output file with error: \(error)"
      }
    }
  }
}
