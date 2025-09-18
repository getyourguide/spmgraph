import ArgumentParser
import SPMGraphVisualize

struct VisualizeArguments: ParsableArguments {
  @OptionGroup var common: SPMGraphArguments

  @Option(
    name: [.customShort("f"), .customLong("focus", withSingleDash: false)],
    help: "Focus on a specific module by highlighting its edges (arrows) in a different color"
  )
  var focusedModule: String?

  @Flag(
    name: [.customShort("t"), .long],
    help: "Flag to exclude third-party dependencies from the graph declared in the `Package.swift`"
  )
  var excludeThirdPartyDependencies = false

  @Option(
    name: [.customShort("o"), .customLong("output", withSingleDash: false)],
    help:
      "Custom output file path for the generated PNG file. Default will generate a 'graph.png' file in the current directory"
  )
  var outputFilePath: String?

  @Option(
    name: [.customShort("s"), .long],
    help:
      "Minimum vertical spacing between the ranks (levels) of the graph. A double value in inches."
  )
  var rankSpacing: Double = 3
}

struct Visualize: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Generates a visual representation of your dependency graph",
    version: "1.0.0"
  )

  @OptionGroup var arguments: VisualizeArguments

  func run() async throws {
    let library = SPMGraphVisualize()
    try await library.run(
      input: SPMGraphVisualizeInput(
        spmPackageDirectory: arguments.common.spmPackageDirectory,
        excludedSuffixes: arguments.common.excludedSuffixes,
        focusedModule: arguments.focusedModule,
        excludeThirdPartyDependencies: arguments.excludeThirdPartyDependencies,
        outputFilePath: arguments.outputFilePath,
        rankSpacing: arguments.rankSpacing,
        verbose: arguments.common.verbose
      )
    )
  }
}
