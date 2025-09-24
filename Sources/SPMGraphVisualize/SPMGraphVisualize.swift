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
import GraphViz
import PackageModel

// MARK: - Input

public struct SPMGraphVisualizeInput {
  /// "Directory path of Package.swift file"
  let spmPackageDirectory: AbsolutePath
  /// Comma separated array of suffixes to exclude from the graph e.g. 'Tests','Live','TestSupport'
  let excludedSuffixes: [String]
  /// Focus on a specific module by highlighting its edges (arrows) in a different color
  let focusedModule: String?
  /// Flag to exclude third-party dependencies from the graph declared in the `Package.swift`
  let excludeThirdPartyDependencies: Bool
  /// Custom output file path for the generated PNG file. Default will generate a 'graph.png' file in the current directory
  let outputFilePath: AbsolutePath
  /// Minimum vertical spacing between the ranks (levels) of the graph. Default is set to 4. Is a double value in inches.
  let rankSpacing: Double
  /// Show extra logging for troubleshooting purposes
  let verbose: Bool

  /// Makes an instance of ``SPMGraphVisualize``
  public init(
    spmPackageDirectory: String,
    excludedSuffixes: [String],
    focusedModule: String?,
    excludeThirdPartyDependencies: Bool,
    outputFilePath: String?,
    rankSpacing: Double,
    verbose: Bool
  ) throws {
    self.spmPackageDirectory = try AbsolutePath.packagePath(spmPackageDirectory)
    self.excludedSuffixes = excludedSuffixes
    self.focusedModule = focusedModule
    self.excludeThirdPartyDependencies = excludeThirdPartyDependencies
    self.rankSpacing = rankSpacing
    self.verbose = verbose

    if let outputFilePath {
      self.outputFilePath = try AbsolutePath(
        validating: outputFilePath,
        relativeTo: .currentDir
      )
    } else {
      // the default output path
      self.outputFilePath = AbsolutePath.currentDir
        .appending(component: "graph")
        .appending(extension: "png")
    }
  }
}

// MARK: - Abstraction and Implementation

/// Represents a type that can generate a visual representation of a Package.swift dependency graph
public protocol SPMGraphVisualizeProtocol {
  func run(input: SPMGraphVisualizeInput) async throws
}

/// A type that can generate a visual representation of a Package.swift dependency graph
public final class SPMGraphVisualize: SPMGraphVisualizeProtocol {
  let packageLoader: PackageLoader
  let system: SystemProtocol

  private var shouldOpenImage: Bool {
    !ProcessInfo.isRunningTests && !ProcessInfo.isCI
  }

  /// Makes an instance of ``SPMGraphVisualize``
  public convenience init() {
    self.init(packageLoader: .live)
  }

  /// Makes an instance of ``SPMGraphVisualize``
  ///
  /// - Parameters:
  ///   - packageLoader: dependency used to load a Package.swift
  ///   - system: dependency used to run shell commands
  ///
  /// - note: Should be public whenever all dependencies are abstracted
  init(
    packageLoader: PackageLoader,
    system: SystemProtocol = System.shared
  ) {
    self.packageLoader = packageLoader
    self.system = system
  }

  /// Generates a visual representation of a Package.swift dependency graph
  /// - Parameters:
  ///  - input: A set of configuration inputs
  public func run(input: SPMGraphVisualizeInput) async throws {
    try GraphVizWrapper.installGraphVizIfNeeded()

    let package = try await packageLoader.load(
      input.spmPackageDirectory,
      input.verbose
    )

    try await generateDependencyGraphFile(package: package, input: input)
  }
}

// MARK: - Private

private extension SPMGraphVisualize {
  func generateDependencyGraphFile(
    package: Package,
    input: SPMGraphVisualizeInput
  ) async throws {
    let graph = generateDependencyGraph(package: package, input: input)

    try await withCheckedThrowingContinuation { continuation in
      // N.B.: gvRenderData may crash in Debug with a bad pointer (e.g. 0x100000000) when copying to `Data`.
      // Likely causes: C ABI mismatch, header/runtime mismatch, or concurrent use of a Graphviz context.
      // Mitigations: Run in release mode where the memory layout is different or enable the AddressSanitizer, which can mask the issue.
      graph.render(using: .dot, to: .png) { [weak self] result in
        guard let self else { return }

        switch result {
        case let .success(data):
          do {
            try data.write(to: input.outputFilePath.asURL)

            // Opens the generated graph unless running tests
            if self.shouldOpenImage {
              try self.system
                .run(
                  "open",
                  input.outputFilePath.pathString,
                  verbose: true
                )
            }
            continuation.resume(returning: ())
          } catch {
            continuation.resume(throwing: error)
          }
        case let .failure(error):
          continuation.resume(throwing: error)
        }
      }
    }
  }

  func generateDependencyGraph(
    package: Package,
    input: SPMGraphVisualizeInput
  ) -> Graph {
    var graph = Graph(directed: true)
    var nodes = [Node]()
    var thirdParties = [Node]()

    package.modules.forEach { module in
      guard
        !containsExcludedSuffix(
          moduleName: module.name,
          excludedSuffixes: input.excludedSuffixes
        )
      else { return }

      // Theming for test and testSupport
      let fromNode = Node.make(name: module.name)
      nodes.append(fromNode)

      let externalDependencies = package.externalDependencies(forModuleName: module.name)

      if !input.excludeThirdPartyDependencies {
        externalDependencies
          .map(\.name)
          .forEach { name in
            let thirdPartyNode = Node.make(name: name, attributes: .thirdParty)
            thirdParties.append(thirdPartyNode)
            graph.append(
              Edge.make(
                from: fromNode,
                to: thirdPartyNode,
                strokeColor: .named(
                  .makeNonHighlightedEdgeStrokeColor(hasFocusedModule: input.focusedModule != nil)
                )
              )
            )
          }
      }
      module
        .dependencies
        .compactMap(\.module)
        .forEach { dependency in
          guard
            !containsExcludedSuffix(
              moduleName: dependency.name,
              excludedSuffixes: input.excludedSuffixes
            )
          else { return }

          let dependencyNode = Node.make(name: dependency.name)
          nodes.append(dependencyNode)

          var isHighlighted = false
          if let focusedModule = input.focusedModule {
            isHighlighted =
              fromNode.id == focusedModule
              || dependencyNode.id == focusedModule
          }

          graph.append(
            Edge.make(
              from: fromNode,
              to: dependencyNode,
              strokeColor: .named(
                isHighlighted
                  ? .red
                  : .makeNonHighlightedEdgeStrokeColor(hasFocusedModule: input.focusedModule != nil)
              )
            )
          )
        }
    }

    graph.rankSeparation = input.rankSpacing

    let sortedNodes = Set(nodes + thirdParties).sorted { $0.id < $1.id }
    graph.append(contentsOf: sortedNodes)

    return graph
  }
}

private extension GraphViz.Color.Name {
  static func makeNonHighlightedEdgeStrokeColor(
    hasFocusedModule: Bool
  ) -> Self {
    hasFocusedModule
      ? .lightgray
      : .gray1
  }
}
