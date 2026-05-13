
use Template::HAML::Comment;
use Template::HAML::Config;
use Template::HAML::Doctype;
use Template::HAML::Filter;
use Template::HAML::Interpolation;
use Template::HAML::Node;
use Template::HAML::Plain;
use Template::HAML::Statement;
use Template::HAML::Tag;

unit module Template::HAML::Codegen;

sub raku-str(Str $s --> Str) is export {
  my $escaped = $s
    .subst('\\', '\\\\', :g)
    .subst('"',  '\\"',  :g)
    .subst('$',  '\\$',  :g)
    .subst('@',  '\\@',  :g)
    .subst('%',  '\\%',  :g)
    .subst('&',  '\\&',  :g)
    .subst('{',  '\\{',  :g)
    .subst("\n", '\\n',  :g)
    .subst("\t", '\\t',  :g)
    .subst("\r", '\\r',  :g)
    .subst("\0", '\\0',  :g);
  '"' ~ $escaped ~ '"';
}

sub ser-bool(Bool $b --> Str) { $b ?? 'True' !! 'False' }

multi sub ser-val(Bool:D $v --> Str) { ser-bool($v) }
multi sub ser-val(Str:D  $v --> Str) { raku-str($v) }
multi sub ser-val(Int:D  $v --> Str) { $v.Str }
multi sub ser-val(Numeric:D $v --> Str) { $v.Str }
multi sub ser-val(InterpString:D $v --> Str) {
  'InterpString.new(:raw(' ~ raku-str($v.raw)
    ~ '), :line(' ~ $v.line ~ '), :column(' ~ $v.column ~ '))';
}
multi sub ser-val(AttrSplat:D $v --> Str) {
  'AttrSplat.new(:expr(' ~ raku-str($v.expr)
    ~ '), :line(' ~ $v.line ~ '), :column(' ~ $v.column ~ '))';
}
multi sub ser-val(Pair:D $p --> Str) {
  raku-str($p.key) ~ ' => ' ~ ser-val($p.value);
}
multi sub ser-val(Positional:D $list --> Str) {
  '(' ~ $list.list.map({ ser-val($_) }).join(', ') ~ ',).list';
}
multi sub ser-val($v --> Str) {
  return 'Nil' unless $v.defined;
  raku-str($v.Str);
}

sub ser-attrs-list(@attrs --> Str) {
  '(' ~ @attrs.map({ ser-val($_) }).join(', ') ~ ',).list';
}

sub ser-str-list(@items --> Str) {
  '(' ~ @items.map({ raku-str($_.Str) }).join(', ') ~ ',).list';
}

sub ser-tag(Tag:D $t --> Str) {
  my @parts;
  @parts.push: ':name(' ~ raku-str($t.name) ~ ')';
  @parts.push: ':indent(' ~ $t.indent ~ ')';
  @parts.push: ':line(' ~ ($t.line // 0) ~ ')';
  @parts.push: ':column(' ~ ($t.column // 0) ~ ')';
  @parts.push: ':output-indent-width(' ~ $t.output-indent-width ~ ')';
  @parts.push: ':content(' ~ raku-str($t.content // '') ~ ')';
  @parts.push: ':self-close' if $t.self-close;
  @parts.push: ':trim-outer' if $t.trim-outer;
  @parts.push: ':trim-inner' if $t.trim-inner;
  @parts.push: ':attrs(' ~ ser-attrs-list($t.attrs) ~ ')' if $t.attrs.elems;

  my $has-splat = $t.attrs.first({ $_ ~~ AttrSplat }).defined;
  if $has-splat {
    @parts.push: ':classes(' ~ ser-str-list($t.classes) ~ ')' if $t.classes.elems;
    @parts.push: ':ids('     ~ ser-str-list($t.ids)     ~ ')' if $t.ids.elems;
  }
  @parts.push: ':obj-ref-args(' ~ ser-str-list($t.obj-ref-args) ~ ')' if $t.obj-ref-args.elems;
  @parts.push: ':config($cfg)';

  'Tag.new(' ~ @parts.join(', ') ~ ')';
}

sub ser-plain(Plain:D $p --> Str) {
  my @parts =
    ':indent('               ~ $p.indent ~ ')',
    ':line('                 ~ ($p.line   // 0) ~ ')',
    ':column('               ~ ($p.column // 0) ~ ')',
    ':output-indent-width('  ~ $p.output-indent-width ~ ')',
    ':text('                 ~ raku-str($p.text // '') ~ ')';
  'Plain.new(' ~ @parts.join(', ') ~ ')';
}

sub ser-statement(Statement:D $s --> Str) {
  my @parts =
    ':indent('              ~ $s.indent ~ ')',
    ':line('                ~ ($s.line   // 0) ~ ')',
    ':column('              ~ ($s.column // 0) ~ ')',
    ':output-indent-width(' ~ $s.output-indent-width ~ ')',
    ':op('                  ~ raku-str($s.op // '')        ~ ')',
    ':expr('                ~ raku-str($s.expr // '')      ~ ')',
    ':kind('                ~ raku-str($s.kind // 'expression') ~ ')',
    ':loop-var('            ~ raku-str($s.loop-var // '')  ~ ')',
    ':loop-iter('           ~ raku-str($s.loop-iter // '') ~ ')';
  'Statement.new(' ~ @parts.join(', ') ~ ')';
}

sub ser-comment(Comment:D $c --> Str) {
  my @parts;
  @parts.push: ':indent('              ~ $c.indent ~ ')';
  @parts.push: ':line('                ~ ($c.line   // 0) ~ ')';
  @parts.push: ':column('              ~ ($c.column // 0) ~ ')';
  @parts.push: ':output-indent-width(' ~ $c.output-indent-width ~ ')';
  @parts.push: ':text('                ~ raku-str($c.text      // '') ~ ')';
  @parts.push: ':condition('           ~ raku-str($c.condition // '') ~ ')';
  @parts.push: ':silent'   if $c.silent;
  @parts.push: ':revealed' if $c.revealed;
  'Comment.new(' ~ @parts.join(', ') ~ ')';
}

sub ser-doctype(Doctype:D $d --> Str) {
  my @parts =
    ':indent('   ~ $d.indent ~ ')',
    ':line('     ~ ($d.line   // 0) ~ ')',
    ':column('   ~ ($d.column // 0) ~ ')',
    ':arg('      ~ raku-str($d.arg      // '') ~ ')',
    ':encoding(' ~ raku-str($d.encoding // '') ~ ')',
    ':format('   ~ raku-str($d.format) ~ ')',
    ':config($cfg)';
  'Doctype.new(' ~ @parts.join(', ') ~ ')';
}

sub ser-filter(Filter:D $f --> Str) {
  my @parts =
    ':indent('              ~ $f.indent ~ ')',
    ':line('                ~ ($f.line   // 0) ~ ')',
    ':column('              ~ ($f.column // 0) ~ ')',
    ':output-indent-width(' ~ $f.output-indent-width ~ ')',
    ':name('                ~ raku-str($f.name // '') ~ ')',
    ':body('                ~ raku-str($f.body // '') ~ ')';
  'Filter.new(' ~ @parts.join(', ') ~ ')';
}

sub ser-object($obj --> Str) {
  return 'Nil' unless $obj.defined;
  given $obj {
    when Tag       { ser-tag($_) }
    when Plain     { ser-plain($_) }
    when Statement { ser-statement($_) }
    when Comment   { ser-comment($_) }
    when Doctype   { ser-doctype($_) }
    when Filter    { ser-filter($_) }
    default {
      die "Codegen: unsupported node payload {$obj.WHAT.^name}";
    }
  }
}

class Codegen is export {
  has Template::HAML::Config $.config;
  has Int $!sym = 0;

  submethod BUILD(Template::HAML::Config :$config) {
    $!config = $config // Template::HAML::Config.new;
  }

  method !gensym(--> Str) {
    '$n' ~ ++$!sym;
  }

  method !ser-config(--> Str) {
    my $c = $!config;
    my @parts;
    @parts.push: ':format('               ~ raku-str($c.format)       ~ ')';
    @parts.push: ':escape-html('          ~ ser-bool($c.escape-html)  ~ ')';
    @parts.push: ':escape-attrs('         ~ ser-bool($c.escape-attrs) ~ ')';
    @parts.push: ':output-style('         ~ raku-str($c.output-style) ~ ')';
    @parts.push: ':attr-quote('           ~ raku-str($c.attr-quote)   ~ ')';
    @parts.push: ':encoding('             ~ raku-str($c.encoding)     ~ ')';
    @parts.push: ':suppress-eval('        ~ ser-bool($c.suppress-eval)~ ')';
    @parts.push: ':cdata('                ~ ser-bool($c.cdata)        ~ ')';
    @parts.push: ':mime-type('            ~ raku-str($c.mime-type)    ~ ')';
    @parts.push: ':hyphenate-data-attrs(' ~ ser-bool($c.hyphenate-data-attrs) ~ ')';
    @parts.push: ':output-indent-width('  ~ $c.output-indent-width    ~ ')';
    @parts.push: ':autoclose('            ~ ser-str-list($c.autoclose) ~ ')';
    @parts.push: ':preserve('             ~ ser-str-list($c.preserve)  ~ ')';
    'Template::HAML::Config.new(' ~ @parts.join(', ') ~ ')';
  }

  method !walk-children(Node:D $n, Str $parent-var --> List) {
    my @lines;
    for $n.children -> $child {
      my $var      = self!gensym;
      my $obj-expr = ser-object($child.object);
      @lines.push: '  my ' ~ $var ~ ' = Node.new(:object(' ~ $obj-expr ~ '));';
      @lines.push: '  ' ~ $parent-var ~ '.add-child(' ~ $var ~ ');';
      @lines.append: self!walk-children($child, $var);
    }
    @lines.List;
  }

  method emit(Node:D $tree --> Str) {
    $!sym = 0;
    my @lines;
    @lines.push: 'use Template::HAML::Comment;';
    @lines.push: 'use Template::HAML::Config;';
    @lines.push: 'use Template::HAML::Doctype;';
    @lines.push: 'use Template::HAML::Filter;';
    @lines.push: 'use Template::HAML::Interpolation;';
    @lines.push: 'use Template::HAML::Node;';
    @lines.push: 'use Template::HAML::Plain;';
    @lines.push: 'use Template::HAML::Renderer;';
    @lines.push: 'use Template::HAML::Statement;';
    @lines.push: 'use Template::HAML::Tag;';
    @lines.push: '';
    @lines.push: 'sub (%locals = %(), Template::HAML::Config :$config, :$ctx --> Str) {';
    @lines.push: '  my $cfg = $config // ' ~ self!ser-config ~ ';';
    @lines.push: '  my $tree = Node.new;';

    @lines.append: self!walk-children($tree, '$tree');

    @lines.push: '  my $*HAML-CTX = $ctx;';
    @lines.push: '  Renderer.new(:%locals, :config($cfg)).render($tree);';
    @lines.push: '}';

    @lines.join("\n") ~ "\n";
  }
}
