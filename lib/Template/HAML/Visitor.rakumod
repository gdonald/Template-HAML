
use Template::HAML::Node;

unit module Template::HAML::Visitor;

my @visitors;

sub register-visitor(:&handler!, Str :$name) is export {
  if $name.defined {
    my $idx = @visitors.first({ .key.defined && .key eq $name }, :k);
    if $idx.defined {
      @visitors[$idx] = $name => &handler;
      return;
    }
    @visitors.push: Pair.new($name, &handler);
  } else {
    @visitors.push: Pair.new(Nil, &handler);
  }
}

sub clear-visitors(--> Int) is export {
  my $n = @visitors.elems;
  @visitors = ();
  $n;
}

sub clear-visitor(Str:D $name --> Bool) is export {
  my $idx = @visitors.first({ .key.defined && .key eq $name }, :k);
  return False unless $idx.defined;
  @visitors.splice($idx, 1);
  True;
}

sub has-visitor(Str:D $name --> Bool) is export {
  so @visitors.first({ .key.defined && .key eq $name });
}

sub visitor-names() is export {
  @visitors.grep({ .key.defined }).map(*.key).list;
}

sub visitor-count(--> Int) is export {
  @visitors.elems;
}

sub apply-visitors(Node:D $tree --> Node) is export {
  my Node $cur = $tree;
  for @visitors -> $v {
    my $result = $v.value.($cur);
    $cur = $result if $result.defined && $result ~~ Node;
  }
  $cur;
}

sub walk-tree(Node:D $tree, &cb) is export {
  &cb($tree);
  walk-tree($_, &cb) for $tree.children;
}
