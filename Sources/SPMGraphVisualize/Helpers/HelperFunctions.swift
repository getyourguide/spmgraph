func containsExcludedSuffix(moduleName: String, excludedSuffixes: [String]) -> Bool {
  var containsExcludedSuffix = false
  excludedSuffixes.forEach { suffix in
    if moduleName.hasSuffix(suffix) {
      containsExcludedSuffix = true
    }
  }
  return containsExcludedSuffix
}
