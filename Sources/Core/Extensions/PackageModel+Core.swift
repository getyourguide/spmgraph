import PackageModel

public extension Module {
  var isLiveModule: Bool {
    name.hasSuffix("Live")
  }
}
