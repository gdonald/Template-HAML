
use Template::HAML::Node;
use Template::HAML::Statement;
use Template::HAML::Tag;
use Template::HAML::X;

sub pos-to-line-col($/) {
  my $orig = $/.orig.Str;
  my $pos  = $/.from;
  my $before = $orig.substr(0, $pos);
  my $line   = 1 + $before.comb("\n").elems;
  my $last-nl = $before.rindex("\n");
  my $column = $last-nl.defined ?? $pos - $last-nl !! $pos + 1;
  ($line, $column);
}

class Actions is export {
  has Node $.tree;
  has Node $!current-node;

  has Str $!indent-leader;
  has Int $!indent-unit;

  has Int $.output-indent-width = 2;

  submethod BUILD(Node:D :$!tree) {
    $!current-node = $!tree.children.first;
  }

  method TOP($/) {}

  method tag($/) {
    my ($line, $column) = pos-to-line-col($/);
    my $indent  = self.compute-level($/<indent>);

    my $name = $/<explicit-tag-name>.defined
      ?? $/<explicit-tag-name><tag-name>.Str
      !! 'div';

    my @classes;
    my @ids;
    for ($/<shorthand> // ()).list -> $sh {
      if $sh<shorthand-class>.defined {
        @classes.push: $sh<shorthand-class><word>.Str;
      } elsif $sh<shorthand-id>.defined {
        @ids.push: $sh<shorthand-id><word>.Str;
      }
    }

    my $params  = $/<params-hash>.made || {};
    my $content = $/<to-eol>.defined ?? $/<to-eol>.Str.trim !! '';

    my $trim    = $/<trim-modifiers>.Str;
    my $trim-outer = $trim.contains('>');
    my $trim-inner = $trim.contains('<');
    my $self-close = $/<void-marker>.defined && $/<void-marker>.Str eq '/';

    my $object = Tag.new(
      :$indent, :$name, :$params, :$content,
      :@classes, :@ids,
      :$self-close, :$trim-outer, :$trim-inner,
      :$line, :$column,
      :output-indent-width($!output-indent-width),
    );
    self.add-node($object);
  }

  method statement($/) {
    my ($line, $column) = pos-to-line-col($/);
    my $indent = self.compute-level($/<indent>);
    my $op     = $/<op>.Str;
    my $expr   = $/<expr>.Str;

    my $object = Statement.new(:$indent, :$op, :$expr, :$line, :$column);
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

    while $offset > 0 {
      $parent .= parent;
      $offset -= 1;
    }

    $parent;
  }

  method compute-level($indent-match) {
    my $ws = $indent-match.Str;
    return 0 unless $ws.chars;

    my ($line, $column) = pos-to-line-col($indent-match);

    if $ws.contains("\t") && $ws.contains(' ') {
      indent-mixed(:$line, :$column);
    }

    my $leader = $ws.substr(0, 1);
    unless $!indent-leader.defined {
      $!indent-leader = $leader;
      $!indent-unit   = $ws.chars;
    }

    if $leader ne $!indent-leader {
      indent-mixed(:$line, :$column);
    }

    if $ws.chars % $!indent-unit != 0 {
      indent-inconsistent(:$line, :$column, :unit($!indent-unit), :got($ws.chars));
    }

    $ws.chars div $!indent-unit;
  }

  method indent($/) {
    make $/.Str.chars;
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
