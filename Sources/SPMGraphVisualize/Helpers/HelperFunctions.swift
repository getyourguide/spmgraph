func containsExcludedSuffix(moduleName: String, excludedSuffixes: [String]) -> Bool {
  excludedSuffixes.contains(where: moduleName.hasSuffix)
}
