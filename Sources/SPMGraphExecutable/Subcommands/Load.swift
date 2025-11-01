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
import SPMGraphConfigSetup

struct LoadArguments: ParsableArguments {
  @Flag(
    name: [.customLong("verbose"), .customShort("v")],
    help: "Show extra logging for troubleshooting purposes."
  )
  var verbose: Bool = false

  @Argument(
    help: "Directory path of the SPMGraphConfig.swift file. The same as the `Package.swift` file."
  )
  var directory: String

  @OptionGroup
  var config: SPMGraphConfigArguments
}

struct Load: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Loads your configuration into spmgraph.",
    discussion:
      "It dynamically loads your `SPMGraphConfig.swift` file into spmgraph so that it can be used by the tool and leveraged on all other commands.",
    version: "1.0.1"
  )

  @OptionGroup var arguments: LoadArguments

  mutating func run() async throws {
    let load = try SPMGraphLoad(
      input: try SPMGraphLoadInput(
        directory: arguments.directory,
        configBuildDirectory: arguments.config.configBuildDirectory,
        verbose: arguments.verbose
      )
    )
    try load.run()
  }
}

extension CleanExit {
  static func make(from error: SPMGraphLoadError) -> Self {
    switch error {
    case let .failedToReadTheConfig(underlyingError):
      CleanExit.message(
        """
        Unable to load your SPMGraphConfig.swift into spmgraph
        Error: Unable to load the configuration and get the build directory with error: \(underlyingError.localizedDescription)
        """
      )
    case let .failedToLoadTheConfigIntoSpmgraph(localizedDescription):
      CleanExit.message(
        """
        Failed to load your SPMGraphConfig.swift into spmgraph
        Error: \(localizedDescription)
        """
      )
    case let .failedToSetupDynamicLoading(underlyingError):
      CleanExit.message(
        """
        Failed to load your SPMGraphConfig.swift into spmgraph
        Error: Failed to configure it for dynamic loading with error: \(underlyingError.localizedDescription)
        """
      )
    }
  }
}
