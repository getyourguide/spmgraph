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

struct Edit: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract:
      "Initializes or edit your spmgraph configuration, including your dependency graph rules written in Swift.",
    discussion: """
      It looks for an `SPMGraphConfig.swift` file in the same directory as the `Package.swift` under analyzes. If there's none, it creates a fresh one from a template.

      Next, it generates a temporary package for editing your `SPMGraphConfig.swift`, where you customize multiple settings, from the expected warnings count to
      writing your own dependency graph rules in Swift code.

      Once the `SPMGraphConfig.swift` is edited, your configuration is dynamic loaded into spmgraph and leveraged on all other commands.  
      """,
    version: "1.0.0"
  )

  @OptionGroup var arguments: EditArguments

  mutating func run() async throws {
    let spmgraphEdit = try SPMGraphEdit(
      input: SPMGraphEditInput(
        spmPackageDirectory: arguments.spmPackageDirectory,
        buildDirectory: arguments.buildDirectory,
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
