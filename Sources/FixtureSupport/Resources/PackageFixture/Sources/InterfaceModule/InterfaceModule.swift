import BaseModule

public protocol InterfaceModuleProtocol {
  func interfaceFunction() -> String
}

public struct InterfaceModule: InterfaceModuleProtocol {
  private let base = BaseModule()

  public init() {}

  public func interfaceFunction() -> String {
    "Interface Module with \(base.baseFunction())"
  }
}
