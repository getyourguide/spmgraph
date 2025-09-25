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

import ArgumentParser
import Foundation

struct SPMGraphArguments: ParsableArguments {
  @Option(
    name: [.customShort("e"), .long],
    help:
      "Comma separated array of suffixes to exclude from the graph e.g. 'Tests','Live','TestSupport'"
  )
  var excludedSuffixes: [String] = []

  @Argument(
    help: "Directory path of the Package.swift file"
  )
  var spmPackageDirectory: String

  @Flag(
    name: [.customLong("verbose"), .customShort("v")],
    help: "Show extra logging for troubleshooting purposes."
  )
  var verbose: Bool = false
}

struct SPMGraphConfigArguments: ParsableArguments {
  @Option(
    name: [.long, .customLong("build-dir"), .customShort("d")],
    help: """
      **For users that leverage the lint capability and rely on the `SPMGraphConfig.swift` file**.
      
      A custom build directory that enables CI controlling and caching of the package used to edit and load the SPMGraphConfig.
      It defaults to a temporary directory, which works consistently for local runs.
      
      - **Warning**: Ensure this is consistent across commands, otherwise your configuration won't be correctly loaded!
      """
  )
  var configBuildDirectory: String?
}

@main
struct SPMGraph: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Utilities for managing your Package.swift dependency graph",
    discussion: """
      Visualization, Selective testing, and Linting of a Package.swift dependency graph
      """,
    version: "0.0.7",
    subcommands: [
      Config.self,
      Load.self,
      Tests.self,
      Lint.self,
      Visualize.self,
    ],
    defaultSubcommand: Visualize.self
  )
}
