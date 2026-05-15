
use Template::HAML;
use Template::HAML::Config;
use Template::HAML::Format;
use Template::HAML::X;

unit module Template::HAML::CLI;

constant HELP-TEXT = q:to/END/;
Usage: haml <command> [options] <file>...

Commands:
  render <file>...   Render HAML file(s) to HTML
  check  <file>...   Parse-only; exit non-zero on parse failure
  fmt    <file>...   Pretty-print HAML in canonical form
  help [<command>]   Show help (also --help, -h)

Run 'haml render --help', 'haml check --help', or 'haml fmt --help'
for command-specific options.
END

constant RENDER-HELP = q:to/END/;
Usage: haml render [options] <file>...

Options:
  -o <path>             Write output to file instead of stdout
  --locals k=v,k2=v2    Pass template locals (comma-separated key=value)
  --format <fmt>        html5 (default), html4, or xhtml
  --escape-html         Enable HTML escaping (default)
  --no-escape-html      Disable HTML escaping
  --ugly                Shortcut for --output-style ugly
  --help, -h            Show this help

Examples:
  haml render view.haml
  haml render view.haml -o out.html
  haml render view.haml --locals name=Alice,age=30
  haml render --format xhtml --ugly view.haml
END

constant CHECK-HELP = q:to/END/;
Usage: haml check [options] <file>...

Parses each HAML file and exits non-zero on the first parse failure.

Options:
  --help, -h   Show this help

Examples:
  haml check view.haml
  haml check views/*.haml
END

constant FMT-HELP = q:to/END/;
Usage: haml fmt [options] <file>...

Pretty-prints each HAML file in canonical form. By default the
result is written to standard out; pass --in-place to rewrite the
file on disk.

Options:
  -o <path>     Write output to file instead of stdout (single file only)
  --in-place    Rewrite each file with its canonical form
  --check       Exit non-zero if any file differs from its canonical form;
                emit no output. Suitable for CI use.
  --help, -h    Show this help

Examples:
  haml fmt view.haml
  haml fmt view.haml -o canonical.haml
  haml fmt --in-place views/*.haml
  haml fmt --check views/*.haml
END

sub parse-locals(Str $s --> Hash) {
  my %h;
  return %h unless $s.defined && $s.chars;
  for $s.split(',') -> $pair {
    next unless $pair.chars;
    my ($k, $v) = $pair.split('=', 2);
    %h{$k.trim} = ($v // '').defined ?? $v !! '';
  }
  %h;
}

sub parse-render-args(@input --> Hash) {
  my @args = @input;
  my %opts;
  my @positional;
  while @args.elems {
    my $a = @args.shift;
    given $a {
      when '-o' {
        die "haml render: -o requires a path\n" unless @args.elems;
        %opts<output> = @args.shift;
      }
      when '--locals' {
        die "haml render: --locals requires an argument\n" unless @args.elems;
        %opts<locals> = parse-locals(@args.shift);
      }
      when '--format' {
        die "haml render: --format requires an argument\n" unless @args.elems;
        %opts<format> = @args.shift;
      }
      when '--escape-html'    { %opts<escape-html>  = True;  }
      when '--no-escape-html' { %opts<escape-html>  = False; }
      when '--ugly'           { %opts<output-style> = 'ugly'; }
      when '--help' | '-h'    { %opts<help> = True; }
      when /^ '--' / | /^ '-' \w / {
        die "haml render: unknown option '$a'\n";
      }
      default { @positional.push($a); }
    }
  }
  { :%opts, :@positional };
}

sub parse-fmt-args(@input --> Hash) {
  my @args = @input;
  my %opts;
  my @positional;
  while @args.elems {
    my $a = @args.shift;
    given $a {
      when '-o' {
        die "haml fmt: -o requires a path\n" unless @args.elems;
        %opts<output> = @args.shift;
      }
      when '--in-place'    { %opts<in-place> = True; }
      when '--check'       { %opts<check>    = True; }
      when '--help' | '-h' { %opts<help>     = True; }
      when /^ '--' / | /^ '-' \w / {
        die "haml fmt: unknown option '$a'\n";
      }
      default { @positional.push($a); }
    }
  }
  { :%opts, :@positional };
}

sub parse-check-args(@input --> Hash) {
  my @args = @input;
  my %opts;
  my @positional;
  while @args.elems {
    my $a = @args.shift;
    given $a {
      when '--help' | '-h' { %opts<help> = True; }
      when /^ '--' / | /^ '-' \w / {
        die "haml check: unknown option '$a'\n";
      }
      default { @positional.push($a); }
    }
  }
  { :%opts, :@positional };
}

sub build-config(%opts --> Template::HAML::Config) {
  my %cfg-args;
  %cfg-args<format>       = %opts<format>       if %opts<format>.defined;
  %cfg-args<escape-html>  = %opts<escape-html>  if %opts<escape-html>.defined;
  %cfg-args<output-style> = %opts<output-style> if %opts<output-style>.defined;
  Template::HAML::Config.new(|%cfg-args);
}

our sub cmd-render(@args, IO::Handle :$out, IO::Handle :$err --> Int) is export {
  my $parsed;
  {
    CATCH {
      default {
        $err.print(.message);
        return 2;
      }
    }
    $parsed = parse-render-args(@args);
  }

  if $parsed<opts><help> {
    $out.print(RENDER-HELP);
    return 0;
  }

  unless $parsed<positional>.elems {
    $err.print("haml render: missing file argument\n");
    $err.print(RENDER-HELP);
    return 2;
  }

  my $config       = build-config($parsed<opts>);
  my %locals       = $parsed<opts><locals> // %();
  my $output-path  = $parsed<opts><output>;

  my @rendered;
  for $parsed<positional>.list -> $file {
    unless $file.IO.e {
      $err.print("haml render: file not found: $file\n");
      return 1;
    }
    my $result;
    {
      CATCH {
        when X::HAML {
          $err.print("haml render: $file: " ~ .message ~ "\n");
          return 1;
        }
        default {
          $err.print("haml render: $file: " ~ .message ~ "\n");
          return 1;
        }
      }
      my $haml = HAML.new(:$config);
      my $src  = $file.IO.slurp(:bin);
      $result = $haml.render(:$src, :%locals);
    }
    @rendered.push($result);
  }

  my $joined = @rendered.join('');
  if $output-path.defined {
    $output-path.IO.spurt($joined);
  } else {
    $out.print($joined);
  }
  0;
}

our sub cmd-check(@args, IO::Handle :$out, IO::Handle :$err --> Int) is export {
  my $parsed;
  {
    CATCH {
      default {
        $err.print(.message);
        return 2;
      }
    }
    $parsed = parse-check-args(@args);
  }

  if $parsed<opts><help> {
    $out.print(CHECK-HELP);
    return 0;
  }

  unless $parsed<positional>.elems {
    $err.print("haml check: missing file argument\n");
    $err.print(CHECK-HELP);
    return 2;
  }

  my $exit = 0;
  for $parsed<positional>.list -> $file {
    unless $file.IO.e {
      $err.print("haml check: file not found: $file\n");
      $exit = 1;
      next;
    }
    {
      CATCH {
        when X::HAML {
          $err.print("haml check: $file: " ~ .message ~ "\n");
          $exit = 1;
        }
        default {
          $err.print("haml check: $file: " ~ .message ~ "\n");
          $exit = 1;
        }
      }
      my $haml = HAML.new;
      $haml.compile-file($file);
      $out.print("$file: OK\n");
    }
  }
  $exit;
}

our sub cmd-fmt(@args, IO::Handle :$out, IO::Handle :$err --> Int) is export {
  my $parsed;
  {
    CATCH {
      default {
        $err.print(.message);
        return 2;
      }
    }
    $parsed = parse-fmt-args(@args);
  }

  if $parsed<opts><help> {
    $out.print(FMT-HELP);
    return 0;
  }

  unless $parsed<positional>.elems {
    $err.print("haml fmt: missing file argument\n");
    $err.print(FMT-HELP);
    return 2;
  }

  my $in-place = ?$parsed<opts><in-place>;
  my $check    = ?$parsed<opts><check>;
  my $output   = $parsed<opts><output>;

  if $in-place && $output.defined {
    $err.print("haml fmt: --in-place and -o are mutually exclusive\n");
    return 2;
  }
  if $check && ($in-place || $output.defined) {
    $err.print("haml fmt: --check cannot be combined with --in-place or -o\n");
    return 2;
  }
  if $output.defined && $parsed<positional>.elems > 1 {
    $err.print("haml fmt: -o accepts only a single input file\n");
    return 2;
  }

  my $exit = 0;
  my @rendered;
  for $parsed<positional>.list -> $file {
    unless $file.IO.e {
      $err.print("haml fmt: file not found: $file\n");
      return 1;
    }
    my $formatted;
    {
      CATCH {
        when X::HAML {
          $err.print("haml fmt: $file: " ~ .message ~ "\n");
          return 1;
        }
        default {
          $err.print("haml fmt: $file: " ~ .message ~ "\n");
          return 1;
        }
      }
      my $src = $file.IO.slurp;
      $formatted = format-source($src);
    }

    if $check {
      my $orig = $file.IO.slurp;
      if $orig ne $formatted {
        $err.print("haml fmt: $file: not in canonical form\n");
        $exit = 1;
      }
    } elsif $in-place {
      $file.IO.spurt($formatted);
    } else {
      @rendered.push($formatted);
    }
  }

  unless $check || $in-place {
    my $joined = @rendered.join('');
    if $output.defined {
      $output.IO.spurt($joined);
    } else {
      $out.print($joined);
    }
  }

  $exit;
}

our sub run(@args, IO::Handle :$out = $*OUT, IO::Handle :$err = $*ERR --> Int) is export {
  my @a = @args;
  if !@a.elems {
    $err.print(HELP-TEXT);
    return 2;
  }
  my $cmd = @a.shift;
  given $cmd {
    when 'render'                 { return cmd-render(@a, :$out, :$err); }
    when 'check'                  { return cmd-check(@a, :$out, :$err); }
    when 'fmt'                    { return cmd-fmt(@a,   :$out, :$err); }
    when 'help' | '--help' | '-h' {
      if @a.elems {
        given @a[0] {
          when 'render' { $out.print(RENDER-HELP); return 0; }
          when 'check'  { $out.print(CHECK-HELP);  return 0; }
          when 'fmt'    { $out.print(FMT-HELP);    return 0; }
          default {
            $err.print("haml help: unknown command '{ @a[0] }'\n");
            $err.print(HELP-TEXT);
            return 2;
          }
        }
      }
      $out.print(HELP-TEXT);
      return 0;
    }
    default {
      $err.print("haml: unknown command '$cmd'\n");
      $err.print(HELP-TEXT);
      return 2;
    }
  }
}
