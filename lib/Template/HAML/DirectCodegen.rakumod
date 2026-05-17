
use Template::HAML::Codegen;
use Template::HAML::Comment;
use Template::HAML::Config;
use Template::HAML::Doctype;
use Template::HAML::Filter;
use Template::HAML::Filters;
use Template::HAML::Interpolation;
use Template::HAML::Node;
use Template::HAML::Plain;
use Template::HAML::Statement;
use Template::HAML::Tag;
use Template::HAML::X;

unit module Template::HAML::DirectCodegen;

constant TRIM-BEFORE = "\x[E000]";
constant TRIM-AFTER  = "\x[E001]";

class X::HAML::DirectCodegenUnsupported is Exception is export {
  has Str $.reason;
  method message { "DirectCodegen: $!reason" }
}

sub unsupported(Str $reason) {
  X::HAML::DirectCodegenUnsupported.new(:$reason).throw;
}

# Internal identifiers chosen to avoid clashing with user locals.
constant BUF-VAR        = '$_haml_out';
constant LOCALS-VAR     = '%_haml_locals';
constant LOCALS-DYN-VAR = '%*HAML-LOCALS';
constant CONFIG-VAR     = '$_haml_config';
constant CTX-VAR        = '$_haml_ctx';
constant LINE-VAR       = '$_haml_line';

sub reserved-local-name(Str $name --> Bool) {
  $name.starts-with('_haml_');
}

class DirectCodegen is export {
  has Template::HAML::Config $.config;
  has Int $!tag-counter   = 0;
  has @!tag-preamble-lines;

  submethod BUILD(Template::HAML::Config :$config) {
    $!config = $config // Template::HAML::Config.new;
  }

  method !next-tag-var(--> Str) {
    '$_haml_tag_' ~ ++$!tag-counter;
  }

  method !is-dynamic-value($v --> Bool) {
    return False if !$v.defined;
    return True  if $v ~~ Template::HAML::Interpolation::InterpString;
    if $v ~~ Pair {
      return self!is-dynamic-value($v.value);
    }
    if $v ~~ Positional {
      for $v.list -> $item {
        return True if self!is-dynamic-value($item);
      }
    }
    False;
  }

  method !tag-has-dynamic-attrs(Tag:D $t --> Bool) {
    return True if $t.obj-ref-args.elems;
    for $t.attrs.list -> $a {
      return True if $a ~~ AttrSplat;
      if $a ~~ Pair {
        return True if self!is-dynamic-value($a.value);
      }
    }
    False;
  }

  method !validate(Node:D $tree) {
    unsupported('remove-whitespace not yet supported') if $!config.remove-whitespace;
    self!validate-node($tree);
  }

  method !validate-node(Node:D $node) {
    my $obj = $node.object;
    if $obj.defined {
      given $obj {
        when Statement {
          state %known = expression => True, if => True, elsif => True,
                          else => True,    unless => True, for => True,
                          while => True,   repeat => True, given => True,
                          when => True,    default => True;
          unsupported('unknown Statement kind: ' ~ $obj.kind)
            unless %known{$obj.kind};
        }
        when Filter {
          unless has-filter($obj.name) {
            X::HAML::UnknownFilter.new(
              :line($obj.line), :column($obj.column), :name($obj.name),
            ).throw;
          }
        }
        when Tag {
          if $obj.trim-inner {
            unsupported('trim-inner not yet supported in this phase');
          }
          if $!config.is-preserved($obj.name) && $node.children.elems {
            unsupported('preserved tags with children not yet supported in this phase');
          }
          if $obj.is-void && $node.children.elems {
            X::HAML::VoidWithChildren.new(
              :line($obj.line), :column($obj.column), :name($obj.name),
            ).throw;
          }
        }
      }
    }
    self!validate-node($_) for $node.children;
  }

  method !scan-locals(Node:D $tree --> List) {
    my %seen;
    self!scan-node-locals($tree, %seen);
    %seen.keys.sort.list;
  }

  method !scan-node-locals(Node:D $node, %seen) {
    my $obj = $node.object;
    if $obj.defined && $obj ~~ Statement {
      self!scan-statement-locals($obj, %seen);
    }
    self!scan-node-locals($_, %seen) for $node.children;
  }

  method !scan-statement-locals(Statement:D $s, %seen) {
    given $s.kind {
      when 'expression' {
        if $s.op ne '==' && !$s.is-bare-ident {
          self!collect-ident-names($s.expr // '', %seen);
        }
      }
      when 'for' {
        self!collect-ident-names($s.loop-iter // '', %seen);
      }
      when 'if' | 'elsif' | 'unless' | 'while' | 'repeat' | 'given' | 'when' {
        unless $s.is-bare-ident {
          self!collect-ident-names($s.expr // '', %seen);
        }
      }
    }
  }

  method !collect-ident-names(Str $text, %seen) {
    for $text.match(/ '$' (<[A..Za..z_]> <[\w \-]>*) /, :g) -> $m {
      my $name = ~$m[0];
      next if $name eq '_';
      next if reserved-local-name($name);
      %seen{$name} = True;
    }
  }

  method !emit-doctype(Doctype:D $d --> Str) {
    my $literal = $d.render ~ "\n";
    '  ' ~ BUF-VAR ~ ' ~= ' ~ raku-str($literal) ~ ';';
  }

  method !emit-plain(Plain:D $p, Int $offset --> Str) {
    my $indent-str = $p.get-indent(:$offset);
    my $text       = $p.text // '';
    if has-interp($text) {
      '  ' ~ BUF-VAR ~ ' ~= ' ~ raku-str($indent-str) ~ ' ~ interpolate('
        ~ raku-str($text) ~ ', ' ~ LOCALS-DYN-VAR ~ ', :line(' ~ ($p.line // 0)
        ~ '), :column(' ~ ($p.column // 0) ~ ')) ~ "\n";';
    } else {
      '  ' ~ BUF-VAR ~ ' ~= ' ~ raku-str($indent-str ~ $text ~ "\n") ~ ';';
    }
  }

  method !emit-comment-lines(Node:D $node, Comment:D $c, Int $offset --> List) {
    return ().List if $c.silent;

    my @lines;
    my $indent-str = $c.get-indent(:$offset);
    if $node.children.elems {
      @lines.push: '  ' ~ BUF-VAR ~ ' ~= ' ~ raku-str($indent-str ~ $c.open-tag ~ "\n") ~ ';';
      @lines.append: self!emit-children-lines($node, $offset);
      @lines.push: '  ' ~ BUF-VAR ~ ' ~= ' ~ raku-str($indent-str ~ $c.close-tag ~ "\n") ~ ';';
    } else {
      my $text = $c.text;
      my $body = '';
      if $text {
        $body = $c.condition ?? $text !! " $text ";
      }
      @lines.push: '  ' ~ BUF-VAR ~ ' ~= '
        ~ raku-str($indent-str ~ $c.open-tag ~ $body ~ $c.close-tag ~ "\n") ~ ';';
    }
    @lines.List;
  }

  method !content-expr(Tag:D $t --> Str) {
    my $content = $t.content // '';
    return raku-str('') unless $content.chars;
    if has-interp($content) {
      'interpolate(' ~ raku-str($content)
        ~ ', ' ~ LOCALS-DYN-VAR
        ~ ', :line(' ~ ($t.line // 0)
        ~ '), :column(' ~ ($t.column // 0) ~ '))';
    } else {
      raku-str($content);
    }
  }

  method !emit-tag-lines(Node:D $node, Tag:D $t, Int $offset --> List) {
    if self!tag-has-dynamic-attrs($t) {
      return self!emit-dynamic-tag-lines($node, $t, $offset);
    }

    my @lines;
    my $open       = $t.open(:$offset);
    my $close      = $t.close;
    my $content-rk = self!content-expr($t);
    my $trim-outer = $t.trim-outer;
    my $tb-prefix  = $trim-outer ?? raku-str(TRIM-BEFORE) ~ ' ~ ' !! '';
    my $ta-suffix  = $trim-outer ?? ' ~ ' ~ raku-str(TRIM-AFTER) !! '';

    if $t.self-close {
      @lines.push: '  ' ~ BUF-VAR ~ ' ~= ' ~ $tb-prefix
        ~ raku-str($open ~ $close) ~ $ta-suffix ~ ';';
      return @lines.List;
    }

    if !$node.children.elems {
      @lines.push: '  ' ~ BUF-VAR ~ ' ~= ' ~ $tb-prefix
        ~ raku-str($open) ~ ' ~ ' ~ $content-rk ~ ' ~ '
        ~ raku-str($close) ~ $ta-suffix ~ ';';
      return @lines.List;
    }

    my $close-indent = $t.get-indent(:$offset);

    @lines.push: '  ' ~ BUF-VAR ~ ' ~= ' ~ raku-str(TRIM-BEFORE) ~ ';' if $trim-outer;

    my $content = $t.content // '';
    if $content.chars {
      @lines.push: '  ' ~ BUF-VAR ~ ' ~= ' ~ raku-str($open) ~ ' ~ ' ~ $content-rk ~ ' ~ "\n";';
    } else {
      @lines.push: '  ' ~ BUF-VAR ~ ' ~= ' ~ raku-str($open ~ "\n") ~ ';';
    }

    @lines.append: self!emit-children-lines($node, $offset);

    @lines.push: '  ' ~ BUF-VAR ~ ' ~= ' ~ raku-str($close-indent ~ $close) ~ ';';
    @lines.push: '  ' ~ BUF-VAR ~ ' ~= ' ~ raku-str(TRIM-AFTER) ~ ';' if $trim-outer;

    @lines.List;
  }

  method !emit-dynamic-tag-lines(Node:D $node, Tag:D $t, Int $offset --> List) {
    my @lines;
    my $tag-var      = self!next-tag-var;
    my $tag-ctor     = ser-tag($t);
    @!tag-preamble-lines.push: '  state ' ~ $tag-var ~ ' = ' ~ $tag-ctor ~ ';';

    my $content-rk = self!content-expr($t);
    my $trim-outer = $t.trim-outer;
    my $tb-prefix  = $trim-outer ?? raku-str(TRIM-BEFORE) ~ ' ~ ' !! '';
    my $ta-suffix  = $trim-outer ?? ' ~ ' ~ raku-str(TRIM-AFTER) !! '';

    my $open-expr = 'render-direct-tag-open(' ~ $tag-var ~ ', ' ~ LOCALS-DYN-VAR
      ~ ', :offset(' ~ $offset ~ '))';
    my $close-expr = $tag-var ~ '.close';
    my $close-indent-expr = $tag-var ~ '.get-indent(:offset(' ~ $offset ~ '))';

    if $t.self-close {
      @lines.push: '  ' ~ BUF-VAR ~ ' ~= ' ~ $tb-prefix
        ~ $open-expr ~ ' ~ ' ~ $close-expr ~ $ta-suffix ~ ';';
      return @lines.List;
    }

    if !$node.children.elems {
      @lines.push: '  ' ~ BUF-VAR ~ ' ~= ' ~ $tb-prefix
        ~ $open-expr ~ ' ~ ' ~ $content-rk ~ ' ~ '
        ~ $close-expr ~ $ta-suffix ~ ';';
      return @lines.List;
    }

    @lines.push: '  ' ~ BUF-VAR ~ ' ~= ' ~ raku-str(TRIM-BEFORE) ~ ';' if $trim-outer;

    my $content = $t.content // '';
    if $content.chars {
      @lines.push: '  ' ~ BUF-VAR ~ ' ~= ' ~ $open-expr ~ ' ~ ' ~ $content-rk ~ ' ~ "\n";';
    } else {
      @lines.push: '  ' ~ BUF-VAR ~ ' ~= ' ~ $open-expr ~ ' ~ "\n";';
    }

    @lines.append: self!emit-children-lines($node, $offset);

    @lines.push: '  ' ~ BUF-VAR ~ ' ~= ' ~ $close-indent-expr ~ ' ~ ' ~ $close-expr ~ ';';
    @lines.push: '  ' ~ BUF-VAR ~ ' ~= ' ~ raku-str(TRIM-AFTER) ~ ';' if $trim-outer;

    @lines.List;
  }

  method !emit-statement-lines(Node:D $node, Statement:D $s, Int $offset --> List) {
    given $s.kind {
      when 'expression' { return self!emit-expression-statement($node, $s, $offset) }
      when 'for'        { return self!emit-for($node, $s, $offset)    }
      when 'while'      { return self!emit-while($node, $s, $offset)  }
      when 'repeat'     { return self!emit-repeat($node, $s, $offset) }
      when 'given'      { return self!emit-given($node, $s, $offset)  }
      when 'when' | 'default' {
        return self!emit-children-lines($node, $offset + 1);
      }
      default {
        unsupported('unhandled Statement kind: ' ~ $s.kind);
      }
    }
  }

  method !emit-expression-statement(Node:D $node, Statement:D $s, Int $offset --> List) {
    my @lines;
    my $indent-str = $s.get-indent(:$offset);
    my $line  = $s.line   // 0;
    my $col   = $s.column // 0;
    my $op    = $s.op     // '';
    my $expr  = $s.expr   // '';

    if $op eq '==' {
      @lines.push: '  ' ~ BUF-VAR ~ ' ~= ' ~ raku-str($indent-str)
        ~ ' ~ interpolate(' ~ raku-str($expr) ~ ', ' ~ LOCALS-DYN-VAR
        ~ ', :line(' ~ $line ~ '), :column(' ~ $col ~ ')) ~ "\n";';
    } elsif $!config.suppress-eval {
      # No-op: eval suppressed; children (rendered below) carry on.
    } else {
      @lines.append: self!emit-eval-statement($s, $indent-str, $line, $col, $expr);
    }

    @lines.append: self!emit-children-lines($node, $offset);
    @lines.List;
  }

  method !wrap-eval(Str $expr, Int $line, Int $col --> Str) {
    'eval-direct({ ' ~ $expr ~ ' }, ' ~ raku-str($expr)
      ~ ', :line(' ~ $line ~ '), :column(' ~ $col ~ '))';
  }

  method !eval-cond-as-raku(
    Str $expr, Bool $is-bare-ident, Int $line, Int $col --> Str
  ) {
    if $is-bare-ident {
      'eval-bare-ident(' ~ raku-str($expr) ~ ', ' ~ LOCALS-DYN-VAR
        ~ ', :line(' ~ $line ~ '), :column(' ~ $col ~ '))';
    } else {
      self!wrap-eval($expr, $line, $col);
    }
  }

  method !emit-if-chain(@kids, Int $start, Int $offset --> List) {
    my @lines;
    my $i = $start;
    my $first = @kids[$i];
    my $first-obj = $first.object;
    my $body-offset = $offset + 1;

    my $cond = self!eval-cond-as-raku(
      $first-obj.expr // '', $first-obj.is-bare-ident,
      $first-obj.line // 0, $first-obj.column // 0,
    );
    $cond = '!(' ~ $cond ~ ')' if $first-obj.kind eq 'unless';
    @lines.push: '  if ' ~ $cond ~ ' {';
    @lines.append: self!emit-children-lines($first, $body-offset);

    $i++;
    while $i < @kids.elems {
      my $k = @kids[$i];
      my $o = $k.object;
      last unless $o.defined && $o ~~ Statement;
      if $o.kind eq 'elsif' {
        my $c = self!eval-cond-as-raku(
          $o.expr // '', $o.is-bare-ident,
          $o.line // 0, $o.column // 0,
        );
        @lines.push: '  } elsif ' ~ $c ~ ' {';
        @lines.append: self!emit-children-lines($k, $body-offset);
        $i++;
      } elsif $o.kind eq 'else' {
        @lines.push: '  } else {';
        @lines.append: self!emit-children-lines($k, $body-offset);
        $i++;
        last;
      } else {
        last;
      }
    }

    @lines.push: '  }';
    (@lines.List, $i - $start);
  }

  method !emit-for(Node:D $node, Statement:D $s, Int $offset --> List) {
    my @lines;
    my $iter = $s.loop-iter // '';
    my $var  = $s.loop-var;
    my $iter-expr = self!wrap-eval($iter, $s.line // 0, $s.column // 0);
    @lines.push: '  for @(' ~ $iter-expr ~ ' // ()) -> $' ~ $var ~ ' {';
    @lines.push: '    my %*HAML-LOCALS = %*HAML-LOCALS.clone;';
    @lines.push: '    %*HAML-LOCALS<' ~ $var ~ '> = $' ~ $var ~ ';';
    @lines.append: self!emit-children-lines($node, $offset + 1);
    @lines.push: '  }';
    @lines.List;
  }

  method !emit-while(Node:D $node, Statement:D $s, Int $offset --> List) {
    my @lines;
    my $cond = self!eval-cond-as-raku(
      $s.expr // '', $s.is-bare-ident,
      $s.line // 0, $s.column // 0,
    );
    @lines.push: '  do {';
    @lines.push: '    my Int $_haml_iters = 0;';
    @lines.push: '    while ' ~ $cond ~ ' {';
    @lines.append: self!emit-children-lines($node, $offset + 1);
    @lines.push: '      last if ++$_haml_iters >= 10000;';
    @lines.push: '    }';
    @lines.push: '  };';
    @lines.List;
  }

  method !emit-repeat(Node:D $node, Statement:D $s, Int $offset --> List) {
    my @lines;
    my $expr = self!eval-cond-as-raku(
      $s.expr // '', $s.is-bare-ident,
      $s.line // 0, $s.column // 0,
    );
    @lines.push: '  do {';
    @lines.push: '    my $_haml_n = ' ~ $expr ~ ';';
    @lines.push: '    my $_haml_cnt = ($_haml_n // 0).Int;';
    @lines.push: '    $_haml_cnt = 0 if $_haml_cnt < 0;';
    @lines.push: '    for ^$_haml_cnt {';
    @lines.append: self!emit-children-lines($node, $offset + 1);
    @lines.push: '    }';
    @lines.push: '  };';
    @lines.List;
  }

  method !emit-given(Node:D $node, Statement:D $s, Int $offset --> List) {
    my @lines;
    my $topic = self!eval-cond-as-raku(
      $s.expr // '', $s.is-bare-ident,
      $s.line // 0, $s.column // 0,
    );
    @lines.push: '  do {';
    @lines.push: '    my Bool $_haml_matched = False;';
    @lines.push: '    given ' ~ $topic ~ ' {';
    @lines.push: '      my %*HAML-LOCALS = %*HAML-LOCALS.clone;';
    @lines.push: '      %*HAML-LOCALS<_> = $_;';
    for $node.children -> $k {
      my $o = $k.object;
      next unless $o.defined && $o ~~ Statement;
      given $o.kind {
        when 'when' {
          my $when-expr = self!wrap-eval(
            $o.expr // '', $o.line // 0, $o.column // 0,
          );
          @lines.push: '      if !$_haml_matched && ($_ ~~ ' ~ $when-expr ~ ') {';
          @lines.push: '        $_haml_matched = True;';
          @lines.append: self!emit-children-lines($k, $offset + 2);
          @lines.push: '      }';
        }
        when 'default' {
          @lines.push: '      if !$_haml_matched {';
          @lines.push: '        $_haml_matched = True;';
          @lines.append: self!emit-children-lines($k, $offset + 2);
          @lines.push: '      }';
        }
      }
    }
    @lines.push: '    }';
    @lines.push: '  };';
    @lines.List;
  }

  method !emit-eval-statement(
    Statement:D $s,
    Str  $indent-str,
    Int  $line,
    Int  $col,
    Str  $expr,
    --> List
  ) {
    my $op       = $s.op // '';
    my $outputs  = $op ne '-';
    my $is-tilde = $op eq '~';

    my $escape-bool;
    if !$outputs {
      $escape-bool = False;
    } elsif $op eq '&=' {
      $escape-bool = True;
    } elsif $op eq '!=' {
      $escape-bool = False;
    } else {
      $escape-bool = $!config.escape-html;
    }

    my $value-expr;
    if $s.is-bare-ident {
      $value-expr = 'eval-bare-ident(' ~ raku-str($expr) ~ ', ' ~ LOCALS-DYN-VAR
        ~ ', :line(' ~ $line ~ '), :column(' ~ $col ~ '))';
    } else {
      $value-expr = 'do { ' ~ $expr ~ ' }';
    }

    my @lines;
    @lines.push: '  do {';
    @lines.push: '    CATCH {';
    @lines.push: '      when X::HAML::Eval { .throw }';
    @lines.push: '      default {';
    @lines.push: '        X::HAML::Eval.new(:code(' ~ raku-str($expr)
      ~ '), :line(' ~ $line ~ '), :column(' ~ $col
      ~ '), :reason(.message)).throw;';
    @lines.push: '      }';
    @lines.push: '    }';
    @lines.push: '    my @*HAML-CONCAT;';
    @lines.push: '    my $_haml_value = ' ~ $value-expr ~ ';';
    @lines.push: '    my $_haml_buffered = @*HAML-CONCAT.join("");';

    if $outputs {
      @lines.push: '    my $_haml_safe = $_haml_value ~~ Template::HAML::Helpers::SafeString;';
      @lines.push: '    my $_haml_str = $_haml_value.defined ?? $_haml_value.Str !! "";';
      if $escape-bool {
        @lines.push: '    $_haml_str = html-escape($_haml_str) unless $_haml_safe;';
      }
      if $is-tilde {
        @lines.push: '    $_haml_str = $_haml_str.subst("\n", "&#x000A;", :g);';
      }
      @lines.push: '    ' ~ BUF-VAR ~ ' ~= '
        ~ raku-str($indent-str) ~ ' ~ $_haml_buffered ~ $_haml_str ~ "\n";';
    } else {
      @lines.push: '    if $_haml_buffered.chars {';
      @lines.push: '      ' ~ BUF-VAR ~ ' ~= '
        ~ raku-str($indent-str) ~ ' ~ $_haml_buffered ~ "\n";';
      @lines.push: '    }';
    }

    @lines.push: '  };';
    @lines.List;
  }

  method !emit-filter-lines(Node:D $node, Filter:D $f, Int $offset --> List) {
    my $name   = $f.name // '';
    my $body   = $f.body // '';
    my $indent = $f.get-indent(:$offset);
    my $line   = $f.line   // 0;
    my $col    = $f.column // 0;

    my @lines;
    @lines.push: '  do {';
    @lines.push: '    my &_haml_filter = lookup-filter(' ~ raku-str($name) ~ ');';
    @lines.push: '    my $_haml_rendered = do {';
    @lines.push: '      CATCH {';
    @lines.push: '        when X::HAML::MarkdownBackendMissing {';
    @lines.push: '          X::HAML::MarkdownBackendMissing.new(:line(' ~ $line
      ~ '), :column(' ~ $col ~ ')).throw;';
    @lines.push: '        }';
    @lines.push: '      }';
    @lines.push: '      _haml_filter(' ~ raku-str($body) ~ ', ' ~ LOCALS-DYN-VAR ~ ');';
    @lines.push: '    };';
    @lines.push: '    if $_haml_rendered.defined && $_haml_rendered.chars {';
    @lines.push: '      ' ~ BUF-VAR
      ~ ' ~= $_haml_rendered.lines.map({ '
      ~ raku-str($indent) ~ ' ~ $_ ~ "\n" }).join;';
    @lines.push: '    }';
    @lines.push: '  };';
    @lines.List;
  }

  method !emit-children-lines(Node:D $node, Int $offset --> List) {
    self!emit-sibling-lines($node.children.list, $offset);
  }

  method !emit-sibling-lines(@kids, Int $offset --> List) {
    my @lines;
    my $i = 0;
    while $i < @kids.elems {
      my $k = @kids[$i];
      my $obj = $k.object;
      if $obj.defined && $obj ~~ Statement
         && ($obj.kind eq 'if' || $obj.kind eq 'unless') {
        my ($chain, $consumed) = self!emit-if-chain(@kids, $i, $offset);
        @lines.append: @($chain);
        $i += $consumed;
      } elsif $obj.defined && $obj ~~ Statement
              && ($obj.kind eq 'elsif' || $obj.kind eq 'else') {
        X::HAML::OrphanElse.new(
          :line($obj.line), :column($obj.column), :kind($obj.kind),
        ).throw;
      } else {
        @lines.append: self!emit-node-lines($k, $offset);
        $i++;
      }
    }
    @lines.List;
  }

  method !emit-node-lines(Node:D $node, Int $offset --> List) {
    my $obj = $node.object;
    return self!emit-children-lines($node, $offset) unless $obj.defined;

    given $obj {
      when Doctype   { return (self!emit-doctype($obj),).List }
      when Plain     { return (self!emit-plain($obj, $offset),).List }
      when Comment   { return self!emit-comment-lines($node, $obj, $offset) }
      when Tag       { return self!emit-tag-lines($node, $obj, $offset) }
      when Statement { return self!emit-statement-lines($node, $obj, $offset) }
      when Filter    { return self!emit-filter-lines($node, $obj, $offset) }
      default {
        unsupported('unsupported node payload ' ~ $obj.WHAT.^name);
      }
    }
  }

  method !uses(--> List) {
    (
      'use Template::HAML::Config;',
      'use Template::HAML::DirectEmit;',
      'use Template::HAML::Filters;',
      'use Template::HAML::Helpers;',
      'use Template::HAML::Interpolation;',
      'use Template::HAML::Tag;',
      'use Template::HAML::X;',
    ).List;
  }

  method !preamble(@locals --> List) {
    my @lines;
    @lines.push: '  my $cfg = ' ~ CONFIG-VAR ~ ' // ' ~ ser-config($!config) ~ ';';
    @lines.push: '  my Int $*HAML-TAB-OFFSET = 0;';
    @lines.push: '  my $*HAML-CTX = ' ~ CTX-VAR ~ ';';
    @lines.push: '  my $*HAML-CFG = $cfg;';
    @lines.push: '  my ' ~ LOCALS-DYN-VAR ~ ' = ' ~ LOCALS-VAR ~ ';';
    @lines.push: '  my ' ~ BUF-VAR ~ ' = "";';
    for @locals -> $name {
      @lines.push: '  my $' ~ $name ~ ' = ' ~ LOCALS-VAR ~ '<' ~ $name ~ '>;';
    }
    @lines.append: @!tag-preamble-lines;
    @lines.List;
  }

  method !postamble(--> List) {
    my @lines;
    @lines.push: Q[  ] ~ BUF-VAR
      ~ Q[ = ] ~ BUF-VAR
      ~ Q[.subst(/\s* "] ~ TRIM-BEFORE ~ Q[" \s*/, "", :g);];
    @lines.push: Q[  ] ~ BUF-VAR
      ~ Q[ = ] ~ BUF-VAR
      ~ Q[.subst(/\s* "] ~ TRIM-AFTER  ~ Q[" \s*/, "", :g);];
    if $!config.is-ugly {
      @lines.push: '  ' ~ BUF-VAR ~ ' = ' ~ BUF-VAR ~ '.lines.map(*.trim).grep(*.chars).join("");';
    }
    @lines.push: '  ' ~ BUF-VAR ~ ';';
    @lines.List;
  }

  method !signature(Str $head --> Str) {
    $head ~ '('
      ~ LOCALS-VAR ~ ' = %(), '
      ~ 'Template::HAML::Config :' ~ CONFIG-VAR ~ ', '
      ~ ':' ~ CTX-VAR
      ~ ' --> Str)';
  }

  method !reset-state {
    $!tag-counter        = 0;
    @!tag-preamble-lines = ();
  }

  method emit-direct(Node:D $tree --> Str) {
    self!reset-state;
    self!validate($tree);
    my @locals    = self!scan-locals($tree);
    my @body      = self!emit-children-lines($tree, 0);
    my @lines;
    @lines.append: self!uses;
    @lines.push: '';
    @lines.push: self!signature('sub ') ~ ' {';
    @lines.append: self!preamble(@locals);
    @lines.append: @body;
    @lines.append: self!postamble;
    @lines.push: '}';
    @lines.join("\n") ~ "\n";
  }

  method emit-direct-module(Node:D $tree, Str:D :$module-name! --> Str) {
    self!reset-state;
    self!validate($tree);
    my @locals    = self!scan-locals($tree);
    my @body      = self!emit-children-lines($tree, 0);
    my @lines;
    @lines.push: 'unit module ' ~ $module-name ~ ';';
    @lines.push: '';
    @lines.append: self!uses;
    @lines.push: '';
    @lines.push: 'our sub haml-render(%locals = %(), Template::HAML::Config :$config, :$ctx --> Str) is export {';
    @lines.push: '  &_haml_body(%locals, :' ~ CONFIG-VAR.substr(1) ~ '($config), :'
      ~ CTX-VAR.substr(1) ~ '($ctx));';
    @lines.push: '}';
    @lines.push: '';
    @lines.push: self!signature('sub _haml_body') ~ ' {';
    @lines.append: self!preamble(@locals);
    @lines.append: @body;
    @lines.append: self!postamble;
    @lines.push: '}';
    @lines.join("\n") ~ "\n";
  }
}
