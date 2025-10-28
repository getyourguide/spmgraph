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

import Foundation
import GraphViz

extension GraphViz.Node {
  mutating func applyAttributes(attributes: NodeStyleAttributes?) {
    self.fillColor = attributes?.fillColor
    self.textColor = attributes?.textColor
    self.strokeWidth = attributes?.strokeWidth
    self.shape = attributes?.shape
    self.fontName = attributes?.fontName
  }
}

struct NodeStyleAttributes: Sendable {
  let fillColor: GraphViz.Color?
  var textColor: GraphViz.Color?
  let strokeWidth: Double?
  let shape: GraphViz.Node.Shape?
  let fontName: String?

  init(
    fillColorName: GraphViz.Color.Name? = nil,
    textColorName: GraphViz.Color.Name? = nil,
    strokeWidth: Double? = nil,
    shape: GraphViz.Node.Shape? = nil,
    fontName: String? = nil
  ) {
    fillColor = fillColorName.map { GraphViz.Color.named($0) }
    textColor = textColorName.map { GraphViz.Color.named($0) }
    self.strokeWidth = strokeWidth
    self.shape = shape
    self.fontName = fontName
  }
}

extension GraphViz.Color: @unchecked @retroactive Sendable {}
extension GraphViz.Node.Shape: @unchecked @retroactive Sendable {}

extension NodeStyleAttributes {
  static let internalInterfaceModule = Self(
    fillColorName: .lightblue,
    shape: .rectangle,
    fontName: .sfMonoRegular
  )
  static let internalLiveModule = Self(
    fillColorName: .coral,
    shape: .box3d,
    fontName: .sfMonoRegular
  )
  static let thirdParty = Self(
    fillColorName: .aquamarine,
    shape: .oval,
    fontName: .sfMonoRegular
  )
  static let testModule = Self(
    fillColorName: .green,
    shape: .octagon,
    fontName: .sfMonoRegular
  )
  static let testSupportModule = Self(
    fillColorName: .green2,
    shape: .trapezium,
    fontName: .sfMonoRegular
  )
}

private extension String {
  static let sfMonoRegular = "SF Mono Regular"
}
