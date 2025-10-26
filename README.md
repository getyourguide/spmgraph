# `spmgraph`: SwiftPM dependency graphs supercharged ⚡

[![CI status](https://github.com/getyourguide/spmgraph/actions/workflows/main.yml/badge.svg)](https://github.com/getyourguide/spmgraph/actions/workflows/main.yml)
![Toolchain](https://img.shields.io/badge/Swift-6.1+%20%7C%20Xcode%2016%3B-orange?logo=swift&logoColor=white)
[![Mint](https://img.shields.io/badge/Mint-getyourguide%2Fspmgraph-40c8a7?logo=leaf&logoColor=white)](https://github.com/getyourguide/spmgraph#installation)
[![Swift Package Manager](https://rawgit.com/jlyonsmith/artwork/master/SwiftPackageManager/swiftpackagemanager-compatible.svg)](https://swift.org/package-manager/)

A CLI tool that **unlocks Swift dependency graphs**, giving you extra information and capabilities.
<br>
With it, you can **visualize your dependency graph**, run **selective tests**, and **enforce architectural rules** for an optimal modular setup.
<br>
_spmgraph_ can be run for any local `Package.swift`.

## Visualize
Generate an image that visually represents your dependency graph. **Open the map!**

```bash
spmgraph visualize <package-path> --help
```

## Tests
**Selective testing** based on git changes or a given list of changed files.
<br>
The output is a comma-separated list of test targets that can be fed into `xcodebuild`'s `-only-testing:TEST-IDENTIFIER` or [fastlane scan](https://docs.fastlane.tools/actions/scan/#scan)'s `only_testing`

```bash
spmgraph tests <package-path> --help
```

## Lint

Verifies whether the dependency graph follows the team-defined best practices.

It's built on top of a user-defined `SPMGraphConfig.swift`, which allows teams to configure their own dependency graph rules leveraging Swift and the [SwiftPM library](https://github.com/swiftlang/swift-package-manager/blob/a33af66bf40ea96ba54f1abd5a5c5440f2a7e323/Package.swift#L56).
<br>

`SPMGraphConfig.default` provides the standard definition with built-in rules and extensible rules that can also be used on custom configurations.

**For that, the steps are:**

### Config & Load

#### 1. Config
Init or edit your spmgraph config

```bash
spmgraph config <package-path> --help
```

- if none, it creates an initial `SPMGraphConfig.swift` on the same path as your `Package.swift`
- spmgraph opens up a temporary Swift Package where you configure spmgraph in Swift and build to check that everything is correct

#### Examples
For example, enforce that
- Feature modules don't depend on each other
- Linked dependencies are imported (used) at least once
- Base modules don't depend on feature modules
- The dependency graph isn't too deep

All possible using Swift. Below is an example of creating your own lint rule by traversing the dependency graph:
```swift
extension SPMGraphConfig.Lint.Rule {
  static let unregisteredLiveModules = Self(
    id: "unregisteredLiveModules",
    name: "Unregistered Live modules",
    abstract: "Live modules need to be added to the app target/feature module as dependencies.",
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

#### 2. Load
Load the latest `SPMGraphConfig.swift` into `spmgraph`

```bash
spmgraph load <package-path> --help
```

### Run the linter

```bash
spmgraph lint <package-path> --help
```

#### Fail on warnings

```bash
spmgraph lint <package-path> --strict <other-options>
```

#### Allowed warnings count
Bypass the strict mode on a given number of allowed warnings

```bash
spmgraph lint <package-path> --strict --warningsCount 3 <other-options>
```

## CI

Custom GitHub actions are [available](./github/actions) for running the different spmgraph commands in CI environments.

**When using multiple runners AND to speed up builds**:
- Pass a custom config build directory via the `--config-build-directory` option
- It allows caching and pre-warming the config package
- It will make loading the config into spmgraph much faster

## Requirements
- [graphviz](https://github.com/graphp/graphviz) (available via `brew install graphviz`)
- Xcode 16+ and the Swift 6.0+ toolchain

## Installation

### [Mint](https://github.com/yonaskolb/mint)

```
mint install getyourguide/spmgraph
```
* For optimal build times, make sure `~/.mint/bin/spmgraph` is cached on your CI runner.

## Acknowledgments
- Inspired by the work that the [Tuist](https://tuist.dev/) team does for the Apple developers community and their focus on leveraging the dependency graph to provide amazing features for engineers. Also, a source of inspiration for our shell abstraction layer.

## Contributing
Check the [CONTRIBUTING.md](./CONTRIBUTING.md) file.
