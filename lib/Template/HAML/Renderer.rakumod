
use Template::HAML::Node;
use Template::HAML::Tag;
use Template::HAML::X;

class Renderer is export {
  method render(Node:D $tree) {
    self.render-node($tree);
  }

  method render-node(Node:D $node) {
    $node.object ?? self.render-object($node) !! self.render-children($node);
  }

  method render-object(Node:D $node) {
    my $obj = $node.object;

    if $obj ~~ Tag && $obj.is-void && $node.children.elems {
      X::HAML::VoidWithChildren.new(
        :line($obj.line), :column($obj.column), :name($obj.name),
      ).throw;
    }

    if $obj ~~ Tag && $obj.self-close {
      return $obj.open ~ $obj.close;
    }

    my $out = $obj.open;
    if $node.children.elems {
      $out ~= $obj.content if $obj.content;
      $out ~= "\n";
      $out ~= self.render-children($node);
      $out ~= $obj.get-indent;
    } else {
      $out ~= $obj.content;
    }
    $out ~= $obj.close;
    $out;
  }

  method render-children(Node:D $node) {
    $node.children.map({ self.render-node($_) }).join;
  }
}
