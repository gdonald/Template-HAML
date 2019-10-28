
use Data::Dump::Tree;

use Template::HAML::Node;
use Template::HAML::Tag;
use Template::HAML::X;

class Actions is export {
  has Node $.tree;
  has Node $!root;
  has Node $!current;

  submethod BUILD {
    $!tree = Node.new;
    $!root = Node.new;
    $!tree.add-child($!root);
    $!current = $!root;
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

  method add-node($object) {
    my Node $new = Node.new(:$object);
    my $current-indent = $!current.object ?? $!current.object.indent !! 0;

    if $object.indent == $current-indent {
      $!current.add-sibling: $new;
    } elsif $object.indent > $current-indent {
      $!current.add-child: $new;
    } elsif $object.indent < $current-indent {
      my $offset = $current-indent - $object.indent;
      my $parent = $!current.parent;

      while $offset >= $object.indent {
        $parent = $parent.parent;
        $offset -= 2;
      }
      $parent.add-child($new);
    }

    $!current = $new;
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
