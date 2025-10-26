import InterfaceModule

public struct LiveModule {
  private let interface = InterfaceModule()

  public init() {}

  public func liveFunction() -> String {
    "Live implementation with \(interface.interfaceFunction())"
  }
}
