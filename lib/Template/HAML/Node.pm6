
class Node is export {
  has Node $.parent is rw;
  has @.children of Node;
  has $.object;

  submethod BUILD(:$!parent = Nil, :$!object = Nil) {}

  method add-child(Node $node) {
    $node.parent = self;
    @!children.push: $node;
  }

  method add-sibling(Node $node) {
    self.parent.add-child($node) if self.parent;
  }
}
