
use Template::HAML::Node;

class Renderer is export {
  method render(Node:D $tree) {
    self.render-node($tree);
  }

  method render-node(Node:D $node) {
    $node.object ?? self.render-object($node) !! self.render-children($node);
  }

  method render-object(Node:D $node) {
    my $out = $node.object.open;
    $out ~= "\n" if $node.children;
    $out ~= self.render-children($node);
    $out ~= $node.object.content;
    $out ~= $node.object.get-indent if $node.children;
    $out ~= $node.object.close;
  }

  method render-children(Node:D $node) {
    $node.children.map({ self.render-node($_) }).join;
  }
}
