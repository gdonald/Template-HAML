
use Template::HAML::Comment;
use Template::HAML::Config;
use Template::HAML::Doctype;
use Template::HAML::Filter;
use Template::HAML::Interpolation;
use Template::HAML::Node;
use Template::HAML::Plain;
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

sub snippet-for($/) {
  my $orig = $/.orig.Str;
  my $pos  = $/.from;
  my $start = $orig.substr(0, $pos).rindex("\n");
  $start = $start.defined ?? $start + 1 !! 0;
  my $end = $orig.index("\n", $pos);
  $end = $end.defined ?? $end !! $orig.chars;
  $orig.substr($start, $end - $start);
}

sub decode-sq(Str $s --> Str) {
  $s.subst(/'\\' (.)/, -> $/ { $0.Str }, :g);
}

sub blank-line(Str $s --> Bool) {
  so $s ~~ /^ \h* $/;
}

sub leading-ws(Str $s --> Int) {
  $s.chars - $s.subst(/^ \h+/, '').chars;
}

sub dedent-filter-body(@raw) {
  my @lines = @raw;

  while @lines.elems && blank-line(@lines[*-1]) {
    @lines.pop;
  }

  return @lines unless @lines.elems;

  my @widths = @lines.grep({ !blank-line($_) }).map({ leading-ws($_) });
  my $min = @widths ?? @widths.min !! 0;

  @lines.map({ blank-line($_) ?? '' !! .substr($min) }).Array;
}

sub parse-control(Str $op, Str $expr) {
  return %( kind => 'expression', expr => $expr ) unless $op eq '-';

  given $expr {
    when /^ 'if'      \s+ (.+) $ /  { return %( kind => 'if',     expr => ~$0.trim ) }
    when /^ 'unless'  \s+ (.+) $ /  { return %( kind => 'unless', expr => ~$0.trim ) }
    when /^ 'elsif'   \s+ (.+) $ /  { return %( kind => 'elsif',  expr => ~$0.trim ) }
    when /^ 'else' \s* $ /          { return %( kind => 'else',   expr => '' ) }
    when /^ 'while'   \s+ (.+) $ /  { return %( kind => 'while',  expr => ~$0.trim ) }
    when /^ 'repeat'  \s+ (.+) $ /  { return %( kind => 'repeat', expr => ~$0.trim ) }
    when /^ 'given'   \s+ (.+) $ /  { return %( kind => 'given',  expr => ~$0.trim ) }
    when /^ 'when'    \s+ (.+) $ /  { return %( kind => 'when',   expr => ~$0.trim ) }
    when /^ 'default' \s* $ /       { return %( kind => 'default', expr => '' ) }
    when /^ 'for' \s+ '$' (\w+) \s+ 'in' \s+ (.+) $ / {
      return %( kind => 'for', expr => '', loop-var => ~$0, loop-iter => ~$1.trim );
    }
    when /^ 'for' \s+ (.+) \s+ '->' \s+ '$' (\w+) \s* $ / {
      return %( kind => 'for', expr => '', loop-iter => ~$0.trim, loop-var => ~$1 );
    }
  }

  %( kind => 'expression', expr => $expr );
}

sub decode-dq(Str $s --> Str) {
  $s.subst(/'\\' (.)/, -> $/ {
    given $0.Str {
      when 'n'  { "\n" }
      when 't'  { "\t" }
      when 'r'  { "\r" }
      when '\\' { '\\' }
      when '"'  { '"' }
      when "'"  { "'" }
      default   { '\\' ~ $0.Str }
    }
  }, :g);
}

class Actions is export {
  has Node $.tree;
  has Node $!current-node;

  has Str $!indent-leader;
  has Int $!indent-unit;

  has Template::HAML::Config $.config;
  has Int $.output-indent-width;
  has Str $.format;

  has Bool $!seen-content = False;

  submethod BUILD(Node:D :$!tree, Template::HAML::Config :$config) {
    $!config = $config // Template::HAML::Config.new;
    $!output-indent-width = $!config.output-indent-width;
    $!format              = $!config.format;
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

    my @attrs;
    if $/<html-attrs>.defined {
      @attrs.append: $/<html-attrs>.made.list;
    }
    if $/<params-hash>.defined {
      @attrs.append: $/<params-hash>.made.list;
    }

    my $content = $/<to-eol>.defined ?? $/<to-eol>.Str.trim !! '';

    my $trim    = $/<trim-modifiers>.Str;
    my $trim-outer = $trim.contains('>');
    my $trim-inner = $trim.contains('<');
    my $self-close = $/<void-marker>.defined && $/<void-marker>.Str eq '/';

    my $object = Tag.new(
      :$indent, :$name, :@attrs, :$content,
      :@classes, :@ids,
      :$self-close, :$trim-outer, :$trim-inner,
      :$line, :$column,
      :output-indent-width($!output-indent-width),
      :config($!config),
    );
    self.add-node($object);
    $!seen-content = True;
  }

  method statement($/) {
    my ($line, $column) = pos-to-line-col($/);
    my $indent = self.compute-level($/<indent>);
    my $op     = $/<output-op>.Str;
    my $expr   = $/<expr>.Str.trim;

    my %ctrl = parse-control($op, $expr);

    my $object = Statement.new(
      :$indent, :$op, :$line, :$column,
      expr      => %ctrl<expr>,
      kind      => %ctrl<kind>,
      loop-var  => %ctrl<loop-var>  // '',
      loop-iter => %ctrl<loop-iter> // '',
      :output-indent-width($!output-indent-width),
    );
    self.add-node($object);
    $!seen-content = True;
  }

  method line:sym<comment>($/) {
    my ($line, $column) = pos-to-line-col($/);
    my $indent = self.compute-level($/<head>);

    my $condition = $/<comment-condition>.defined
      ?? $/<comment-condition><cond>.Str.trim
      !! '';
    my $revealed = $/<comment-revealed>.defined;
    my $text = $/<to-eol>.Str.trim;

    my $object = Comment.new(
      :$indent, :$line, :$column,
      :$text, :$condition, :$revealed,
      :output-indent-width($!output-indent-width),
    );
    self.add-node($object);
    $!seen-content = True;
  }

  method line:sym<silent-comment>($/) {
    my ($line, $column) = pos-to-line-col($/);
    my $indent = self.compute-level($/<head>);

    my $object = Comment.new(
      :$indent, :$line, :$column, :silent,
      :output-indent-width($!output-indent-width),
    );
    self.add-node($object);
    $!seen-content = True;
  }

  method line:sym<plain>($/) {
    my ($line, $column) = pos-to-line-col($/);
    my $indent = self.compute-level($/<head>);
    my $raw    = $/<plain-text>.Str;

    $raw .= subst(/\h+ $/, '');
    $raw .= subst(/^ '\\'/, '') if $raw.starts-with('\\');

    my $object = Plain.new(
      :$indent, :$line, :$column,
      :text($raw),
      :output-indent-width($!output-indent-width),
    );
    self.add-node($object);
    $!seen-content = True;
  }

  method line:sym<filter>($/) {
    my ($line, $column) = pos-to-line-col($/);
    my $indent = self.compute-level($/<head>);
    my $name   = $/<word>.Str;

    my @raw;
    if $/<body-line> {
      for $/<body-line>.list -> $bl {
        my $s = $bl.Str;
        $s = $s.substr(0, $s.chars - 1) if $s.ends-with("\n");
        @raw.push: $s;
      }
    }

    @raw = dedent-filter-body(@raw);

    my $body = @raw.join("\n");

    my $object = Filter.new(
      :$indent, :$name, :$body, :$line, :$column,
      :output-indent-width($!output-indent-width),
    );
    self.add-node($object);
    $!seen-content = True;
  }

  method line:sym<doctype>($/) {
    my ($line, $column) = pos-to-line-col($/);
    if $!seen-content {
      X::HAML::DoctypeNotFirst.new(:$line, :$column, :snippet(snippet-for($/))).throw;
    }

    my $rest = $/<to-eol>.Str.trim;
    my ($arg, $encoding) = '', '';
    if $rest.chars {
      my @parts = $rest.words;
      $arg = @parts[0] // '';
      $encoding = @parts[1] // '';
    }

    my $object = Doctype.new(
      :indent(0), :$line, :$column,
      :$arg, :$encoding, :$!format,
      :config($!config),
    );
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
    my $snippet = snippet-for($indent-match);

    if $ws.contains("\t") && $ws.contains(' ') {
      indent-mixed(:$line, :$column, :$snippet);
    }

    my $leader = $ws.substr(0, 1);
    unless $!indent-leader.defined {
      $!indent-leader = $leader;
      $!indent-unit   = $ws.chars;
    }

    if $leader ne $!indent-leader {
      indent-mixed(:$line, :$column, :$snippet);
    }

    if $ws.chars % $!indent-unit != 0 {
      indent-inconsistent(:$line, :$column, :unit($!indent-unit), :got($ws.chars), :$snippet);
    }

    $ws.chars div $!indent-unit;
  }

  method indent($/) {
    make $/.Str.chars;
  }

  method sq-content($/) { make decode-sq($/.Str) }
  method dq-content($/) {
    my $raw = $/.Str;
    if has-interp($raw) {
      my ($line, $column) = pos-to-line-col($/);
      make Template::HAML::Interpolation::InterpString.new(
        :$raw, :$line, :$column,
      );
    } else {
      make decode-dq($raw);
    }
  }

  method single-quoted-string($/) { make $/<sq-content>.made }
  method double-quoted-string($/) { make $/<dq-content>.made }

  method quoted-string($/) {
    if $/<single-quoted-string> {
      make $/<single-quoted-string>.made;
    } else {
      make $/<double-quoted-string>.made;
    }
  }

  method bool($/) {
    given $/.Str {
      when 'True'  | 'true'  { make True  }
      when 'False' | 'false' { make False }
      when 'Nil'             { make Nil   }
    }
  }

  method number($/) {
    make $/.Str.Numeric;
  }

  method symbol($/) {
    make $/<word>.Str;
  }

  method array-value($/) {
    make $/<value>.map({ .made }).list;
  }

  method hash-value($/) {
    make ($/<pair> // ()).list.map({ .made }).list;
  }

  method value($/) {
    for <quoted-string number bool symbol hash-value array-value> -> $k {
      if $/{$k}.defined {
        make $/{$k}.made;
        return;
      }
    }
  }

  method rocket-key($/) {
    if $/<quoted-string>.defined {
      make $/<quoted-string>.made;
    } elsif $/<symbol>.defined {
      make $/<symbol>.made;
    } else {
      make $/<word>.Str;
    }
  }

  method pair-bare($/)   { make Pair.new($/<word>.Str,        $/<value>.made) }
  method pair-rocket($/) { make Pair.new($/<rocket-key>.made, $/<value>.made) }

  method pair($/) {
    if $/<pair-rocket>.defined {
      make $/<pair-rocket>.made;
    } else {
      make $/<pair-bare>.made;
    }
  }

  method param-value($/) { make $/<value>.made }
  method param-key($/)   { make $/<word>.Str }
  method param($/)       { make $/<pair-bare>.made }

  method params($/) {
    my %h;
    for ($/<pair> // ()).list -> $p {
      %h{$p.made.key} = $p.made.value;
    }
    make %h;
  }

  method params-hash($/) {
    make ($/<pair> // ()).list.map({ .made }).list;
  }

  method html-bool-attr($/) {
    make Pair.new($/<hyphen-name>.Str, True);
  }

  method html-keyed-attr($/) {
    make Pair.new($/<hyphen-name>.Str, $/<quoted-string>.made);
  }

  method html-attr($/) {
    if $/<html-keyed-attr>.defined {
      make $/<html-keyed-attr>.made;
    } else {
      make $/<html-bool-attr>.made;
    }
  }

  method html-attrs($/) {
    make $/<html-attr>.map({ .made }).list;
  }

  method css-class($/)   { make $/.Str.subst(/\./, '').trim }
  method css-classes($/) { make $/<css-class>.map({ .made }) }
}
