import Foundation
import PackageModel

extension Package {
  func externalDependencies(
    forModuleNames moduleNames: [String]
  ) -> [Module.ProductReference] {
    modules
      .filter { moduleNames.contains($0.name) }
      .map(\.dependencies)
      .reduce(
        [],
        +
      )
      .compactMap(\.product)
      .sorted(by: { $0.name < $1.name })
  }

  func externalDependencies(
    forModuleName moduleName: String
  ) -> [Module.ProductReference] {
    externalDependencies(forModuleNames: [moduleName])
  }
}
