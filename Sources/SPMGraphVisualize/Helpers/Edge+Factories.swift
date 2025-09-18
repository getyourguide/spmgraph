import GraphViz

extension Edge {
  static func make(
    from: Node,
    to: Node,
    direction: Direction? = nil,
    strokeColor: Color? = .named(.gray1)
  ) -> Self {
    var edge = Edge(from: from, to: to)
    edge.strokeColor = strokeColor
    return edge
  }
}
