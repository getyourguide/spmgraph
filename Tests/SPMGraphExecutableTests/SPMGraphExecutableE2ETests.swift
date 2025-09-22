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

import Basics
import Foundation
import Testing

@Suite(.serialized)
struct SPMGraphExecutableE2ETests {
  // auto reset to its initial value before it test runs
  private let process = Process()
  private let outputPipe = Pipe()
  private let errorPipe = Pipe()

  @Test(
    arguments: [
      "",
      "visualize ",
      "tests ",
      "config ",
      "load ",
      "lint ",
    ]
  )
  func help(command: String) throws {
    try runToolProcess(command: "\(command)--help")
    assertProcess()
  }

  /// Tests the visualize feature
  ///
  /// - warning: For this to work it has to be run via the spmgraph testplan, where the Address Sanitizer is enabled,
  /// which works around potential memory crashes with graphviz in debug
  @Test(.enabled(if: ProcessInfo.isSpmgraphTestPlan))
  func visualize() async throws {
    // GIVEN
    let outputPath = try localFileSystem.tempDirectory
      .appending(component: "graph")
      .appending(extension: "png")

    // WHEN
    try runToolProcess(command: "visualize \(AbsolutePath.fixturePackagePath) -o \(outputPath)")

    // THEN
    assertProcess()

    #expect(localFileSystem.exists(outputPath))

    // Cleanup
    try localFileSystem.removeFileTree(outputPath)
  }

  @Test(arguments: ["textDump", "textFile"])
  func tests(outputMode: String) throws {
    // GIVEN
    let changedFilePath = AbsolutePath.fixturePackagePath
      .appending(component: "Sources")
      .appending(component: "TargetB")
      .appending(component: "Example")
      .appending(extension: "swift")

    // WHEN
    try runToolProcess(
      command: "tests \(AbsolutePath.fixturePackagePath) --files \(changedFilePath) --output \(outputMode)"
    )

    // THEN
    assertProcess(
      outputContains: outputMode == "textDump"
      ? "TargetBTests,TargetATests"
      : "saved the formatted list of test modules to"
    )

    if outputMode == "textFile" {
      let outputPath = try #require(localFileSystem.currentWorkingDirectory)
        .appending(component: "output")
        .appending(extension: "txt")
      #expect(localFileSystem.exists(outputPath))
    }
  }

  @Test func initialConfig() async throws {
    // WHEN
    try runToolProcess(
      command: "config \(AbsolutePath.fixturePackagePath) -d \(AbsolutePath.buildDir)",
      waitForExit: false
    )

    // THEN
    #expect(
      localFileSystem.exists(.configPackagePath),
      "It creates the config package in the buildDir"
    )
    #expect(
      try localFileSystem.getDirectoryContents(.configPackagePath) ==
      [
        "Package.swift",
        "Sources"
      ]
    )

    #expect(
      localFileSystem.exists(
        AbsolutePath.fixturePackagePath.appending(component: "SPMGraphConfig.swift")
      ),
      "It creates a spmgraph config file in the same dir as the Package"
    )

    process.terminate()
    assertProcess()

    // The config package outlives the process
    #expect(localFileSystem.exists(.configPackagePath))

    // Cleanup
    try localFileSystem.removeFileTree(.userConfigFilePath)
    try localFileSystem.removeFileTree(.dirtyConfigFilePath)
    try localFileSystem.removeFileTree(.configPackagePath)
  }

  @Test func configWhenEditing() async throws {
    // GIVEN
    createUserConfigFile()
    try stubUserConfigFile()

    // WHEN
    let buildDir = try localFileSystem.tempDirectory
      .appending(component: "buildDir")
    try runToolProcess(
      command: "config \(AbsolutePath.fixturePackagePath) -d \(buildDir)",
      waitForExit: false
    )

    // THEN

    // It creates the config package in the buildDir
    #expect(localFileSystem.exists(.configPackagePath))
    #expect(
      try localFileSystem.getDirectoryContents(.configPackagePath) ==
      [
        "Package.swift",
        "Sources"
      ]
    )
    #expect(
      try localFileSystem.getDirectoryContents(.configPackageSources) ==
      [
        "SPMGraphConfig.swift"
      ]
    )
    #expect(
      try localFileSystem.readFileContents(.configPackageConfigFile) ==
      .userConfigStub
    )

    // WHEN - the user config file is updated

    let updatedConfigContent = """
      import Foundation
      import PackageModel
      import SPMGraphDescriptionInterface
      
      let spmGraphConfig = SPMGraphConfig(
        lint: SPMGraphConfig.Lint(isStrict: true)
      )
      """
    try stubUserConfigFile(with: updatedConfigContent)

    try await Task.sleep(for: .seconds(1))

    // THEN
    #expect(
      try localFileSystem.readFileContents(.userConfigFilePath) ==
      updatedConfigContent,
      "The user spmgraph config file should be updated reflecting the changes done"
    )

    process.terminate()
    assertProcess()

    // The config package outlives the process
    #expect(localFileSystem.exists(.configPackagePath))

    // Cleanup
    try localFileSystem.removeFileTree(.userConfigFilePath)
    try localFileSystem.removeFileTree(.dirtyConfigFilePath)
  }

  /// Tests the `load functionality`, which feeds the user configuration into spmgraph, by building it and dynamically loading it's dylib.
  ///
  /// - warning: It depends on the serial execution of the tests and on the config package being loaded into memory beforehand.
  ///
  /// - note: This could be improved to rely on two separate `Process`s to run both `config` and `load` in sequence,
  /// instead of relying on the serial order of tests.
  @Test func testLoad() async throws {
    createUserConfigFile()
    try stubUserConfigFile()

    let buildDir = try localFileSystem.tempDirectory
      .appending(component: "buildDir")

    try runToolProcess(
      command: "load \(AbsolutePath.fixturePackagePath) -d \(buildDir)",
      waitForExit: true
    )
    assertProcess()
  }

  /// Tests the `lint functionality`, which depends on the the user config being loaded into spmgraph.
  ///
  /// - warning: It depends on the serial execution of the tests and on the user config dylib being generated.
  ///
  /// - note: This could be improved to rely on two separate `Process`s to run `config`, `load` and `lint` in sequence,
  /// instead of relying on the serial order of tests.
  @Test func testLint() async throws {
    let outputPath = "lint_output"

    try runToolProcess(
      command: "lint \(AbsolutePath.fixturePackagePath) --strict -o \(outputPath) -d \(AbsolutePath.buildDir)",
      waitForExit: true
    )
    assertProcess()

    let outputAbsolutePath = try #require(localFileSystem.currentWorkingDirectory)
      .appending(component: "lint_output")
      .appending(extension: "txt")
    #expect(localFileSystem.exists(outputAbsolutePath))
  }
}

// MARK: - Helpers

private extension SPMGraphExecutableE2ETests {
  func runToolProcess(
    command: String,
    waitForExit: Bool = true
  ) throws {
    let commands = command.split(whereSeparator: \.isWhitespace)

    var arguments: [String]
    if commands.count > 1 {
      arguments = commands.map { String($0) }
    } else {
      arguments = command
        .split { [" -", " --"].contains(String($0)) }
        .map { String($0) }
    }

    let executableURL = Bundle.productsDirectory.appendingPathComponent("spmgraph")

    process.executableURL = executableURL
    process.arguments = arguments
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    try process.run()
    if waitForExit {
      process.waitUntilExit()
    }
  }

  func assertProcess(
    expectsError: Bool = false,
    outputContains: String? = nil,
    _ sourceLocation: SourceLocation = #_sourceLocation
  ) {
    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let outputContent = String(data: outputData, encoding: .utf8) ?? ""
    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
    let errorContent = String(data: errorData, encoding: .utf8) ?? ""

    #expect(
      errorContent.isEmpty != expectsError, "Found error: \(errorContent)",
      sourceLocation: sourceLocation
    )

    if let outputContains {
      #expect(
        outputContent.contains(outputContains),
        sourceLocation: sourceLocation
      )
    }
  }

  func createUserConfigFile() {
    localFileSystem.createEmptyFiles(
      at: .fixturePackagePath,
      files: "SPMGraphConfig.swift"
    )

    if !localFileSystem.exists(.userConfigFilePath) {
      Issue.record("Missing SPMGraphConfig.swift fixture file")
    }
  }

  func stubUserConfigFile(with content: String = .userConfigStub) throws {
    try localFileSystem.writeFileContents(
      .userConfigFilePath,
      string: content
    )
  }
}

private extension ProcessInfo {
  static var isSpmgraphTestPlan: Bool {
    processInfo.environment["TESTPLAN"] == "spmgraph"
  }
}

private extension Bundle {
  /// Returns path to the built products directory.
  static var productsDirectory: URL {
    #if os(macOS)
    for bundle in allBundles where bundle.bundlePath.hasSuffix(".xctest") {
      return bundle.bundleURL.deletingLastPathComponent()
    }
    fatalError("couldn't find the products directory")
    #else
    return main.bundleURL
    #endif
  }
}

private extension AbsolutePath {
  static var fixturePackagePath: AbsolutePath {
    do {
      return try AbsolutePath(
        validating: "../../Fixtures/Package",
        relativeTo: .init(validating: #filePath)
      )
    } catch {
      Issue.record("Unable to resolve fixture package path")
      preconditionFailure("Unable to resolve fixture package path")
    }
  }

  static var buildDir: AbsolutePath {
    do {
      return try localFileSystem.tempDirectory
        .appending(component: "buildDir")
    } catch {
      Issue.record("Unable to resolve custom build directory path")
      preconditionFailure("Unable to resolve custom build directory path")
    }
  }

  static let configPackagePath: AbsolutePath = buildDir.appending(component: "spmgraph-config")
  static let configPackageSources = configPackagePath
    .appending("Sources")
    .appending("SPMGraphConfig")
  static let configPackageConfigFile = configPackagePath
    .appending("Sources")
    .appending("SPMGraphConfig")
    .appending("SPMGraphConfig.swift")

  static let userConfigFilePath: AbsolutePath = fixturePackagePath
    .appending(component: "SPMGraphConfig.swift")
  static let dirtyConfigFilePath: AbsolutePath = fixturePackagePath
    .appending(component: "PMGraphConfig.swift")
}

private extension String {
  static let userConfigStub: String = """
    import Foundation
    import PackageModel
    import SPMGraphDescriptionInterface
    
    let spmGraphConfig = SPMGraphConfig.default
    """
}
