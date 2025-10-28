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

import GraphViz

extension Node {
  static func make(
    name: String,
    attributes: NodeStyleAttributes? = .internalInterfaceModule
  ) -> Node {
    var node = Node(name)
    let attributesToApply = node.customType?.attributes ?? attributes
    node.applyAttributes(attributes: attributesToApply)
    return node
  }

  enum CustomType {
    case live
    case tests
    case testSupport

    var attributes: NodeStyleAttributes {
      switch self {
      case .live: return .internalLiveModule
      case .tests: return .testModule
      case .testSupport: return .testSupportModule
      }
    }
  }

  var customType: CustomType? {
    switch id {
    case _ where id.hasSuffix("Tests"): return .tests
    case _ where id.hasSuffix("Live") || id.hasSuffix("Feature"): return .live
    case _ where id.hasSuffix("TestSupport"): return .testSupport
    default: return nil
    }
  }
}
