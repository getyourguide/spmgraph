// Inspired by and mainly copied from https://github.com/tuist/tuist/blob/cf57cbcc8ef5574b0be717ce620c35e1a8f3fb5a/Sources/TuistSupport/System/System.swift

import Foundation
import TSCBasic

/// Defines the API to interact with the system shell
///
/// - note: It heavily relies on variadic parameters, thus the decision to use a gold old protocol based API,
/// as of now variadic args are still quite limited and not allowed in tuples
public protocol SystemProtocol: AnyObject {
  /// Run a shell command and capture the output
  /// - Returns: `utf8` formatted `String` output
  @discardableResult
  func runAndCapture(_ arguments: String...) throws -> String

  /// Run a shell command in a specific directory and capture the output
  /// - Returns: `utf8` formatted `String` output
  @discardableResult
  func runAndCapture(_ arguments: String..., workingDirectory: AbsolutePath) throws -> String

  /// Runs a shell command and prints its output
  func run(
    _ arguments: String...,
    verbose: Bool
  ) throws

  /// Runs a shell command in a specific directory and prints its output
  func run(
    _ arguments: String...,
    workingDirectory: AbsolutePath,
    verbose: Bool
  ) throws

  /// Run an echo command
  func echo(
    _ command: String
  ) throws

  static var env: [String: String] { get }
}

/// Implements the API to interact with the system shell
// N.B.: Unchecked Sendable should be fine because System is a fire and forget shell client
// that doesn't have any shared mutable state
public final class System: SystemProtocol, @unchecked Sendable {
  public static let shared = System()

  /// Helper to access the current env
  public static let env = ProcessInfo.processInfo.environment

  /// Run a shell command and capture the output
  /// - Returns: `utf8` formatted `String` output
  @discardableResult
  public func runAndCapture(_ arguments: String...) throws -> String {
    let process = Process(
      arguments: arguments,
      environmentBlock: ProcessEnvironmentBlock(System.env),
      outputRedirection: .collect,
      startNewProcessGroup: false
    )

    try process.launch()
    let result = try process.waitUntilExit()
    try result.throwIfErrored()

    return try result.utf8Output()
  }

  /// Run a shell command in a specific directory and capture the output
  /// - Returns: `utf8` formatted `String` output
  @discardableResult
  public func runAndCapture(
    _ arguments: String...,
    workingDirectory: AbsolutePath
  ) throws -> String {
    let process = Process(
      arguments: arguments,
      environmentBlock: ProcessEnvironmentBlock(System.env),
      workingDirectory: workingDirectory,
      outputRedirection: .collect,
      startNewProcessGroup: false
    )

    try process.launch()
    let result = try process.waitUntilExit()
    try result.throwIfErrored()

    return try result.utf8Output()
  }

  /// Run an echo command
  public func echo(
    _ command: String
  ) throws {
    try run(
      "echo",
      command,
      verbose: true
    )
  }

  /// Runs a shell command and prints its output
  public func run(
    _ arguments: String...,
    verbose: Bool = true
  ) throws {
    let redirection: TSCBasic.Process.OutputRedirection = .none
    let process = Process(
      arguments: arguments,
      outputRedirection: .stream(
        stdout: { bytes in
          FileHandle.standardOutput.write(Data(bytes))
          redirection.outputClosures?.stdoutClosure(bytes)
        },
        stderr: { bytes in
          FileHandle.standardError.write(Data(bytes))
          redirection.outputClosures?.stderrClosure(bytes)
        }
      ),
      startNewProcessGroup: false
    )

    try launchAndRunProcess(process, verbose: verbose)
  }

  /// Runs a shell command in a specific directory and prints its output
  public func run(
    _ arguments: String...,
    workingDirectory: AbsolutePath,
    verbose: Bool = true
  ) throws {
    let redirection: TSCBasic.Process.OutputRedirection = .none
    let process = Process(
      arguments: arguments,
      workingDirectory: workingDirectory,
      outputRedirection: .stream(
        stdout: { bytes in
          FileHandle.standardOutput.write(Data(bytes))
          redirection.outputClosures?.stdoutClosure(bytes)
        },
        stderr: { bytes in
          FileHandle.standardError.write(Data(bytes))
          redirection.outputClosures?.stderrClosure(bytes)
        }
      ),
      startNewProcessGroup: false
    )

    try launchAndRunProcess(process, verbose: verbose)
  }
}

private extension System {
  func launchAndRunProcess(
    _ process: TSCBasic.Process,
    verbose: Bool
  ) throws {
    try process.launch()
    let result = try process.waitUntilExit()
    let output = try result.utf8Output()
    if verbose {
      print(output)
    }

    try result.throwIfErrored()
  }
}

extension ProcessResult {
  /// Throws a SystemError if the result is unsuccessful.
  ///
  /// - Throws: A SystemError.
  func throwIfErrored() throws {
    switch exitStatus {
    case let .signalled(code):
      let data = Data(try stderrOutput.get())
      throw SystemError.signalled(command: command(), code: code, standardError: data)
    case let .terminated(code):
      if code != 0 {
        let data = Data(try stderrOutput.get())
        throw SystemError.terminated(command: command(), code: code, standardError: data)
      }
    }
  }

  /// It returns the command that the process executed.
  /// If the command is executed through xcrun, then the name of the tool is returned instead.
  /// - Returns: Returns the command that the process executed.
  func command() -> String {
    let command = arguments.first!
    if command == "/usr/bin/xcrun" {
      return arguments[1]
    }
    return command
  }
}

enum SystemError: Error, Equatable {
  case terminated(command: String, code: Int32, standardError: Data)
  case signalled(command: String, code: Int32, standardError: Data)

  var description: String {
    switch self {
    case let .signalled(command, code, data):
      if data.count > 0, let string = String(data: data, encoding: .utf8) {
        return "The '\(command)' was interrupted with a signal \(code) and message:\n\(string)"
      } else {
        return "The '\(command)' was interrupted with a signal \(code)"
      }
    case let .terminated(command, code, data):
      if data.count > 0, let string = String(data: data, encoding: .utf8) {
        return "The '\(command)' command exited with error code \(code) and message:\n\(string)"
      } else {
        return "The '\(command)' command exited with error code \(code)"
      }
    }
  }
}

public enum ANSIColor: String, CaseIterable {
  case black = "\u{001B}[30m"
  case red = "\u{001B}[31m"
  case green = "\u{001B}[32m"
  case yellow = "\u{001B}[33m"
  case blue = "\u{001B}[34m"
  case magenta = "\u{001B}[35m"
  case cyan = "\u{001B}[36m"
  case white = "\u{001B}[37m"
  case `default` = "\u{001B}[38m"
  case reset = "\u{001B}[0m"
}

public enum FontStyle: String, CaseIterable {
  case `default` = ""
  case bold = "\u{001B}[1m"
}
