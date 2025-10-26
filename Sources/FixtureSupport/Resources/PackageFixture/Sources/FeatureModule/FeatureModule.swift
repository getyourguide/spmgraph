import InterfaceModule
import LiveModule

public struct FeatureModule {
  private let interface = InterfaceModule()
  private let live = LiveModule()

  public init() {}

  public func featureFunction() -> String {
    "Feature: \(interface.interfaceFunction()) + \(live.liveFunction())"
  }
}
