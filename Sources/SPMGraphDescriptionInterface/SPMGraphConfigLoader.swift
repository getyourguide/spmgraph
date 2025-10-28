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

public enum SPMGraphConfigLoaderError: LocalizedError {
  case failedToLoadUserConfiguration(reason: String)

  public var errorDescription: String? {
    switch self {
    case let .failedToLoadUserConfiguration(reason):
      """
      Failed to load the `SPMGraphConfig.swift` file! Check if it exists and builds successfully by running `spmgraph config`.
      If it does exist and builds well, run `spmgraph load` and wait for your configuration to be loaded into spmgraph.
      Reason: \(reason)
      """
    }
  }
}

public protocol SPMGraphConfigLoading {
  func load(buildDirectory: AbsolutePath) throws(SPMGraphConfigLoaderError) -> SPMGraphConfig
}

public struct SPMGraphConfigLoader: SPMGraphConfigLoading {
  public init() {}

  public func load(buildDirectory: AbsolutePath) throws(SPMGraphConfigLoaderError) -> SPMGraphConfig
  {
    do {
      let spmgraphConfigDirectory = buildDirectory.appending("spmgraph-config")
      let spmGraphConfig = try plugin(
        at: "\(spmgraphConfigDirectory.pathString)/.build/debug/libSPMGraphDescription.dylib"
      )
      return spmGraphConfig
    } catch {
      throw error
    }
  }

  private typealias InitFunction = @convention(c) () -> UnsafeMutableRawPointer

  private func plugin(at path: String) throws(SPMGraphConfigLoaderError) -> SPMGraphConfig {
    let dlopenReference = dlopen(path, RTLD_NOW | RTLD_LOCAL)
    if dlopenReference != nil {
      defer {
        dlclose(dlopenReference)
      }

      let symbolName = "loadSPMGraphConfig"
      let dlsymReference = dlsym(dlopenReference, symbolName)

      if dlsymReference != nil {
        let initFunction: InitFunction = unsafeBitCast(dlsymReference, to: InitFunction.self)
        let pluginPointer = initFunction()
        let builder = Unmanaged<SPMGraphConfigBuilder>.fromOpaque(pluginPointer).takeRetainedValue()
        return builder.build()
      } else {
        throw .failedToLoadUserConfiguration(
          reason: "error loading lib: symbol \(symbolName) not found, path: \(path)"
        )
      }
    } else {
      if let error = dlerror() {
        throw .failedToLoadUserConfiguration(
          reason: "error opening dylib: \(String(format: "%s", error)), path: \(path)"
        )
      } else {
        throw .failedToLoadUserConfiguration(
          reason: "error opening dylib: unknown error, path: \(path)"
        )
      }
    }
  }
}
