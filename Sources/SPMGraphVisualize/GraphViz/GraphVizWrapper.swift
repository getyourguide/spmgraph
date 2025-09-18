import Core

enum GraphVizWrapper {
  static func installGraphVizIfNeeded() throws {
    if try !isGraphVizInstalled() {
      try installGraphViz()
    }
  }
}

private extension GraphVizWrapper {
  static func isGraphVizInstalled() throws -> Bool {
    try System.shared.runAndCapture("brew", "list", "--formula").contains("graphviz")
  }

  static func installGraphViz() throws {
    print("Installing GraphViz...")
    var env = System.env
    env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
    try System.shared.run(
      "brew",
      "install",
      "graphviz"
    )
  }
}
