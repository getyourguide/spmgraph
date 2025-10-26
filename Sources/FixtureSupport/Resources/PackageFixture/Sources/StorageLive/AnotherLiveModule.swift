import NetworkingLive

public struct AnotherLiveModule {
  private let live = LiveModule()

  public init() {}

  public func anotherLiveFunction() -> String {
    "Another Live: \(live.liveFunction())"
  }
}
