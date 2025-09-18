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
import SPMGraphTests

struct TestsArguments: ParsableArguments {
  @OptionGroup var common: SPMGraphArguments

  @Option(
    name: [.customLong("files"), .customLong("changedFiles")],
    help: "Optional list of changed files. Otherwise git versioning is used"
  )
  var changedFiles: [String] = []  // TODO: Change to AbsolutePath

  @Option(
    name: [.customLong("baseBranch"), .customLong("branch"), .short],
    help: "Base branch to compare the changes against"
  )
  var baseBranch: String?

  @Option(
    name: [.customLong("output"), .customLong("outputMode"), .short],
    help:
      "The output mode. Options are: \(SPMGraphTests.OutputMode.allCases.map(\.rawValue).joined(separator: ", "))"
  )
  var outputMode: SPMGraphTests.OutputMode = .textDump

  // TODO: Review if gitDir options is needed - generally git is in the root dir of the root Package
}

struct Tests: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract:
      "Selective testing. It maps modules that should be built and test modules that should be run based on git changes or a set of changed files.",
    discussion: """
      Given changed files, it traverses the dependency graph and defines which modules were affected.
      Useful to optimize for building and running tests only for what changed.
      """,
    version: "1.0.0"
  )

  @OptionGroup var arguments: TestsArguments

  mutating func run() async throws {
    let library = try SPMGraphTests(
      input: SPMGraphTestsInput(
        spmPackageDirectory: arguments.common.spmPackageDirectory,
        buildDirectory: arguments.common.buildDirectory,
        excludedSuffixes: arguments.common.excludedSuffixes,
        changedFiles: arguments.changedFiles,
        baseBranch: arguments.baseBranch,
        outputMode: arguments.outputMode,
        verbose: arguments.common.verbose
      )
    )
    try await library.run()
  }
}

extension SPMGraphTests.OutputMode: ExpressibleByArgument {
  public init?(argument: String) {
    self.init(rawValue: argument)
  }
}
