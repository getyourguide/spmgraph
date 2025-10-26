import InterfaceModule
// Note: BaseModule is declared as a dependency but not imported or used

public struct ModuleWithUnusedDep {
  private let interface = InterfaceModule()

  public init() {}

  public func moduleFunction() -> String {
    "Module with unused dep: \(interface.interfaceFunction())"
  }
}
