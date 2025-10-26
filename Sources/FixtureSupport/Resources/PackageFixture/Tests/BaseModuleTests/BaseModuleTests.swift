import Testing
@testable import BaseModule

@Suite
struct BaseModuleTests {
  @Test
  func testBaseModule() {
    let base = BaseModule()
    #expect(base.baseFunction() == "Base Module")
  }
}
