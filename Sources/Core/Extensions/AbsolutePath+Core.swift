import Basics
import Foundation

public extension AbsolutePath {
  /// The path to the program’s current directory.
  static var currentDir: AbsolutePath {
    guard let currentDir = localFileSystem.currentWorkingDirectory else {
      preconditionFailure("Unable to resolve the current directory")
    }
    return currentDir
  }
}

public extension AbsolutePath {
  static func packagePath(_ spmPackageDirectory: String) throws -> AbsolutePath {
    try AbsolutePath(
      validating: spmPackageDirectory,
      relativeTo: .currentDir
    )
  }

  static func buildDirectory(_ path: String?) throws -> AbsolutePath {
    if let path {
      try AbsolutePath(
        validating: path,
        relativeTo: .currentDir
      )
    } else {
      try localFileSystem.tempDirectory
    }
  }
}
