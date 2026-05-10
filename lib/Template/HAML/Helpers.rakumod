
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

sub html-safe(Str() $s --> SafeString) is export {
  SafeString.new($s);
}

sub current-ctx() {
  try { $*HAML-CTX } // Nil;
}

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

sub content-for(Str() $name, &block --> Str) is export {
  my $ctx = current-ctx();
  return '' unless $ctx.defined;
  my $body = block-result(&block);
  $ctx.set-content($name, $body);
  '';
}

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

sub surround(Str() $pre, Str() $post, &block --> Str) is export {
  $pre ~ strip-ws(block-result(&block)) ~ $post;
}

sub precede(Str() $pre, &block --> Str) is export {
  $pre ~ strip-ws(block-result(&block));
}

sub succeed(Str() $post, &block --> Str) is export {
  strip-ws(block-result(&block)) ~ $post;
}

sub list-of($items, &block --> Str) is export {
  my @rendered;
  for $items.list -> $item {
    my $body = block($item);
    my $str  = $body.defined ?? $body.Str !! '';
    @rendered.push: '<li>' ~ strip-ws($str) ~ '</li>';
  }
  @rendered.join("\n");
}

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

sub capture-haml(&block --> Str) is export {
  my $template = block-result(&block);
  require ::('Template::HAML');
  ::('HAML').render(:src($template));
}
