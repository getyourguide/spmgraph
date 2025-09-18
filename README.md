# spmgraph - SwiftPM dependency graph management

A CLI tool that **unlocks Swift dependency graphs**, giving you extra information and capabilities. 
With it you can visualize your dependency graph, run selective testing, and enforce architectural rules for optimal modular setups.

## How to use

`spmgraph` is run for a local `Package.swift` and takes the user configuration from a `SPMGraphConfig.swift` file.

### Edit
Create and edit your spmgraph config

- run `spmgraph edit <'Package.swift' path> <options>`
- it creates an initial `SPMGraphConfig.swift` on the same path as your `Package.swift`
- spmgraph opens up a temporary Swift Package where you configure spmgraph in Swift and build to check that everything is correct

### Visualize
Generate an image with a visual representation of your dependency. **Open the map!**

run `spmgraph visualize <'Package.swift' path> help` for more

### Tests
**Selective testing** based on git changes or a given list of changed files.
The output is a comma separate list of test targets that can be fed into `xcodebuild`'s `-only-testing:TEST-IDENTIFIER` or [fastlane scan](https://docs.fastlane.tools/actions/scan/#scan)'s `only_testing`

run `spmgraph tests <'Package.swift' path> help` for more

### Lint
Verify if the dependency graph follow the defined team and industry best practices.

For example, enforce that
- feature modules don't depend on each other
- Linked dependencies are imported (used) at least once
- Base modules don't depend on feature modules
- the dependency graph isn't too deep

All possible using Swift. Below an example of creating your own lint rule by traversing the dependency graph:
```swift
extension SPMGraphConfig.Lint.Rule {
  static let unregisteredLiveModules = Self(
    id: "unregisteredLiveModules",
    name: "Unregistered Live modules",
    abstract: "Live modules need to be added to the app target / feature module as dependencies.",
    validate: { package, excludedSuffixes in
      let liveModules = package
        .modules
        .compactMap { module -> Module? in
          guard !module.containsOneOf(suffixes: excludedSuffixes), module.isLiveModule else {
            return nil
          }
          return module
        }

      guard
        let featureModule = package
          .modules
          .first(where: { $0.name == "GetYourGuideFeature" }),
        case let featureModuleDependencies = featureModule
          .dependencies
          .compactMap(\.module)
      else {
        return [LintError.missingFeatureModule]
      }

      return liveModules.compactMap { liveModule in
        if !featureModuleDependencies.contains(liveModule) {
          return LintError.unregisteredLiveModules(
            moduleName: liveModule.name,
            appModule: featureModule.name
          )
        }

        return nil
      }
    }
  )
}
``` 

run `spmgraph lint <'Package.swift' path> help` for more

## Requirements
- [graphviz](https://github.com/graphp/graphviz) (available via `brew install graphviz`)
- Xcode 16+ and the Swift 6.0+ toolchain

## Installation

### [Mint](https://github.com/yonaskolb/mint)

```
mint install getyourguide/spmgraph
```
* For optimal build times make sure `~/.mint/bin/spmgraph` is cached on your CI runner.

## Acknowledgments
- Inspired by the work that the [Tuist](https://tuist.dev/) team does for the Apple developers community and their focus on leveraging the dependency graph to provide amazing features for engineers. Also, source of inspiration for our shell abstraction layer. 

## Open roadmap 
- [ ] Cover the core logic of Lint, Map and Visualize libs with tests
- [ ] Support macros (to become a GitHub issue)    

Ideas
- [ ] Lint - see if it can be improved to cover auto-exported dependencies. For example usages of `import Dependencies` justify linking `DependenciesExtras` as a dependency.
- [ ] Add fix it suggestion to lint errors
