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
import Foundation
import PackageModel

/// Defines the contract for building and loading the user's configuration dynamically.
/// - warning: This API isn't intended to be used by `spmgraph` users directly, but is rather used internally by the tool
/// so that the configuration is loaded correctly. **Do not conform to it**!
open class SPMGraphConfigBuilder {
  public init() {}

  open func build() -> SPMGraphConfig {
    fatalError("You have to override this method.")
  }
}

/// Defines the `spmgraph` configuration for a given package definition that relies on it.
/// It includes the dependency graph lint rules and settings, the selective testing setup, and whether the strict mode is enabled.
/// - note: The user's `SPMGraphConfig.swift` must live in the same directory of the `Package.swift` that is under
/// evaluation.
public struct SPMGraphConfig: Sendable {
  public struct Lint: Sendable {
    public struct Rule: Sendable {
      public let id: String
      public let name: String
      public let abstract: String
      public var validate: @Sendable (Package, _ excludedSuffixes: [String]) -> [LocalizedError]

      public init(
        id: String,
        name: String,
        abstract: String,
        validate: @Sendable @escaping (Package, _: [String]) -> [LocalizedError]
      ) {
        self.id = id
        self.name = name
        self.abstract = abstract
        self.validate = validate
      }
    }

    /// A set of Lint rules that traverse a loaded dependency graph and return errors on broken rules
    public let rules: [Rule]
    /// When **enabled** it returns a **failure exit** code on **any warnings**
    public let isStrict: Bool
    /// The number of allowed warnings for the strict mode.
    /// - note: It can be useful to **bypass the strict mode in specific scenarios**. `The default is zero`.
    public let expectedWarningsCount: UInt

    public init(
      rules: [Rule] = .default,
      isStrict: Bool,
      expectedWarningsCount: UInt = 0
    ) {
      self.rules = rules
      self.isStrict = isStrict
      self.expectedWarningsCount = expectedWarningsCount
    }

    public static let `default`: Self = .init(isStrict: false)
  }

  /// Configuration for selective testing.
  ///
  /// It maps modules that should be built and tests that should be run based on changed files.
  public struct Tests: Sendable {
    /// Base branch to compare the changes against.
    public let baseBranch: String

    /// Initializes the selective tests configuration.
    /// - Parameter baseBranch: Base branch to compare the changes against. It `defaults` to `main`.
    public init(baseBranch: String = "main") {
      self.baseBranch = baseBranch
    }
  }

  public let lint: Lint
  public let tests: Tests
  /// Comma separated array of suffixes to exclude from the graph e.g. 'Tests','Live','TestSupport'.
  public let excludedSuffixes: [String]

  /// Initializes a ``SPMGraphConfig``.
  /// - Parameters:
  ///   - lint: Configures the lint capability.
  ///   - tests: Configures the selective tests capability.
  ///   - excludedSuffixes: Comma separated array of suffixes to exclude from the graph e.g. 'Tests','Live','TestSupport'.
  ///   - verbose: Show extra logging for troubleshooting purposes.
  public init(
    lint: Lint,
    tests: Tests = .init(),
    excludedSuffixes: [String] = [],
    verbose: Bool = false
  ) {
    self.lint = lint
    self.tests = tests
    self.excludedSuffixes = excludedSuffixes
  }

  /// The default ``SPMGraphConfig`` with strict mode disabled and the built-in lint rules.
  public static let `default`: Self = .init(lint: .default)
}

typealias Validate = (Package, _ excludedSuffixes: [String]) -> [LocalizedError]

public extension Array where Element == SPMGraphConfig.Lint.Rule {
  static let `default`: [SPMGraphConfig.Lint.Rule] = [
    .unusedDependencies,
    .liveModuleLiveDependency(),
    .baseOrInterfaceModuleLiveDependency(),
  ]
}

public extension SPMGraphConfig.Lint.Rule {
  static func liveModuleLiveDependency(
    isLiveModule: @Sendable @escaping (Module) -> Bool = \.isLiveModule
  ) -> Self {
    Self(
      id: "liveModuleLiveDependency",
      name: "Live modules should not depend on other Live modules",
      abstract:
        "To keep the dependency graph flat and avoid depending on implementations, a Live Module should never depend on another Live module",
      validate: { package, excludedSuffixes in
        let liveModules = package.modules
          .filter { !$0.containsOneOf(suffixes: excludedSuffixes) }
          .filter(\.isLiveModule)
          .sorted()

        let errors: [SPMGraphConfig.Lint.Error] =
          liveModules
          .map { liveModule in
            liveModule.dependencies
              .compactMap(\.module)
              .filter(\.isLiveModule == true)
              .map { dependency in
                SPMGraphConfig.Lint.Error.liveModuleLiveDependency(
                  moduleName: liveModule.name,
                  liveDependencyName: dependency.name
                )
              }
          }
          .reduce([], +)

        return errors
      }
    )
  }

  static func baseOrInterfaceModuleLiveDependency(
    isBaseModule: @Sendable @escaping (Module) -> Bool = { module in
      !module.isLiveModule && !module.canDependOnLive
    },
    isLiveModule: @Sendable @escaping (Module) -> Bool = \.isLiveModule
  ) -> Self {
    Self(
      id: "baseOrInterfaceModuleLiveDependency",
      name: "Base or Interface modules should not depend on Live modules",
      abstract:
        "To keep the dependency graph flat and avoid depending on higher level, a Base or Interface Module should never depend on upper Live Modules",
      validate: { package, excludedSuffixes in
        let nonLiveModulesThatCannotDependOnLive = package.modules
          .filter { !$0.containsOneOf(suffixes: excludedSuffixes) }
          .filter(isBaseModule)
          .filter { !isLiveModule($0) }  // filters out live modules, those are covered by the liveModuleLiveDependency rule
          .sorted()

        let errors: [SPMGraphConfig.Lint.Error] =
          nonLiveModulesThatCannotDependOnLive
          .map { module in
            module.dependencies
              .compactMap(\.module)
              .filter(isLiveModule)
              .map { dependency in
                SPMGraphConfig.Lint.Error.baseOrInterfaceModuleLiveDependency(
                  moduleName: module.name,
                  liveDependencyName: dependency.name
                )
              }
          }
          .reduce([], +)

        return errors
      }
    )
  }

  static let unusedDependencies = Self(
    id: "unusedDependencies",
    name: "Unused linked dependencies",
    abstract: """
      To keep the project clean and avoid long compile times, a Module should not have any unused dependencies.
      
      - Note: It does blindly expects the target to match the product name, and doesn't yet consider
      the multiple targets that compose a product (open improvement). 
      
      - Note: For `@_exported` usages, there will be an error in case only the exported module is used.
      For example, module Networking exports module NetworkingHelpers, if only NetworkingHelpers is used by a target
      there will be a lint error, while if both Networking and NetworkingHelpers are used there will be no error. 
      """,
    validate: { package, excludedSuffixes in
      let errors: [SPMGraphConfig.Lint.Error] = package.modules
        .filter { !$0.containsOneOf(suffixes: excludedSuffixes) && !$0.isFeature }
        .sorted()
        .compactMap { module in
          let dependencies = module
            .dependenciesFilteringOutLiveInUITestSupport
            .filter { dependency in
              let isExcluded = dependency.containsOneOf(suffixes: excludedSuffixes)
              return !isExcluded && dependency.shouldBeImported
            }
          let swiftFiles = try? findSwiftFiles(in: module.path.pathString)

          return dependencies.compactMap { dependency in
            let filePaths = swiftFiles ?? []
            var isDependencyUsed = false
            for filePath in filePaths {
              let fileContent = try? String(contentsOfFile: filePath, encoding: .utf8)
              let regexPattern =
                "import (enum |struct |class )?(\\b\(NSRegularExpression.escapedPattern(for: dependency.name))\\b)"
              if let regex = try? NSRegularExpression(pattern: regexPattern, options: []) {
                let range = NSRange(location: 0, length: fileContent?.utf16.count ?? 0)
                let match = regex.firstMatch(in: fileContent ?? "", options: [], range: range)
                if match != nil {
                  isDependencyUsed = true
                  break
                }
              }
            }

            return isDependencyUsed
              ? nil
              : SPMGraphConfig.Lint.Error.unusedDependencies(
                moduleName: module.name,
                dependencyName: dependency.name
              )
          }
        }
        .flatMap { $0 }
      return errors
    }
  )

  static func findSwiftFiles(in directory: String) throws -> [String] {
    let enumerator = FileManager.default.enumerator(atPath: directory)
    var swiftFiles = [String]()
    while let element = enumerator?.nextObject() as? String {
      if element.hasSuffix(".swift") {
        swiftFiles.append("\(directory)/\(element)")
      }
    }
    return swiftFiles
  }
}

public extension Module {
  var isFeature: Bool {
    name.contains("Feature")
  }

  var isLiveModule: Bool {
    name.hasSuffix("Live")
  }

  var isApp: Bool {
    name.contains("App") || name.hasSuffix("UI")
  }

  var isLiveTest: Bool {
    name.hasSuffix("LiveTests")
  }

  var isLiveTestSupport: Bool {
    name.contains("LiveTestSupport")
  }

  var isUITestSupport: Bool {
    name.contains("UITestSupport")
      || name.contains("UITestsSupport")  // with `s`
        && name != "ServerDrivenUITestSupport"
  }

  func containsOneOf(suffixes: [String]) -> Bool {
    suffixes.contains(where: name.hasSuffix)
  }

  var canDependOnLive: Bool {
    isFeature
      || isApp
      || isLiveTest
      || isLiveTestSupport
      || isUITestSupport
  }
}

public extension Module.Dependency {
  func containsOneOf(suffixes: [String]) -> Bool {
    suffixes.contains(where: name.hasSuffix)
  }
}

private extension Module.Dependency {
  /// Whether the dependency requires an import or not. For example, macros and plugins don't require an import clause.
  var shouldBeImported: Bool {
    guard let module else { return true }

    return module.type != .macro && module.type != .plugin
  }
}

private extension Module {
  var dependenciesFilteringOutLiveInUITestSupport: [Dependency] {
    guard isUITestSupport else { return dependencies }

    return dependencies.filter { dependency in
      let isLiveDependency = dependency.module?.isLiveModule ?? false
      return !isLiveDependency
    }
  }
}

extension Module: @retroactive Comparable {
  public static func < (lhs: Module, rhs: Module) -> Bool {
    lhs.name < rhs.name
  }
}

extension SPMGraphConfig.Lint {
  enum Error: LocalizedError {
    case liveModuleLiveDependency(moduleName: String, liveDependencyName: String)
    case baseOrInterfaceModuleLiveDependency(moduleName: String, liveDependencyName: String)
    case unusedDependencies(moduleName: String, dependencyName: String)

    var errorDescription: String? {
      switch self {
      case let .liveModuleLiveDependency(moduleName, liveDependencyName):
        return "\(moduleName) must not depend on Live Module \(liveDependencyName)"
      case let .baseOrInterfaceModuleLiveDependency(moduleName, liveDependencyName):
        return "\(moduleName) must not depend on Live Module \(liveDependencyName)"
      case let .unusedDependencies(moduleName, dependencyName):
        return "\(moduleName) is not using \(dependencyName)"
      }
    }
  }
}

func == <Root, Value: Equatable>(
  lhs: KeyPath<Root, Value>,
  rhs: Value
) -> (Root) -> Bool {
  { $0[keyPath: lhs] == rhs }
}

func != <Root, Value: Equatable>(
  lhs: KeyPath<Root, Value>,
  rhs: Value
) -> (Root) -> Bool {
  { $0[keyPath: lhs] != rhs }
}
