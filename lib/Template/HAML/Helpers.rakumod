
use Template::HAML::X;

unit module Template::HAML::Helpers;

class SafeString is export {
  has Str $.value;

  method new(Str() $value) {
    self.bless(:$value);
  }

  method Str(--> Str)  { $!value }
  method gist(--> Str) { $!value }
}

#| Mark a string as already-safe so it bypasses default escaping.
sub html-safe(Str() $s --> SafeString) is export {
  SafeString.new($s);
}

#| Append a string to the current capture buffer (inside C<capture-haml>).
sub haml-concat(Str() $s --> SafeString) is export {
  my $buf = try { @*HAML-CONCAT };
  if $buf.defined {
    $buf.push: $s;
    SafeString.new('');
  } else {
    SafeString.new($s);
  }
}

#| Increase the renderer's output indent by C<$n> levels.
sub tab-up(Int $n = 1) is export {
  if (try { $*HAML-TAB-OFFSET }).defined {
    $*HAML-TAB-OFFSET = $*HAML-TAB-OFFSET + $n;
  }
}

#| Decrease the renderer's output indent by C<$n> levels.
sub tab-down(Int $n = 1) is export {
  if (try { $*HAML-TAB-OFFSET }).defined {
    $*HAML-TAB-OFFSET = $*HAML-TAB-OFFSET - $n;
  }
}

sub current-ctx() {
  try { $*HAML-CTX } // Nil;
}

#| Inside a layout, emit the rendered inner template (default) or a
#| named C<content-for> block.
our sub yield(Str :$name = 'default' --> SafeString) is export {
  my $ctx = current-ctx();
  unless $ctx.defined {
    X::HAML::YieldOutsideLayout.new(:line(0), :column(0)).throw;
  }
  if $name eq 'default' {
    SafeString.new($ctx.yield-content // '');
  } else {
    SafeString.new($ctx.get-content($name));
  }
}

#| Capture block output and store it under C<$name> for later C<yield>.
sub content-for(Str() $name, &block --> Str) is export {
  my $ctx = current-ctx();
  return '' unless $ctx.defined;
  my $body = block-result(&block);
  $ctx.set-content($name, $body);
  '';
}

#| Render a partial template by name with optional locals or a collection.
sub render(:$partial, :%locals, :$collection, Str :$as --> SafeString) is export {
  my $ctx = current-ctx();
  die "render() requires :partial" unless $partial.defined;
  die "render() requires a HAML context" unless $ctx.defined && $ctx.haml.defined;

  my $haml = $ctx.haml;
  my $path = $haml.resolve-template($partial.Str);

  if $ctx.partial-depth >= $ctx.partial-depth-limit {
    X::HAML::PartialDepthExceeded.new(
      :line(0), :column(0),
      :name($partial.Str), :limit($ctx.partial-depth-limit),
    ).throw;
  }

  $ctx.partial-depth = $ctx.partial-depth + 1;
  my $prev-dir = $ctx.current-dir;
  $ctx.current-dir = $path.IO.dirname;

  my $out = '';
  if $collection.defined {
    my $var = $as // 'item';
    for $collection.list -> $item {
      my %sub = %locals.clone;
      %sub{$var} = $item;
      $out ~= $haml.render-compiled-file($path, %sub);
    }
  } else {
    $out = $haml.render-compiled-file($path, %locals);
  }

  $ctx.partial-depth = $ctx.partial-depth - 1;
  $ctx.current-dir   = $prev-dir;

  SafeString.new($out);
}

sub html-escape(Str $s --> Str) {
  $s.subst('&', '&amp;', :g)
    .subst('<', '&lt;',  :g)
    .subst('>', '&gt;',  :g)
    .subst('"', '&quot;', :g)
    .subst("'", '&#39;', :g);
}

#| HTML-escape C<$s>, skipping characters that are already part of an entity.
sub escape-once(Str() $s --> Str) is export {
  my $out = '';
  my $i   = 0;
  while $i < $s.chars {
    my $ch = $s.substr($i, 1);
    if $ch eq '&' {
      my $rest = $s.substr($i);
      if $rest ~~ / ^ ( '&' [ '#' \d+ | '#x' <[0..9 a..f A..F]>+ | <[a..zA..Z]>+ ] ';' ) / {
        $out ~= ~$0;
        $i   += $0.chars;
        next;
      }
      $out ~= '&amp;';
    }
    elsif $ch eq '<' { $out ~= '&lt;'; }
    elsif $ch eq '>' { $out ~= '&gt;'; }
    elsif $ch eq '"' { $out ~= '&quot;'; }
    elsif $ch eq "'" { $out ~= '&#39;'; }
    else             { $out ~= $ch; }
    $i++;
  }
  $out;
}

sub block-result(&block --> Str) {
  my $result = block();
  $result.defined ?? $result.Str !! '';
}

sub strip-ws(Str $s --> Str) {
  $s.subst(/^ \s+/, '').subst(/\s+ $/, '');
}

#| Render C<$pre>, then the trimmed block output, then C<$post>.
sub surround(Str() $pre, Str() $post, &block --> Str) is export {
  $pre ~ strip-ws(block-result(&block)) ~ $post;
}

#| Render C<$pre> immediately before the trimmed block output.
sub precede(Str() $pre, &block --> Str) is export {
  $pre ~ strip-ws(block-result(&block));
}

#| Render the trimmed block output immediately followed by C<$post>.
sub succeed(Str() $post, &block --> Str) is export {
  strip-ws(block-result(&block)) ~ $post;
}

#| Emit a C<< <li>...</li> >> for each item, calling C<&block> per item.
sub list-of($items, &block --> Str) is export {
  my @rendered;
  for $items.list -> $item {
    my $body = block($item);
    my $str  = $body.defined ?? $body.Str !! '';
    @rendered.push: '<li>' ~ strip-ws($str) ~ '</li>';
  }
  @rendered.join("\n");
}

#| Convert newlines to C<&#x000A;> inside any C<< <pre> >>/C<< <textarea> >> in C<$html>.
sub find-and-preserve(Str() $html --> Str) is export {
  my $out = $html;
  for <pre textarea> -> $tag {
    $out = $out.subst(
      / '<' $tag (<-[>]>*) '>' (.*?) '</' $tag '>' /,
      -> $m {
        '<' ~ $tag ~ ~$m[0] ~ '>'
          ~ ~$m[1].subst("\n", '&#x000A;', :g)
          ~ '</' ~ $tag ~ '>';
      },
      :g,
    );
  }
  $out;
}

#| Render a block that returns HAML source and return the resulting HTML.
sub capture-haml(&block --> Str) is export {
  my $template = block-result(&block);
  require ::('Template::HAML');
  ::('HAML').render(:src($template));
}

=begin pod

=head1 NAME

Template::HAML::Helpers - helper subs available to embedded code

=head1 SYNOPSIS

=begin code :lang<raku>
use Template::HAML::Helpers;

surround '<b>', '</b>', { 'hi' };  # <b>hi</b>
list-of(<a b c>, -> $x { $x.uc });
=end code

=head1 EXPORTED SUBS

C<html-safe>, C<haml-concat>, C<tab-up>, C<tab-down>, C<yield>,
C<content-for>, C<render>, C<escape-once>, C<surround>, C<precede>,
C<succeed>, C<list-of>, C<find-and-preserve>, C<capture-haml>.

C<yield> and C<render> require an active C<HAML> rendering context;
calling them outside one raises C<X::HAML::YieldOutsideLayout> or a
plain die respectively.

=end pod
