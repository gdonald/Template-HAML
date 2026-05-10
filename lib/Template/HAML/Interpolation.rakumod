
use Template::HAML::Eval;

unit module Template::HAML::Interpolation;

sub html-escape(Str $s --> Str) {
  $s.subst('&', '&amp;', :g)
    .subst('<', '&lt;',  :g)
    .subst('>', '&gt;',  :g)
    .subst('"', '&quot;', :g)
    .subst("'", '&#39;', :g);
}

sub find-balanced(Str $s, Int $start --> Int) {
  my $depth = 1;
  my $i = $start;
  while $i < $s.chars {
    my $c = $s.substr($i, 1);
    if    $c eq '{' { $depth++ }
    elsif $c eq '}' {
      $depth--;
      return $i if $depth == 0;
    }
    elsif $c eq '"' || $c eq "'" {
      my $quote = $c;
      $i++;
      while $i < $s.chars {
        my $cc = $s.substr($i, 1);
        last if $cc eq $quote;
        $i++ if $cc eq '\\' && $i + 1 < $s.chars;
        $i++;
      }
    }
    $i++;
  }
  -1;
}

sub decode-string-escape(Str $next --> Str) {
  given $next {
    when 'n'  { "\n" }
    when 't'  { "\t" }
    when 'r'  { "\r" }
    when '\\' { '\\' }
    when '"'  { '"' }
    when "'"  { "'" }
    default   { '\\' ~ $next }
  }
}

sub interpolate(
  Str  $text, %locals,
  Int  :$line   = 0,
  Int  :$column = 0,
  Bool :$escape = True,
  Bool :$string-escapes = False,
  --> Str
) is export {
  my $out = '';
  my $i   = 0;
  my $len = $text.chars;

  while $i < $len {
    my $c = $text.substr($i, 1);

    if $c eq '\\' && $i + 1 < $len {
      my $next = $text.substr($i + 1, 1);
      if ($next eq '#' || $next eq '!') && $i + 2 < $len && $text.substr($i + 2, 1) eq '{' {
        my $end = find-balanced($text, $i + 3);
        if $end >= 0 {
          $out ~= "$next\{" ~ $text.substr($i + 3, $end - ($i + 3)) ~ '}';
          $i = $end + 1;
        } else {
          $out ~= "$next\{";
          $i += 3;
        }
        next;
      }

      if $string-escapes {
        $out ~= decode-string-escape($next);
        $i += 2;
        next;
      }

      $out ~= $c;
      $i++;
      next;
    }

    if ($c eq '#' || $c eq '!') && $i + 1 < $len && $text.substr($i + 1, 1) eq '{' {
      my $end = find-balanced($text, $i + 2);
      if $end < 0 {
        $out ~= $c;
        $i++;
        next;
      }
      my $code = $text.substr($i + 2, $end - ($i + 2));
      my $val  = eval-haml($code, %locals, :$line, :$column);
      my $str  = $val.defined ?? $val.Str !! '';
      if $c eq '#' && $escape {
        $str = html-escape($str);
      }
      $out ~= $str;
      $i = $end + 1;
      next;
    }

    $out ~= $c;
    $i++;
  }

  $out;
}

sub has-interp(Str $text --> Bool) is export {
  return False unless $text.defined;
  my $i = 0;
  my $len = $text.chars;
  while $i < $len {
    my $c = $text.substr($i, 1);
    if $c eq '\\' && $i + 1 < $len {
      my $next = $text.substr($i + 1, 1);
      if ($next eq '#' || $next eq '!')
         && $i + 2 < $len
         && $text.substr($i + 2, 1) eq '{' {
        return True;
      }
      $i += 2;
      next;
    }
    if ($c eq '#' || $c eq '!') && $i + 1 < $len && $text.substr($i + 1, 1) eq '{' {
      return True;
    }
    $i++;
  }
  False;
}

class InterpString is export {
  has Str $.raw;
  has Int $.line   = 0;
  has Int $.column = 0;

  submethod BUILD(Str :$!raw, Int :$!line = 0, Int :$!column = 0) {}

  method resolve(%locals, Bool :$escape = True --> Str) {
    interpolate(
      $!raw, %locals,
      :line($!line), :column($!column),
      :$escape, :string-escapes,
    );
  }
}
