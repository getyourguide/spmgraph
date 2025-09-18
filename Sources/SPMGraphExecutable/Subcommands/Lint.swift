import ArgumentParser
import SPMGraphLint

struct LintArguments: ParsableArguments {
  @OptionGroup var common: SPMGraphArguments

  @Flag(
    name: [.short, .long],
    help: "Fails on warnings"
  )
  var strict: Bool = false

  @Option(
    name: [.customShort("o"), .customLong("output", withSingleDash: false)],
    help:
      "Relative path for an output file with the formatted lint results. By default the errors are only dumped into the sdtout."
  )
  var outputFilePath: String?

  @Option(
    name: [.customShort("c"), .customLong("warningsCount", withSingleDash: false)],
    help:
      "The number of allowed warnings for the strict mode. note: It can be useful to **bypass the strict mode in specific scenarios**. `The default is zero`."
  )
  public var expectedWarningsCount: UInt = 0
}

struct Lint: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract:
      "Lints your Package.swift dependency graph and uncovers configuration issues. Arguments take precedence over the matching `SPMGraphConfig.swift` options.",
    discussion: """
        Run checks on a given Package.swift and raises configuration issues and potential optimisations
        that otherwise would be bubbled up by the build system later on.
      """,
    version: "1.0.0"
  )

  @OptionGroup var arguments: LintArguments

  mutating func run() async throws {
    let library = try SPMGraphLint(
      input: SPMGraphLintInput(
        spmPackageDirectory: arguments.common.spmPackageDirectory,
        buildDirectory: arguments.common.buildDirectory,
        excludedSuffixes: arguments.common.excludedSuffixes,
        isStrict: arguments.strict,
        verbose: arguments.common.verbose,
        expectedWarningsCount: arguments.expectedWarningsCount,
        outputFilePath: arguments.outputFilePath
      )
    )
    try await library.run()
  }
}

extension CommandConfiguration: @unchecked @retroactive Sendable {}
