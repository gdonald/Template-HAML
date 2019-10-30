
use Template::HAML::Node;
use Template::HAML::Statement;
use Template::HAML::Tag;
use Template::HAML::X;

use Data::Dump::Tree;

class Actions is export {
  has Node $.tree;
  has Node $!current-node;

  submethod BUILD(Node:D :$!tree) {
    $!current-node = $!tree.children.first;
  }

  method TOP($/) {}

  method tag($/) {
    my $indent = $/<indent>.made;
    my $name = $/<tag-type><word>.Str;
    my $params = $/<params-hash>.made || {};
    my $content = $/<phrase>.Str.trim || '';
    my $sigil = $/<tag-type><sigil>.Str;
    my $classes = $/<css-classes>.made || [];

    my $object = Tag.new(:$indent, :$sigil, :$name, :$params, :$content, :$classes);
    self.add-node($object);
  }

  method statement($/) {
    my $indent = $/<indent>.made;
    my $op = $/<op>.Str;
    my $cond = $/<cond>.Str;

    my $object = Statement.new(:$indent, :$op, :$cond);
    self.add-node($object);
  }

  method add-node($object) {
    my Node $new = Node.new(:$object);
    my $current-indent = $!current-node.object ?? $!current-node.object.indent !! 0;

    if $object.indent > $current-indent {
      $!current-node.add-child: $new;
    } elsif $object.indent < $current-indent {
      self.get-parent($current-indent, $object.indent).add-child($new);
    } else {
      $!current-node.add-sibling: $new;
    }

    $!current-node = $new;
  }

  method get-parent($current-indent, $object-indent) {
    my $offset = $current-indent - $object-indent;
    my $parent = $!current-node.parent;

    while $offset >= $object-indent {
      $parent .= parent;
      $offset -= 2;
    }

    $parent;
  }

  method indent($/) {
    my $length = $/.Str.chars;
    illegal-indent if $length mod 2;
    make $length;
  }

  method quoted-string($/) {
    if $/<double-quoted-string> {
      make $/<double-quoted-string>.Str.subst(:global, /\"/, '');
    } elsif $/<single-quoted-string> {
      make $/<single-quoted-string>.Str.subst(:global, /\'/, '');
    }
  }

  method param-value($/) {
    if $/<quoted-string> {
      make $/<quoted-string>.made.trim;
    } elsif $/<symbol> {
      make $/<symbol>.Str.subst(:global, /\:/, '').trim;
    }
  }

  method param-key($/) {
    make $/<word>.Str;
  }

  method param($/) {
    make Pair.new: $/<param-key>.made, $/<param-value>.made;
  }

  method params($/) {
    make Hash.new: $/<param>.map({ .made });
  }

  method params-hash($/) {
    make $/<params>.made;
  }

  method css-class($/) {
    make $/.Str.subst(/\./, '').trim;
  }

  method css-classes($/) {
    make $/<css-class>.map({ .made });
  }
}
