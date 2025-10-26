//
//
//  Copyright (c) 2025 GetYourGuide GmbH
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//

import Basics
import Foundation
import PackageModel
import Testing

@testable import SPMGraphDescriptionInterface

@Suite
struct SPMGraphConfigTests {
  @Suite("liveModuleLiveDependency rule")
  struct LiveModuleLiveDependency {
    @Test("It has the correct properties")
    func testRuleProperties() {
      // GIVEN
      let rule = SPMGraphConfig.Lint.Rule.liveModuleLiveDependency()

      // THEN
      #expect(rule.id == "liveModuleLiveDependency")
      #expect(rule.name == "Live modules should not depend on other Live modules")
      #expect(
        rule.abstract
          == "To keep the dependency graph flat and avoid depending on implementations, a Live Module should never depend on another Live module"
      )
    }

    @Test("Validate detects Live module depending on another Live module")
    func testValidateDetectsViolation() async throws {
      // GIVEN
      let rule = SPMGraphConfig.Lint.Rule.liveModuleLiveDependency()

      // WHEN
      let package = try await loadFixturePackage()
      let errors = rule.validate(package, [])

      // THEN
      #expect(errors.count == 1, "StorageLive depends on NetworkingLive, which violates the rule")

      let error = try #require(errors.first as? SPMGraphConfig.Lint.Error)
      #expect(
        error == SPMGraphConfig.Lint.Error.liveModuleLiveDependency(
          moduleName: "StorageLive",
          liveDependencyName: "NetworkingLive"
        )
      )
    }

    @Test("Validate with excluded dependencies allows specific violations")
    func testValidateWithExcludedDependencies() async throws {
      // GIVEN
      let rule = SPMGraphConfig.Lint.Rule.liveModuleLiveDependency(
        excludedDependencies: ["NetworkingLive"]
      )

      // WHEN
      let package = try await loadFixturePackage()
      let errors = rule.validate(package, [])

      // THEN
      #expect(errors.isEmpty, "Should not report violations for excluded dependencies")
    }

    @Test("Validate with excluded suffixes ignores matching modules")
    func testValidateWithExcludedSuffixes() async throws {
      // GIVEN
      let rule = SPMGraphConfig.Lint.Rule.liveModuleLiveDependency()

      // WHEN - Exclude modules ending with "Live"
      let package = try await loadFixturePackage()
      let errors = rule.validate(package, ["Live"])

      // THEN
      #expect(errors.isEmpty, "Should not check excluded modules")
    }

    @Test("Validate with custom Live module definition")
    func testValidateWithCustomLiveModuleDefinition() async throws {
      // GIVEN - isLiveModule defines modules ending with "Interface"
      let rule = SPMGraphConfig.Lint.Rule.liveModuleLiveDependency(
        isLiveModule: { $0.name.hasSuffix("Interface") }
      )

      // WHEN
      let package = try await loadFixturePackage()
      let errors = rule.validate(package, [])

      // THEN
      #expect(errors.isEmpty, "Per custom definition, there are no interdependencies between live modules")
    }
  }

  @Suite("baseOrInterfaceModuleLiveDependency rule")
  struct BaseOrInterfaceModuleLiveDependency {
    @Test("It has the correct properties")
    func testRuleProperties() {
      // GIVEN
      let rule = SPMGraphConfig.Lint.Rule.baseOrInterfaceModuleLiveDependency()

      // THEN
      #expect(rule.id == "baseOrInterfaceModuleLiveDependency")
      #expect(rule.name == "Base or Interface modules should not depend on Live modules")
      #expect(
        rule.abstract
          == "To keep the dependency graph flat and avoid depending on higher level, a Base or Interface Module should never depend on upper Live Modules"
      )
    }

    @Test("Validate passes when Base modules do not depend on Live modules")
    func testValidateWithNoViolations() async throws {
      // GIVEN
      let rule = SPMGraphConfig.Lint.Rule.baseOrInterfaceModuleLiveDependency()

      // WHEN
      let package = try await loadFixturePackage()
      let errors = rule.validate(package, [])

      // THEN
      #expect(errors.isEmpty, "Should not detect violations when base modules don't depend on Live modules")
    }

    @Test("Validate fails when Base modules depend on Live modules")
    func testValidateWithViolations() async throws {
      // GIVEN
      let rule = SPMGraphConfig.Lint.Rule.baseOrInterfaceModuleLiveDependency(
        isLiveModule: { $0.name == "BaseModule" }
      )

      // WHEN
      let package = try await loadFixturePackage()
      let errors = rule.validate(package, [])

      // THEN
      #expect(errors.count == 3, "The module `BaseModule` is considered Base, which triggers errors")

      let mappedErrors = try #require(errors as? [SPMGraphConfig.Lint.Error])
      #expect(
        mappedErrors == [
          .baseOrInterfaceModuleLiveDependency(
            moduleName: "BaseModuleTests",
            liveDependencyName: "BaseModule"
          ),
          .baseOrInterfaceModuleLiveDependency(
            moduleName: "InterfaceModule",
            liveDependencyName: "BaseModule"
          ),
          .baseOrInterfaceModuleLiveDependency(
            moduleName: "ModuleWithUnusedDep",
            liveDependencyName: "BaseModule"
          )
        ]
      )
    }

    @Test("Validate with excluded suffixes ignores matching modules")
    func testValidateWithExcludedSuffixes() async throws {
      // GIVEN
      let rule = SPMGraphConfig.Lint.Rule.baseOrInterfaceModuleLiveDependency()

      // WHEN - Exclude base modules
      let package = try await loadFixturePackage()
      let errors = rule.validate(package, ["Module"])

      // THEN
      #expect(errors.isEmpty, "Should not check excluded modules")
    }
  }

  @Suite("unusedDependencies rule")
  struct UnusedDependenciesTests {
    @Test("It has the correct properties")
    func testRuleProperties() {
      // GIVEN
      let rule = SPMGraphConfig.Lint.Rule.unusedDependencies

      // THEN
      #expect(rule.id == "unusedDependencies")
      #expect(rule.name == "Unused linked dependencies")
      #expect(
        rule.abstract == """
        To keep the project clean and avoid long compile times, a Module should not have any unused dependencies.
        
        - Note: It does blindly expects the target to match the product name, and doesn't yet consider
        the multiple targets that compose a product (open improvement). 
        
        - Note: For `@_exported` usages, there will be an error in case only the exported module is used.
        For example, module Networking exports module NetworkingHelpers, if only NetworkingHelpers is used by a target
        there will be a lint error, while if both Networking and NetworkingHelpers are used there will be no error.
        """
      )
    }

    @Test("Validate detects unused dependencies")
    func testValidateDetectsUnusedDependencies() async throws {
      // GIVEN
      let rule = SPMGraphConfig.Lint.Rule.unusedDependencies

      // WHEN
      let package = try await loadFixturePackage()
      let errors = rule.validate(package, [])

      // THEN
      #expect(errors.count == 1, "Should detect unused dependencies")

      let mappedErrors = try #require(errors as? [SPMGraphConfig.Lint.Error])
      #expect(
        mappedErrors == [
          .unusedDependencies(
            moduleName: "ModuleWithUnusedDep",
            dependencyName: "BaseModule"
          ),
        ]
      )
    }

    @Test("Validate with excluded suffixes ignores matching modules")
    func testValidateWithExcludedSuffixes() async throws {
      // GIVEN
      let rule = SPMGraphConfig.Lint.Rule.unusedDependencies

      // WHEN - Exclude modules with "WithUnusedDep" suffix
      let package = try await loadFixturePackage()
      let errors = rule.validate(package, ["BaseModule"])

      // THEN
      #expect(errors.isEmpty, "BaseModule should be ignored")
    }
  }

  @Suite("Default rules configuration")
  struct DefaultRules {
    @Test("Contains the expected rules")
    func testDefaultRulesArePresent() {
      // GIVEN
      let defaultRules = [SPMGraphConfig.Lint.Rule].default

      // THEN
      #expect(defaultRules.count == 3, "Should have 3 default rules")
      #expect(defaultRules.contains { $0.id == "unusedDependencies" })
      #expect(defaultRules.contains { $0.id == "liveModuleLiveDependency" })
      #expect(defaultRules.contains { $0.id == "baseOrInterfaceModuleLiveDependency" })
    }

    @Test("Default rules have unique IDs")
    func testDefaultRulesHaveUniqueIDs() {
      // GIVEN
      let defaultRules = [SPMGraphConfig.Lint.Rule].default

      // WHEN
      let uniqueIDs = Set(defaultRules.map(\.id))

      // THEN
      #expect(uniqueIDs.count == defaultRules.count, "All rule IDs should be unique")
    }
  }

  @Suite("SPMGraphConfig")
  struct Config {
    @Test("Default config has expected properties")
    func testDefaultConfig() {
      // GIVEN
      let config = SPMGraphConfig.default

      // THEN
      #expect(config.lint.isStrict == false)
      #expect(config.lint.expectedWarningsCount == 0)
      #expect(config.excludedSuffixes.isEmpty)
      #expect(config.lint.rules.count == 3)
    }

    @Test("Can create custom config with strict mode")
    func testCustomStrictConfig() {
      // GIVEN
      let config = SPMGraphConfig(
        lint: .init(isStrict: true, expectedWarningsCount: 5),
        excludedSuffixes: ["Tests", "Mock"]
      )

      // THEN
      #expect(config.lint.isStrict == true)
      #expect(config.lint.expectedWarningsCount == 5)
      #expect(config.excludedSuffixes == ["Tests", "Mock"])
    }

    @Test("Can create config with custom rules")
    func testCustomRulesConfig() {
      // GIVEN
      let customRule = SPMGraphConfig.Lint.Rule(
        id: "customRule",
        name: "Custom Rule",
        abstract: "A custom lint rule",
        validate: { _, _ in [] }
      )

      let config = SPMGraphConfig(
        lint: .init(rules: [customRule], isStrict: false)
      )

      // THEN
      #expect(config.lint.rules.count == 1)
      #expect(config.lint.rules.first?.id == "customRule")
    }
  }
}
