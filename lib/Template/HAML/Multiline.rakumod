
use Template::HAML::X;

unit module Template::HAML::Multiline;

sub leading-ws-count(Str $s --> Int) {
  my $m = $s ~~ /^ \h+/;
  $m ?? $m.Str.chars !! 0;
}

sub blank-line(Str $s --> Bool) {
  so $s ~~ /^ \h* $/;
}

sub opaque-block-head-indent(Str $line --> Int) {
  if $line ~~ /^ (\h*) ':' \w/ {
    return $0.Str.chars;
  }
  if $line ~~ /^ (\h*) '-#' / {
    return $0.Str.chars;
  }
  -1;
}

sub line-starts-statement(Str $line --> Bool) {
  return False if $line ~~ /^ \h* '-#' /;
  return False if $line ~~ /^ \h* '==' /;
  so $line ~~ /^ \h* ['!=' | '&=' | '-' | '=' | '~'] /;
}

our sub code-state(Str $code) is export {
  my $bracket-depth   = 0;
  my $in-string       = '';
  my $escape          = False;
  my $last-non-ws     = '';

  for $code.comb -> $c {
    if $in-string {
      if $escape {
        $escape = False;
      } elsif $c eq '\\' {
        $escape = True;
      } elsif $c eq $in-string {
        $in-string = '';
      }
      $last-non-ws = $c unless $c eq ' ' || $c eq "\t";
      next;
    }
    if $c eq "'" || $c eq '"' {
      $in-string = $c;
    } elsif $c eq '(' || $c eq '[' || $c eq '{' {
      $bracket-depth++;
    } elsif $c eq ')' || $c eq ']' || $c eq '}' {
      $bracket-depth--;
    }
    $last-non-ws = $c unless $c eq ' ' || $c eq "\t";
  }

  %(
    bracket-depth   => $bracket-depth,
    ends-with-comma => $last-non-ws eq ',',
    in-string       => $in-string,
  );
}

sub continuation-needed(Str $code --> Bool) {
  my %state = code-state($code);
  return True if %state<bracket-depth> > 0;
  return True if %state<ends-with-comma>;
  return True if %state<in-string>;
  False;
}

sub preprocess-multiline(Str $src --> Str) is export {
  my @lines = $src.split("\n");
  my @out;
  my $i = 0;

  while $i < @lines.elems {
    my $line = @lines[$i];

    my $opaque = opaque-block-head-indent($line);
    if $opaque >= 0 {
      @out.push: $line;
      $i++;
      while $i < @lines.elems {
        my $body = @lines[$i];
        last unless blank-line($body) || leading-ws-count($body) > $opaque;
        @out.push: $body;
        $i++;
      }
      next;
    }

    if line-starts-statement($line) {
      my $start-line = $i + 1;
      my $joined     = $line;
      my $consumed   = 0;

      while continuation-needed($joined) {
        if $i + 1 + $consumed >= @lines.elems {
          X::HAML::UnbalancedExpression.new(
            :line($start-line), :column(1), :code($joined),
          ).throw;
        }
        my $next = @lines[$i + 1 + $consumed];
        $consumed++;
        $joined ~= ' ' ~ $next.subst(/^\h+/, '');
      }

      @out.push: $joined;
      @out.push: '' for ^$consumed;
      $i += 1 + $consumed;
      next;
    }

    @out.push: $line;
    $i++;
  }

  @out.join("\n");
}
