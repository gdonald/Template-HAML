
use Template::HAML::Comment;
use Template::HAML::Config;
use Template::HAML::Doctype;
use Template::HAML::Eval;
use Template::HAML::Filter;
use Template::HAML::Filters;
use Template::HAML::Helpers;
use Template::HAML::Interpolation;
use Template::HAML::Node;
use Template::HAML::Plain;
use Template::HAML::Statement;
use Template::HAML::Tag;
use Template::HAML::X;

sub html-escape(Str $s --> Str) {
  $s.subst('&', '&amp;', :g)
    .subst('<', '&lt;',  :g)
    .subst('>', '&gt;',  :g)
    .subst('"', '&quot;', :g)
    .subst("'", '&#39;', :g);
}

sub resolve-attrs(@attrs, %locals) {
  @attrs.map(-> $p {
    my $v = $p.value;
    if $v ~~ Template::HAML::Interpolation::InterpString {
      $p.key => $v.resolve(%locals, :escape(False));
    } elsif $v ~~ Positional && $v !~~ Pair {
      my @resolved = $v.list.map(-> $item {
        $item ~~ Template::HAML::Interpolation::InterpString
          ?? $item.resolve(%locals, :escape(False))
          !! $item;
      });
      $p.key => @resolved.List;
    } else {
      $p;
    }
  }).list;
}

sub normalize-splat-value($v) {
  return $v unless $v.defined;
  if $v ~~ Pair {
    return Pair.new($v.key, normalize-splat-value($v.value));
  }
  if $v ~~ Associative {
    return $v.keys.sort.map({ Pair.new($_, normalize-splat-value($v{$_})) }).list;
  }
  if $v ~~ Positional {
    return $v.list.map({ normalize-splat-value($_) }).list;
  }
  $v;
}

sub splat-to-pairs($v) {
  return () unless $v.defined;
  return ($v,)                                                if $v ~~ Pair;
  return $v.keys.sort.map({ Pair.new($_, $v{$_}) }).list      if $v ~~ Associative;
  return $v.list.grep(* ~~ Pair)                              if $v ~~ Positional;
  ();
}

sub expand-splats(@attrs, %locals) {
  my @out;
  for @attrs -> $a {
    if $a ~~ AttrSplat {
      my $val = eval-haml(
        $a.expr, %locals,
        :line($a.line), :column($a.column),
      );
      for splat-to-pairs($val) -> $p {
        @out.push: Pair.new($p.key, normalize-splat-value($p.value));
      }
    } else {
      @out.push: $a;
    }
  }
  @out;
}

sub flatten-class-vals($v) {
  return () unless $v.defined;
  if $v ~~ Positional && $v !~~ Pair {
    return $v.list.flatmap({ flatten-class-vals($_) });
  }
  return () if $v === False;
  return ($v.Str,) if $v === True;
  $v.Str.split(/\s+/).grep(*.chars).list;
}

sub flatten-id-vals($v) {
  return () unless $v.defined;
  if $v ~~ Positional && $v !~~ Pair {
    return $v.list.flatmap({ flatten-id-vals($_) });
  }
  my $s = $v.Str;
  $s.chars ?? ($s,) !! ();
}

sub merge-attr-pairs(@pairs, :@shorthand-classes = (), :@shorthand-ids = ()) {
  my @order;
  my %slot;
  my @class-vals;
  my @id-vals;
  my $has-class = False;
  my $has-id    = False;

  for @pairs -> $p {
    if $p.key eq 'class' {
      @class-vals.append: flatten-class-vals($p.value);
      unless $has-class { @order.push: 'class'; $has-class = True }
    } elsif $p.key eq 'id' {
      @id-vals.append: flatten-id-vals($p.value);
      unless $has-id { @order.push: 'id'; $has-id = True }
    } else {
      @order.push: $p.key unless %slot{$p.key}:exists;
      %slot{$p.key} = $p.value;
    }
  }

  if @shorthand-classes.elems {
    @class-vals.append: @shorthand-classes;
    unless $has-class { @order.push: 'class'; $has-class = True }
  }
  if @shorthand-ids.elems {
    @id-vals.prepend: @shorthand-ids;
    unless $has-id { @order.push: 'id'; $has-id = True }
  }

  my @out;
  for @order -> $k {
    if $k eq 'class' {
      @out.push: 'class' => @class-vals.unique.join(' ');
    } elsif $k eq 'id' {
      @out.push: 'id' => @id-vals.join('_');
    } else {
      @out.push: $k => %slot{$k};
    }
  }
  @out;
}

sub camel-to-snake(Str $s --> Str) {
  $s.subst(/ (<[a..z 0..9]>) (<[A..Z]>) /, -> $/ { $0 ~ '_' ~ $1.Str.lc }, :g).lc;
}

sub prefix-str($p) {
  return Nil unless $p.defined;
  return $p.key.Str if $p ~~ Pair;
  $p.Str;
}

sub compute-obj-ref($obj, %locals) {
  my @args = $obj.obj-ref-args.list;
  return (Nil, Nil) unless @args.elems;

  my $val = eval-haml(
    @args[0], %locals,
    :line($obj.line), :column($obj.column),
  );
  return (Nil, Nil) unless $val.defined;

  my $prefix;
  if @args.elems >= 2 {
    my $p = eval-haml(
      @args[1], %locals,
      :line($obj.line), :column($obj.column),
    );
    $prefix = prefix-str($p);
  }

  my $type-name;
  if $val.^can('haml-object-ref') {
    my $r = $val.haml-object-ref;
    $type-name = $r.defined ?? $r.Str !! camel-to-snake($val.WHAT.^shortname);
  } else {
    $type-name = camel-to-snake($val.WHAT.^shortname);
  }

  my $cls = ($prefix.defined && $prefix.chars)
    ?? $prefix ~ '_' ~ $type-name
    !! $type-name;

  my $id-val = $val.^can('id') ?? $val.id !! Nil;
  my $id-str = $id-val.defined ?? $cls ~ '_' ~ $id-val.Str !! Nil;

  ($cls, $id-str);
}

sub existing-class-str($v --> Str) {
  if $v ~~ Positional && $v !~~ Pair {
    return $v.list.grep({ .defined && .so }).join(' ');
  }
  $v.defined ?? $v.Str !! '';
}

sub existing-id-str($v --> Str) {
  if $v ~~ Positional && $v !~~ Pair {
    return $v.list.grep({ .defined && .so }).join('_');
  }
  $v.defined ?? $v.Str !! '';
}

sub inject-obj-ref-attrs(@attrs, $cls, $id) {
  my @out = @attrs;

  if $cls.defined && $cls.chars {
    my $idx = @out.first({ .key eq 'class' }, :k);
    if $idx.defined {
      my $existing = existing-class-str(@out[$idx].value);
      my $merged   = $existing.chars ?? "$cls $existing" !! $cls;
      @out[$idx] = 'class' => $merged;
    } else {
      @out.push: 'class' => $cls;
    }
  }

  if $id.defined && $id.chars {
    my $idx = @out.first({ .key eq 'id' }, :k);
    if $idx.defined {
      my $existing = existing-id-str(@out[$idx].value);
      my $merged   = $existing.chars ?? $id ~ '_' ~ $existing !! $id;
      @out[$idx] = 'id' => $merged;
    } else {
      @out.push: 'id' => $id;
    }
  }

  @out;
}

constant TRIM-BEFORE = "\x[E000]";
constant TRIM-AFTER  = "\x[E001]";

class Renderer is export {
  has %.locals;
  has Int $.max-while-iters = 10000;
  has Template::HAML::Config $.config;

  submethod BUILD(
    :%!locals,
    Int :$!max-while-iters = 10000,
    Template::HAML::Config :$config,
  ) {
    $!config = $config // Template::HAML::Config.new;
  }

  method render(Node:D $tree) {
    my Int $*HAML-TAB-OFFSET = 0;
    my $out = self.render-node($tree, %!locals, 0);
    $out = self.apply-trim-markers($out);
    $out = self.compress($out) if $!config.is-ugly;
    $out;
  }

  method apply-trim-markers(Str $html --> Str) {
    my $tb = TRIM-BEFORE;
    my $ta = TRIM-AFTER;
    $html.subst(/\s* $tb \s*/, '', :g)
         .subst(/\s* $ta \s*/, '', :g);
  }

  method compress(Str $html --> Str) {
    $html.lines.map(*.trim).grep(*.chars).join('');
  }

  method should-escape(Statement:D $obj --> Bool) {
    return True  if $obj.op eq '&=';
    return False if $obj.op eq '!=';
    $!config.escape-html;
  }

  method render-node(Node:D $node, %locals, Int $offset) {
    $node.object
      ?? self.render-object($node, %locals, $offset)
      !! self.render-children($node, %locals, $offset);
  }

  method render-object(Node:D $node, %locals, Int $offset) {
    my $obj = $node.object;

    if $obj ~~ Doctype {
      return $obj.render ~ "\n";
    }

    if $obj ~~ Comment {
      return self.render-comment($node, %locals, $offset);
    }

    if $obj ~~ Statement {
      return self.render-statement($node, %locals, $offset);
    }

    if $obj ~~ Plain {
      return self.render-plain($node, %locals, $offset);
    }

    if $obj ~~ Filter {
      return self.render-filter($node, %locals, $offset);
    }

    if $obj ~~ Tag && $obj.is-void && $node.children.elems {
      X::HAML::VoidWithChildren.new(
        :line($obj.line), :column($obj.column), :name($obj.name),
      ).throw;
    }

    my $has-splat = $obj.attrs.grep({ $_ ~~ AttrSplat }).elems > 0;
    my @expanded  = $has-splat ?? expand-splats($obj.attrs, %locals) !! $obj.attrs.list;
    my @resolved  = resolve-attrs(@expanded, %locals);
    if $has-splat {
      my @sh-classes = $obj ~~ Tag ?? $obj.classes.list !! ();
      my @sh-ids     = $obj ~~ Tag ?? $obj.ids.list     !! ();
      @resolved = merge-attr-pairs(
        @resolved,
        :shorthand-classes(@sh-classes),
        :shorthand-ids(@sh-ids),
      );
    }
    if $obj ~~ Tag && $obj.obj-ref-args.elems {
      my ($cls, $id) = compute-obj-ref($obj, %locals);
      @resolved = inject-obj-ref-attrs(@resolved, $cls, $id);
    }
    my $content  = self.interpolate-content($obj, %locals);

    my $open  = $obj.open(:$offset, :attrs(@resolved));
    my $close = $obj.close;

    if $obj.trim-outer {
      $open  = TRIM-BEFORE ~ $open;
      $close = $close ~ TRIM-AFTER;
    }

    if $obj.self-close {
      return $open ~ $close;
    }

    my $is-preserved = $!config.is-preserved($obj.name);

    my $out = $open;
    if $node.children.elems {
      $out ~= $content if $content;
      if $obj.trim-inner {
        my $kids = self.render-children($node, %locals, $offset + 1);
        $out ~= $kids.subst(/^ \s+/, '').subst(/\s+ $/, '');
      } elsif $is-preserved {
        my $kids = self.render-children($node, %locals, $offset);
        my $inner = "\n" ~ $kids ~ $obj.get-indent(:$offset);
        $out ~= $inner.subst("\n", '&#x000A;', :g);
      } else {
        $out ~= "\n";
        $out ~= self.render-children($node, %locals, $offset);
        $out ~= $obj.get-indent(:$offset);
      }
    } else {
      $out ~= $content;
    }
    $out ~= $close;
    $out;
  }

  method interpolate-content(Tag:D $obj, %locals --> Str) {
    return '' unless $obj.content.defined && $obj.content.chars;
    interpolate(
      $obj.content, %locals,
      :line($obj.line), :column($obj.column),
    );
  }

  method render-filter(Node:D $node, %locals, Int $offset) {
    my $obj = $node.object;
    unless has-filter($obj.name) {
      X::HAML::UnknownFilter.new(
        :line($obj.line), :column($obj.column), :name($obj.name),
      ).throw;
    }
    my &handler = lookup-filter($obj.name);
    my $rendered = do {
      my $*HAML-CFG = $!config;
      handler($obj.body, %locals);
    };
    return '' unless $rendered.defined && $rendered.chars;

    my $indent = $obj.get-indent(:$offset);
    $rendered.lines.map({ $indent ~ $_ ~ "\n" }).join;
  }

  method render-plain(Node:D $node, %locals, Int $offset) {
    my $obj = $node.object;
    my $text = interpolate(
      $obj.text, %locals,
      :line($obj.line), :column($obj.column),
    );
    $obj.get-indent(:$offset) ~ $text ~ "\n";
  }

  method render-children(Node:D $node, %locals, Int $offset) {
    self.render-sibling-list($node.children, %locals, $offset);
  }

  method render-sibling-list(@kids, %locals, Int $offset) {
    my $out = '';
    my $i = 0;
    while $i < @kids.elems {
      my $k = @kids[$i];
      my $obj = $k.object;
      if $obj.defined && $obj ~~ Statement && ($obj.kind eq 'if' || $obj.kind eq 'unless') {
        my ($html, $consumed) = self.render-conditional-chain(@kids, $i, %locals, $offset);
        $out ~= $html;
        $i += $consumed;
      } elsif $obj.defined && $obj ~~ Statement && ($obj.kind eq 'elsif' || $obj.kind eq 'else') {
        X::HAML::OrphanElse.new(
          :line($obj.line), :column($obj.column), :kind($obj.kind),
        ).throw;
      } else {
        $out ~= self.render-node($k, %locals, $offset);
        $i++;
      }
    }
    $out;
  }

  method render-conditional-chain(@kids, Int $start, %locals, Int $offset) {
    my $i = $start;
    my $first = @kids[$i];
    my $first-obj = $first.object;
    my $body-offset = $offset + 1;

    my $cond = eval-haml(
      $first-obj.expr, %locals,
      :line($first-obj.line), :column($first-obj.column),
    );
    $cond = !$cond if $first-obj.kind eq 'unless';

    my $matched = ?$cond;
    my $output  = $matched ?? self.render-children($first, %locals, $body-offset) !! '';

    $i++;
    while $i < @kids.elems {
      my $k = @kids[$i];
      my $o = $k.object;
      last unless $o.defined && $o ~~ Statement;
      if $o.kind eq 'elsif' {
        unless $matched {
          my $c = eval-haml(
            $o.expr, %locals,
            :line($o.line), :column($o.column),
          );
          if $c {
            $matched = True;
            $output  = self.render-children($k, %locals, $body-offset);
          }
        }
        $i++;
      } elsif $o.kind eq 'else' {
        unless $matched {
          $matched = True;
          $output  = self.render-children($k, %locals, $body-offset);
        }
        $i++;
        last;
      } else {
        last;
      }
    }

    ($output, $i - $start);
  }

  method render-comment(Node:D $node, %locals, Int $offset) {
    my $obj = $node.object;
    return '' if $obj.silent;

    my $indent = $obj.get-indent(:$offset);
    if $node.children.elems {
      my $out = $indent ~ $obj.open-tag ~ "\n";
      $out ~= self.render-children($node, %locals, $offset);
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

  method render-statement(Node:D $node, %locals, Int $offset) {
    my $obj = $node.object;

    given $obj.kind {
      when 'for'    { return self.render-for($node,    %locals, $offset) }
      when 'while'  { return self.render-while($node,  %locals, $offset) }
      when 'repeat' { return self.render-repeat($node, %locals, $offset) }
      when 'given'  { return self.render-given($node,  %locals, $offset) }
      when 'when' | 'default' {
        return self.render-children($node, %locals, $offset + 1);
      }
    }

    if $obj.op eq '==' {
      my $str = interpolate(
        $obj.expr, %locals,
        :line($obj.line), :column($obj.column),
      );
      my $own = $obj.get-indent(:$offset) ~ $str ~ "\n";
      my $kids = $node.children.elems
        ?? self.render-children($node, %locals, $offset)
        !! '';
      return $own ~ $kids;
    }

    if $!config.suppress-eval {
      my $kids = $node.children.elems
        ?? self.render-children($node, %locals, $offset)
        !! '';
      return $kids;
    }

    my @*HAML-CONCAT;
    my $value = eval-haml(
      $obj.expr, %locals,
      :line($obj.line), :column($obj.column),
    );
    my $buffered = @*HAML-CONCAT.join('');

    my $own = '';
    if $obj.outputs {
      my $is-safe = $value ~~ Template::HAML::Helpers::SafeString;
      my $str = $value.defined ?? $value.Str !! '';
      $str = html-escape($str) if self.should-escape($obj) && !$is-safe;
      if $obj.op eq '~' {
        $str = $str.subst("\n", '&#x000A;', :g);
      }
      $own  = $obj.get-indent(:$offset) ~ $buffered ~ $str ~ "\n";
    } elsif $buffered.chars {
      $own = $obj.get-indent(:$offset) ~ $buffered ~ "\n";
    }

    my $kids = $node.children.elems
      ?? self.render-children($node, %locals, $offset)
      !! '';
    $own ~ $kids;
  }

  method render-for(Node:D $node, %locals, Int $offset) {
    my $obj = $node.object;
    my $iter = eval-haml(
      $obj.loop-iter, %locals,
      :line($obj.line), :column($obj.column),
    );

    my $out = '';
    for @($iter // ()) -> $item {
      my %sub = %locals.clone;
      %sub{$obj.loop-var} = $item;
      $out ~= self.render-children($node, %sub, $offset + 1);
    }
    $out;
  }

  method render-repeat(Node:D $node, %locals, Int $offset) {
    my $obj = $node.object;
    my $n = eval-haml(
      $obj.expr, %locals,
      :line($obj.line), :column($obj.column),
    );
    my $count = ($n // 0).Int;
    $count = 0 if $count < 0;

    my $out = '';
    for ^$count {
      $out ~= self.render-children($node, %locals, $offset + 1);
    }
    $out;
  }

  method render-while(Node:D $node, %locals, Int $offset) {
    my $obj = $node.object;
    my $out = '';
    my $iters = 0;
    while eval-haml(
      $obj.expr, %locals,
      :line($obj.line), :column($obj.column),
    ) {
      $out ~= self.render-children($node, %locals, $offset + 1);
      last if ++$iters >= $!max-while-iters;
    }
    $out;
  }

  method render-given(Node:D $node, %locals, Int $offset) {
    my $obj = $node.object;
    my $topic = eval-haml(
      $obj.expr, %locals,
      :line($obj.line), :column($obj.column),
    );

    my %sub = %locals.clone;
    %sub<_> = $topic;

    my $out = '';
    my $matched = False;
    for $node.children -> $k {
      my $o = $k.object;
      next unless $o.defined && $o ~~ Statement;

      if $o.kind eq 'when' && !$matched {
        my $c = eval-haml(
          '$_ ~~ (' ~ $o.expr ~ ')', %sub,
          :line($o.line), :column($o.column),
        );
        if $c {
          $matched = True;
          $out ~= self.render-children($k, %sub, $offset + 2);
        }
      } elsif $o.kind eq 'default' && !$matched {
        $matched = True;
        $out ~= self.render-children($k, %sub, $offset + 2);
      }
    }
    $out;
  }
}
