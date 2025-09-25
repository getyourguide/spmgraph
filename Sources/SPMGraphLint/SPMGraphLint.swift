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

public struct SPMGraphLintInput {
  /// "Directory path of Package.swift file"
  let spmPackageDirectory: AbsolutePath
  /// A custom build directory for the package used to edit and load the SPMGraphConfig.
  let configBuildDirectory: AbsolutePath
  /// Comma separated array of suffixes to exclude from the graph e.g. 'Tests','Live','TestSupport'
  let excludedSuffixes: [String]
  /// Fails on warnings
  let isStrict: Bool
  /// Show extra logging for troubleshooting purposes
  let verbose: Bool
  /// The number of allowed warnings for the strict mode.
  /// - note: It can be useful to **bypass the strict mode in specific scenarios**. `The default is zero`.
  let expectedWarningsCount: UInt
  /// Relative path for an output file with the formatted lint results. By default the errors are added only listed in the sdtout.
  let outputFilePath: String?

  /// Makes an instance of ``SPMGraphLintInput``
  public init(
    spmPackageDirectory: String,
    configBuildDirectory: String?,
    excludedSuffixes: [String],
    isStrict: Bool,
    verbose: Bool,
    expectedWarningsCount: UInt,
    outputFilePath: String?
  ) throws {
    self.spmPackageDirectory = try AbsolutePath.packagePath(spmPackageDirectory)
    self.configBuildDirectory = try AbsolutePath.configBuildDirectory(configBuildDirectory)
    self.excludedSuffixes = excludedSuffixes
    self.isStrict = isStrict
    self.verbose = verbose
    self.expectedWarningsCount = expectedWarningsCount
    self.outputFilePath = outputFilePath
  }
}

// MARK: - Abstraction and Implementation

/// Represents a type that lints a Package.swift dependency graph and uncovers configuration issues
public protocol SPMGraphLintProtocol {
  func run() async throws
}

/// A type that lints a Package.swift dependency graph and uncovers configuration issues
public final class SPMGraphLint: SPMGraphLintProtocol {
  private let packageLoader: PackageLoader
  private let config: SPMGraphConfig
  private let system: SystemProtocol
  private let input: SPMGraphLintInput

  private var rules: [SPMGraphConfig.Lint.Rule] {
    config.lint.rules
  }

  private var isStrict: Bool {
    if input.isStrict {
      return true
    } else {
      return config.lint.isStrict
    }
  }

  private var excludedSuffixes: [String] {
    if !input.excludedSuffixes.isEmpty {
      return input.excludedSuffixes
    } else {
      return config.excludedSuffixes
    }
  }

  private var expectedWarningsCount: UInt {
    if input.expectedWarningsCount > 0 {
      return input.expectedWarningsCount
    } else {
      return config.lint.expectedWarningsCount
    }
  }

  /// Makes an instance of ``SPMGraphLint`` from a given input
  public convenience init(input: SPMGraphLintInput) throws {
    try self.init(packageLoader: .live, input: input)
  }

  /// Makes an instance of ``SPMGraphLint``
  ///
  /// - Parameters:
  ///   - spmPackageDirectory: Path to the directory containing the `Package.swift` file
  ///   - packageLoader: dependency used to load a Package.swift
  ///   - system: dependency used to run shell commands
  init(
    packageLoader: PackageLoader = .live,
    configLoader: SPMGraphConfigLoading = SPMGraphConfigLoader(),
    system: SystemProtocol = System.shared,
    input: SPMGraphLintInput
  ) throws {
    self.packageLoader = packageLoader
    self.config = try configLoader.load(buildDirectory: input.configBuildDirectory)
    self.system = system
    self.input = input
  }

  /// Lints the Swift Package dependency graph
  public func run() async throws {
    let package = try await packageLoader.load(
      input.spmPackageDirectory,
      input.verbose
    )

    let result = lintGraph(package: package)

    if let outputFilePath = input.outputFilePath {
      try generateOutput(lintMessage: result.message, outputFilePath: outputFilePath)
    }

    if result.hasErrors && isStrict {
      throw SPMGraphLint.Error.lintFailedAndStrictIsOn
    }
  }
}

// MARK: - Private

private extension SPMGraphLint {
  struct Result: Equatable {
    let hasErrors: Bool
    let message: String
  }

  func lintGraph(package: Package) -> Result {
    var totalErrorsCount = 0
    var lintMessage = ""

    rules.forEach { rule in
      printAndCollect("", lintMessage: &lintMessage)

      printAndCollect(
        "Running lint rule: \(rule.name)",
        color: .cyan,
        style: .bold,
        lintMessage: &lintMessage
      )
      printAndCollect(
        rule.abstract,
        style: .bold,
        terminator: "\n",
        lintMessage: &lintMessage
      )

      let errors = rule.validate(package, excludedSuffixes)
      totalErrorsCount += errors.count

      if errors.isEmpty {
        printAndCollect(
          "✅ Found no issues",
          color: .green,
          terminator: "\n",
          lintMessage: &lintMessage
        )
      } else {
        printAndCollect(
          "Errors:",
          color: .yellow,
          lintMessage: &lintMessage
        )
        let errorsDescription = errors.map { "- ⚠️  \($0.localizedDescription)" }
        printAndCollect(
          errorsDescription.joined(separator: "\n"),
          lintMessage: &lintMessage
        )
        printAndCollect(
          "Found ",
          color: .yellow,
          terminator: "",
          lintMessage: &lintMessage
        )
        printAndCollect(
          "\(errors.count) \(errors.count == 1 ? "error" : "errors")!",
          color: .yellow,
          style: .bold,
          terminator: "",
          lintMessage: &lintMessage
        )
        printAndCollect(
          " Let's fix it, humans 🤖!",
          color: .yellow,
          lintMessage: &lintMessage
        )
      }
    }

    printAndCollect("\n", lintMessage: &lintMessage)

    let hasErrors = totalErrorsCount > 0
    if hasErrors {
      printAndCollect(
        "⚠️  Found a ",
        color: .yellow,
        terminator: "",
        lintMessage: &lintMessage
      )
      printAndCollect(
        "total of \(totalErrorsCount) errors ",
        color: .yellow,
        style: .bold,
        terminator: "",
        lintMessage: &lintMessage
      )
      printAndCollect(
        "for all rules ran. Don't worry, everything is fixable!",
        color: .yellow,
        lintMessage: &lintMessage
      )
    } else {
      printAndCollect(
        "No errors found! The dependency graph looks tidy ✨",
        color: .green,
        style: .bold,
        terminator: "\n",
        lintMessage: &lintMessage
      )
    }

    // Write boolean result into file if running in the CI
    if System.env["CI"] != nil {
      let fileURL = AbsolutePath.currentDir
        .appending(".spmgraph_lint_result")
        .appending(extension: "txt")
        .asURL
      try? "\(hasErrors)".write(to: fileURL, atomically: true, encoding: .utf8)
    }

    return Result(
      hasErrors: hasErrors,
      message: lintMessage
    )
  }

  func printAndCollect(
    _ message: String,
    color: ANSIColor = .default,
    style: FontStyle = .default,
    terminator: String = "\n",
    lintMessage: inout String
  ) {
    print(
      "\(color.rawValue)\(style.rawValue)\(message)\(FontStyle.default.rawValue)\(ANSIColor.reset.rawValue)",
      terminator: terminator
    )

    lintMessage.append(message + terminator)
  }

  /// Generates the output for the lint results
  func generateOutput(lintMessage: String, outputFilePath: String) throws {
    let fileURL = AbsolutePath.currentDir
      .appending(outputFilePath)
      .appending(extension: "txt")
      .asURL

    do {
      try lintMessage.write(to: fileURL, atomically: true, encoding: .utf8)
      print("✅ Successfully saved the lint output into \(fileURL)")
    } catch {
      throw SPMGraphLint.Error.failedToSaveOutputFile(error: error)
    }
  }
}

// MARK: - Error

extension SPMGraphLint {
  /// Possible Lint failure reasons
  public enum Error: LocalizedError {
    case lintFailedAndStrictIsOn
    case failedToSaveOutputFile(error: Swift.Error)

    public var errorDescription: String? {
      switch self {
      case .lintFailedAndStrictIsOn:
        "Lint failed and strict flag is on!"
      case let .failedToSaveOutputFile(error):
        "Failed to save output file with error: \(error)"
      }
    }
  }
}
