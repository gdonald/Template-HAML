
use Template::HAML::Node;
use Template::HAML::Tag;

unit module Template::HAML::TagTransformers;

my %handlers;
my @order;

sub register-tag-transformer(Str:D :$name!, :&handler!) is export {
  @order.push: $name unless %handlers{$name}:exists;
  %handlers{$name} = &handler;
}

sub clear-tag-transformers(--> Int) is export {
  my $n = @order.elems;
  %handlers = ();
  @order = ();
  $n;
}

sub clear-tag-transformer(Str:D $name --> Bool) is export {
  return False unless %handlers{$name}:exists;
  %handlers{$name}:delete;
  @order = @order.grep(* ne $name);
  True;
}

sub has-tag-transformer(Str:D $name --> Bool) is export {
  %handlers{$name}:exists;
}

sub tag-transformer-names() is export {
  @order.list;
}

sub tag-transformer-count(--> Int) is export {
  @order.elems;
}

sub lookup-tag-transformer(Str:D $name) is export {
  %handlers{$name}:exists ?? %handlers{$name} !! Nil;
}

sub apply-tag-transformers(Node:D $tree --> Node) is export {
  return $tree unless @order.elems;
  transform-children($tree);
  $tree;
}

sub transform-children(Node:D $node) {
  loop (my $i = 0; $i < $node.children.elems; $i++) {
    my $child = $node.children[$i];
    my $obj   = $child.object;
    if $obj.defined && $obj ~~ Tag && (%handlers{$obj.name}:exists) {
      my &h     = %handlers{$obj.name};
      my $r     = h($child);
      my $next  = ($r.defined && $r ~~ Node) ?? $r !! $child;
      if $next !=== $child {
        $next.parent = $node;
        $node.children[$i] = $next;
        $child = $next;
      }
    }
    transform-children($child);
  }
}
