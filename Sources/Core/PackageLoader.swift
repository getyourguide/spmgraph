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
import PackageModel
import Workspace

/// Loads the content of a Package.swift, the dependency graph included
///
/// The ``PackageLoader`` uses the SPM library to load the package representation
public struct PackageLoader: Sendable {
  /// Asynchronously loads the Package.swift file located at the provided `packagePath`.
  /// - Parameters:
  ///   - packagePath: The path to the Package.swift file to load.
  ///   - verbose: A Boolean indicating whether to log detailed debug information during the loading process.
  /// - Returns: The `Package` object constructed from the Package.swift file.
  /// - Throws: If there is an error loading the Package.swift file.
  public var load: @Sendable (AbsolutePath, _ verbose: Bool) async throws -> Package
}

extension PackageLoader {
  /// Makes a **Live** ``PackageLoader`` instance
  public static let live: Self = {
    .init(
      load: { packagePath, verbose in
        let observability = ObservabilitySystem { if verbose { print("\($0): \($1)") } }

        let workspace = try Workspace(forRootPackage: packagePath)

        return try await workspace.loadRootPackage(
          at: packagePath,
          observabilityScope: observability.topScope
        )
      }
    )
  }()
}
