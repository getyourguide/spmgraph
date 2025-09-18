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

  @Option(
    help: """
      A custom build directory used to build the package used to edit and load the SPMGraphConfig.
      It defaults to a temporary directory.

      Note: It enables controlling and caching the artifact that is generated from the user's `SPMGraphConfig` file.

      Warning: Ensure this is consistent across commands, otherwise your configuration won't be correctly loaded!
      """
  )
  var buildDirectory: String?
}

struct Load: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Loads your configuration into spmgraph.",
    discussion:
      "It dynamically loads your `SPMGraphConfig.swift` file into spmgraph so that it can be used by the tool and leveraged on all other commands.",
    version: "1.0.0"
  )

  @OptionGroup var arguments: LoadArguments

  mutating func run() async throws {
    let load = try SPMGraphLoad(
      input: try SPMGraphLoadInput(
        directory: arguments.directory,
        buildDirectory: arguments.buildDirectory,
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
