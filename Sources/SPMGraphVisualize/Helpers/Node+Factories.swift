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
