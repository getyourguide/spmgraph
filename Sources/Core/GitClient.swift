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

import Foundation

/// A helper for common git operations
public struct GitClient {
  public typealias BaseBranch = String

  /// List all files that changed on git when compared to a given `base branch`
  public var listChangedFiles: (BaseBranch) throws -> [String]
}

extension GitClient {
  /// Makes a **Live** ``GitClient`` instance
  public static func makeLive(
    system: SystemProtocol = System.shared
  ) -> Self {
    .init { baseBranch in
      // Get the root directory of git repository
      let rootDirectory =
        try system
        .runAndCapture("git", "rev-parse", "--show-toplevel")
        .trimmingCharacters(in: .whitespacesAndNewlines)

      // Get changed files
      let output = try system.runAndCapture(
        "git",
        "diff",
        "origin/\(baseBranch)...HEAD",
        "--name-only"
      )

      // Convert changed files relative paths to absolute paths
      let changedFiles =
        output
        .components(separatedBy: "\n")
        .filter { !$0.isEmpty }
        .map { "\(rootDirectory)/\($0)" }

      return changedFiles
    }
  }
}
