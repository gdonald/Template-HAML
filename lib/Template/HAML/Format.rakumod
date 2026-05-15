
use Template::HAML::Actions;
use Template::HAML::Comment;
use Template::HAML::Config;
use Template::HAML::Doctype;
use Template::HAML::Filter;
use Template::HAML::Grammar;
use Template::HAML::Interpolation;
use Template::HAML::Multiline;
use Template::HAML::Node;
use Template::HAML::Plain;
use Template::HAML::Statement;
use Template::HAML::Tag;
use Template::HAML::X;

class X::HAML::FormatUnsupported is X::HAML is export {
  has Str $.kind;
  method message {
    self.loc ~ " format: unsupported construct '$!kind'" ~ self.caret
  }
}

my $PLAIN-SIGIL-RX = rx/^ <[%.#=\-!&~/:\\]> /;

class Formatter is export {
  has Template::HAML::Config $.config;

  submethod BUILD(Template::HAML::Config :$config) {
    $!config = $config // Template::HAML::Config.new;
  }

  method format-source(Str:D $src --> Str) {
    my $normalized = $src.subst(:global, /\r\n/, "\n").subst(:global, /\r/, "\n");
    my $joined     = preprocess-multiline($normalized);

    my $root = Node.new;
    $root.add-child(Node.new);
    my $actions = Actions.new(:tree($root), :config($!config));
    my $m = Grammar.parse($joined, :$actions);
    unless $m {
      X::HAML::ParseFail.new(:line(0), :column(0), :snippet('')).throw;
    }

    my $out = self!emit-children($actions.tree, 0);
    self!normalize-blanks($out);
  }

  method !emit-children(Node:D $node, Int $level --> Str) {
    my $out = '';
    my $prev-last-line;
    for $node.children -> $kid {
      my $obj = $kid.object;
      next unless $obj.defined;
      if $prev-last-line.defined && $obj.^can('line') && $obj.line.defined && $obj.line > $prev-last-line + 1 {
        $out ~= "\n";
      }
      $out ~= self!emit-node($kid, $level);
      $prev-last-line = self!subtree-last-line($kid);
    }
    $out;
  }

  method !subtree-last-line(Node:D $node) {
    my $obj = $node.object;
    return Nil unless $obj.defined;
    my $last = ($obj.^can('line') && $obj.line.defined) ?? $obj.line !! Nil;
    for $node.children -> $kid {
      my $c = self!subtree-last-line($kid);
      $last = $c if $c.defined && (!$last.defined || $c > $last);
    }
    $last;
  }

  method !emit-node(Node:D $node, Int $level --> Str) {
    my $obj = $node.object;
    return '' unless $obj.defined;

    return self!emit-tag($node, $level)       if $obj ~~ Tag;
    return self!emit-plain($node, $level)     if $obj ~~ Plain;
    return self!emit-statement($node, $level) if $obj ~~ Statement;
    return self!emit-comment($node, $level)   if $obj ~~ Comment;
    return self!emit-doctype($node, $level)   if $obj ~~ Doctype;
    return self!emit-filter($node, $level)    if $obj ~~ Filter;

    self!unsupported($obj.^name.lc, $obj);
  }

  method !emit-statement(Node:D $node, Int $level --> Str) {
    my $obj = $node.object;
    my $indent = '  ' x $level;
    my $head;

    given $obj.kind {
      when 'expression' { $head = $indent ~ $obj.op ~ ' ' ~ $obj.expr      }
      when 'if'         { $head = $indent ~ '- if '     ~ $obj.expr        }
      when 'unless'     { $head = $indent ~ '- unless ' ~ $obj.expr        }
      when 'elsif'      { $head = $indent ~ '- elsif '  ~ $obj.expr        }
      when 'else'       { $head = $indent ~ '- else'                       }
      when 'while'      { $head = $indent ~ '- while '  ~ $obj.expr        }
      when 'repeat'     { $head = $indent ~ '- repeat ' ~ $obj.expr        }
      when 'given'      { $head = $indent ~ '- given '  ~ $obj.expr        }
      when 'when'       { $head = $indent ~ '- when '   ~ $obj.expr        }
      when 'default'    { $head = $indent ~ '- default'                    }
      when 'for'        {
        $head = $indent ~ '- for $' ~ $obj.loop-var ~ ' in ' ~ $obj.loop-iter;
      }
      default { $head = $indent ~ $obj.op ~ ' ' ~ $obj.expr }
    }

    my $out = $head ~ "\n";
    $out ~= self!emit-children($node, $level + 1) if $node.children.elems;
    $out;
  }

  method !emit-doctype(Node:D $node, Int $level --> Str) {
    my $obj    = $node.object;
    my $indent = '  ' x $level;
    my $head   = $indent ~ '!!!';
    if $obj.arg.defined && $obj.arg.chars {
      $head ~= ' ' ~ $obj.arg;
      $head ~= ' ' ~ $obj.encoding if $obj.encoding.defined && $obj.encoding.chars;
    }
    $head ~ "\n";
  }

  method !emit-comment(Node:D $node, Int $level --> Str) {
    my $obj    = $node.object;
    my $indent = '  ' x $level;

    if $obj.silent {
      my $body-indent = '  ' x ($level + 1);
      my $head = $indent ~ '-#';
      $head ~= ' ' ~ $obj.text.trim if $obj.text.defined && $obj.text.trim.chars;
      my $out = $head ~ "\n";
      if $obj.silent-body.defined && $obj.silent-body.chars {
        for $obj.silent-body.split("\n") -> $bl {
          $out ~= $bl.chars ?? $body-indent ~ $bl ~ "\n" !! "\n";
        }
      }
      return $out;
    }

    my $head = $indent ~ '/';
    $head ~= '!' if $obj.revealed;
    $head ~= '[' ~ $obj.condition ~ ']' if $obj.condition.defined && $obj.condition.chars;

    if $node.children.elems {
      return $head ~ "\n" ~ self!emit-children($node, $level + 1);
    }
    if $obj.text.defined && $obj.text.chars {
      return $head ~ ' ' ~ $obj.text ~ "\n";
    }
    $head ~ "\n";
  }

  method !emit-filter(Node:D $node, Int $level --> Str) {
    my $obj         = $node.object;
    my $indent      = '  ' x $level;
    my $body-indent = '  ' x ($level + 1);

    my $out = $indent ~ ':' ~ $obj.name ~ "\n";
    return $out unless $obj.body.defined && $obj.body.chars;

    for $obj.body.split("\n") -> $line {
      $out ~= $line.chars ?? $body-indent ~ $line ~ "\n" !! "\n";
    }
    $out;
  }

  method !emit-tag(Node:D $node, Int $level --> Str) {
    my $obj = $node.object;

    my $indent = '  ' x $level;
    my $has-shorthand = ?($obj.classes.elems || $obj.ids.elems);

    my $head = $indent;
    if $has-shorthand && $obj.name eq 'div' {
      # implicit div: emit shorthand only
    } else {
      $head ~= '%' ~ $obj.name;
    }

    for $obj.classes.list -> $cls {
      $head ~= '.' ~ $cls;
    }
    if $obj.ids.elems {
      $head ~= '#' ~ $obj.ids[0];
    }

    if $obj.obj-ref-args.elems {
      $head ~= '[' ~ $obj.obj-ref-args.join(', ') ~ ']';
    }

    if $obj.source-attrs.elems {
      $head ~= self!emit-attrs($obj.source-attrs.list);
    }

    if    $obj.trim-outer && $obj.trim-inner { $head ~= '<>' }
    elsif $obj.trim-outer                    { $head ~= '>'  }
    elsif $obj.trim-inner                    { $head ~= '<'  }

    $head ~= '/' if $obj.self-close && !$obj.is-void;

    my $content = ($obj.content // '');
    my $has-kids = ?$node.children.elems;

    if $has-kids && $content.chars {
      return $head ~ ' ' ~ $content ~ "\n" ~ self!emit-children($node, $level + 1);
    }
    return $head ~ "\n" ~ self!emit-children($node, $level + 1) if $has-kids;
    return $head ~ ' ' ~ $content ~ "\n"                       if $content.chars;
    $head ~ "\n";
  }

  method !emit-attrs(@attrs --> Str) {
    my @parts;
    for @attrs -> $a {
      if $a ~~ AttrSplat {
        @parts.push: '|' ~ $a.expr;
      } else {
        @parts.push: self!emit-pair($a.key, $a.value);
      }
    }
    '{' ~ @parts.join(', ') ~ '}';
  }

  method !emit-pair(Str:D $key, $value --> Str) {
    my $rv = self!emit-value($value);
    $key ~~ /^ <[A..Za..z_]> <[A..Za..z0..9_]>* $/
      ?? "$key: $rv"
      !! self!emit-string($key) ~ " => $rv";
  }

  method !emit-value($v --> Str) {
    return 'Nil'                                       unless $v.defined;
    return $v ?? 'True' !! 'False'                     if $v ~~ Bool;
    return $v.Str                                      if $v ~~ Int;
    return $v.Str                                      if $v ~~ Numeric;
    if $v ~~ Template::HAML::Interpolation::InterpString {
      return '"' ~ $v.raw ~ '"';
    }
    if $v ~~ Positional && $v !~~ Pair {
      my @l = $v.list;
      if @l.elems && @l[0] ~~ Pair {
        return '{' ~ @l.map({ self!emit-pair(.key, .value) }).join(', ') ~ '}';
      }
      return '[' ~ @l.map({ self!emit-value($_) }).join(', ') ~ ']';
    }
    self!emit-string($v.Str);
  }

  method !emit-string(Str:D $s --> Str) {
    my $needs-dq = $s.contains("'") || $s.contains("\n") || $s.contains("\t") || $s.contains("\r");
    if $needs-dq {
      my $esc = $s
        .subst('\\', '\\\\', :g)
        .subst('"',  '\\"',  :g)
        .subst("\n", '\\n',  :g)
        .subst("\t", '\\t',  :g)
        .subst("\r", '\\r',  :g);
      return '"' ~ $esc ~ '"';
    }
    my $esc = $s.subst('\\', '\\\\', :g);
    "'" ~ $esc ~ "'";
  }

  method !emit-plain(Node:D $node, Int $level --> Str) {
    my $obj    = $node.object;
    my $indent = '  ' x $level;
    my $text   = $obj.text;

    if $text.chars && $text ~~ $PLAIN-SIGIL-RX {
      return $indent ~ '\\' ~ $text ~ "\n";
    }
    $indent ~ $text ~ "\n";
  }

  method !normalize-blanks(Str:D $s --> Str) {
    my @lines = $s.split("\n");
    @lines.pop if @lines.elems && @lines[*-1] eq '';

    my @out;
    my $prev-blank = True;
    for @lines -> $line {
      my $blank = ($line ~~ /^ \s* $/).so;
      next if $blank && $prev-blank;
      @out.push: $line;
      $prev-blank = $blank;
    }
    while @out.elems && @out[*-1] ~~ /^ \s* $/ { @out.pop }
    @out.elems ?? @out.join("\n") ~ "\n" !! '';
  }

  method !unsupported(Str:D $kind, $obj) {
    my $line   = ($obj.defined && $obj.^can('line'))   ?? $obj.line   !! 0;
    my $column = ($obj.defined && $obj.^can('column')) ?? $obj.column !! 0;
    X::HAML::FormatUnsupported.new(:$kind, :$line, :$column).throw;
  }
}

sub format-source(Str:D $src, Template::HAML::Config :$config --> Str) is export {
  Formatter.new(:$config).format-source($src);
}
