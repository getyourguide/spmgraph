public func == <Root, Value: Equatable>(
  lhs: KeyPath<Root, Value>,
  rhs: Value
) -> (Root) -> Bool {
  { $0[keyPath: lhs] == rhs }
}

public func != <Root, Value: Equatable>(
  lhs: KeyPath<Root, Value>,
  rhs: Value
) -> (Root) -> Bool {
  { $0[keyPath: lhs] != rhs }
}
