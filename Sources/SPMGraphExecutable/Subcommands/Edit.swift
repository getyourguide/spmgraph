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

struct EditArguments: ParsableArguments {
  @Flag(
    name: [.customLong("verbose"), .customShort("v")],
    help: "Show extra logging for troubleshooting purposes."
  )
  var verbose: Bool = false

  @Argument(
    help: "Directory path of the Package.swift file"
  )
  var spmPackageDirectory: String

  @OptionGroup
  var config: SPMGraphConfigArguments
}

struct Edit: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract:
      "Initializes or edit your spmgraph configuration, including your dependency graph rules written in Swift.",
    discussion: """
      It looks for an `SPMGraphConfig.swift` file in the same directory as the `Package.swift` under analyzes. If there's none, it creates a fresh one from a template.

      Next, it generates a temporary package for editing your `SPMGraphConfig.swift`, where you customize multiple settings, from the expected warnings count to writing your own dependency graph rules in Swift code.

      Once the `SPMGraphConfig.swift` is edited, your configuration is dynamically loaded into spmgraph and leveraged on all other commands.  
      """,
    version: "1.0.0"
  )

  @OptionGroup var arguments: EditArguments

  mutating func run() async throws {
    let spmgraphEdit = try SPMGraphEdit(
      input: SPMGraphEditInput(
        spmPackageDirectory: arguments.spmPackageDirectory,
        configBuildDirectory: arguments.config.configBuildDirectory,
        verbose: arguments.verbose
      )
    )
    try await spmgraphEdit.run()
  }
}

extension CleanExit {
  static func make(from error: SPMGraphEditError) -> Self {
    switch error {
    case let .unableToLoadTemplates(bundle):
      CleanExit.message(
        """
        Unable to load the template files for generating the temporary Package
        Error: Missing resources in the bundle \(bundle)
        """
      )
    case let .failedToCreateOrLoadConfigFile(underlyingError):
      CleanExit.message(
        """
        Unable to create or load the user's SPMGraphConfig.swift file
        Error: \(underlyingError.localizedDescription)
        """
      )
    case let .failedToCreateEditPackage(underlyingError):
      CleanExit.message(
        """
        Unable to create a temporary project for editing the SPMGraphConfig.swift file
        Error: \(underlyingError.localizedDescription)
        """
      )
    case let .failedToCopyTemplateFile(underlyingError):
      CleanExit.message(
        """
        Unable to create a package for editing the SPMGraphConfig.swift file
        Error: Failed to copy template file with error \(underlyingError.localizedDescription)
        """
      )
    case let .failedToOpenEditPackageForEditing(underlyingError):
      CleanExit.message(
        """
        Unable open the project for editing the SPMGraphConfig.swift file
        Error: \(underlyingError.localizedDescription)
        """
      )
    case let .failedToObserveConfigFileChanges(underlyingError):
      CleanExit.message(
        """
        Unable to observe changes on the edited SPMGraphConfig.swift file and update spmgraph with it
        Error: \(underlyingError.localizedDescription)
        """
      )
    }
  }
}
