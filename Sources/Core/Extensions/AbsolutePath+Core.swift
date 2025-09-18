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
