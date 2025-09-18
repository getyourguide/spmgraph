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

@main
struct SPMGraph: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Utilities for managing your Package.swift dependency graph",
    discussion: """
      Visualization, Selective testing, and Linting of a Package.swift dependency graph
      """,
    version: "1.0.0",
    subcommands: [
      Edit.self,
      Load.self,
      Tests.self,
      Lint.self,
      Visualize.self,
    ],
    defaultSubcommand: Visualize.self
  )
}
