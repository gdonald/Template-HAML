
use Template::HAML::Comment;
use Template::HAML::Doctype;
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

    if $obj ~~ Doctype {
      return $obj.render ~ "\n";
    }

    if $obj ~~ Comment {
      return self.render-comment($node);
    }

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

  method render-comment(Node:D $node) {
    my $obj = $node.object;
    return '' if $obj.silent;

    my $indent = $obj.get-indent;
    if $node.children.elems {
      my $out = $indent ~ $obj.open-tag ~ "\n";
      $out ~= self.render-children($node);
      $out ~= $indent ~ $obj.close-tag ~ "\n";
      return $out;
    }

    my $text = $obj.text;
    my $body = '';
    if $text {
      $body = $obj.condition ?? $text !! " $text ";
    }
    $indent ~ $obj.open-tag ~ $body ~ $obj.close-tag ~ "\n";
  }
}
