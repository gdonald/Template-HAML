
use Template::HAML;
use Template::HAML::Config;
use Template::HAML::Format;
use Template::HAML::Lint;
use Template::HAML::Watch;
use Template::HAML::X;

unit module Template::HAML::CLI;

constant HELP-TEXT = q:to/END/;
Usage: haml <command> [options] <file>...

Commands:
  render <file>...   Render HAML file(s) to HTML
  check  <file>...   Parse-only; exit non-zero on parse failure
  fmt    <file>...   Pretty-print HAML in canonical form
  lint   <file>...   Static analysis; non-zero exit on diagnostics
  help [<command>]   Show help (also --help, -h)

Run 'haml <command> --help' for command-specific options.
END

constant RENDER-HELP = q:to/END/;
Usage: haml render [options] <file>...

A file argument of '-' reads HAML source from standard input.

File arguments may also be globs (e.g. 'views/*.haml'); when more than
one file matches, --out-dir is required so each output goes to its own
file.

Options:
  -o <path>             Write output to file instead of stdout
  --out-dir <dir>       Write each input to <dir>/<basename>.html
  --watch               Re-render on change. Requires -o or --out-dir.
  --poll <ms>           Use polling (interval in ms) instead of
                        filesystem notifications when --watch is set.
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
  haml render 'views/*.haml' --out-dir build/
  haml render 'views/*.haml' --out-dir build/ --watch
  echo '%p hi' | haml render -
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

constant LINT-HELP = q:to/END/;
Usage: haml lint [options] <file>...

Runs registered lint rules against each HAML file and reports
diagnostics. A file argument of '-' reads HAML source from standard
input.

Exit codes:
  0   No diagnostics reported.
  1   At least one diagnostic reported (or a file failed to parse).
  2   Invocation error (bad option, missing file argument, etc.).

Options:
  --locals k=v,k2=v2    Declare locals the template expects. Used by
                        rules such as 'unused-locals'. Values are
                        optional; only keys are inspected.
  --help, -h            Show this help

Examples:
  haml lint view.haml
  haml lint --locals name,age view.haml
  haml lint views/*.haml
  echo '%p hi' | haml lint -
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
      when '--out-dir' {
        die "haml render: --out-dir requires a path\n" unless @args.elems;
        %opts<out-dir> = @args.shift;
      }
      when '--watch'  { %opts<watch> = True; }
      when '--poll'   {
        die "haml render: --poll requires a millisecond value\n" unless @args.elems;
        my $v = @args.shift;
        die "haml render: --poll value must be a positive integer\n"
          unless $v ~~ /^ <[0..9]>+ $/ && $v.Int > 0;
        %opts<poll> = $v.Int;
      }
      when '--max-rebuilds' {
        die "haml render: --max-rebuilds requires an integer\n" unless @args.elems;
        my $v = @args.shift;
        die "haml render: --max-rebuilds value must be a non-negative integer\n"
          unless $v ~~ /^ <[0..9]>+ $/;
        %opts<max-rebuilds> = $v.Int;
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

sub parse-lint-args(@input --> Hash) {
  my @args = @input;
  my %opts;
  my @positional;
  while @args.elems {
    my $a = @args.shift;
    given $a {
      when '--locals' {
        die "haml lint: --locals requires an argument\n" unless @args.elems;
        %opts<locals> = parse-locals(@args.shift);
      }
      when '--help' | '-h' { %opts<help> = True; }
      when /^ '--' / | /^ '-' \w / {
        die "haml lint: unknown option '$a'\n";
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

sub render-file(Str:D $label, $src-blob, $config, %locals, IO::Handle:D $err --> Str) {
  CATCH {
    when X::HAML {
      $err.print("haml render: $label: " ~ .message ~ "\n");
      return Str;
    }
    default {
      $err.print("haml render: $label: " ~ .message ~ "\n");
      return Str;
    }
  }
  my $haml = HAML.new(:$config);
  $haml.render(:src($src-blob), :%locals);
}

our sub cmd-render(@args, IO::Handle :$out, IO::Handle :$err, IO::Handle :$in --> Int) is export {
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
  my $out-dir      = $parsed<opts><out-dir>;
  my $watch        = ?$parsed<opts><watch>;
  my $poll-ms      = $parsed<opts><poll>         // 0;
  my $max-rebuilds = $parsed<opts><max-rebuilds>;

  if $output-path.defined && $out-dir.defined {
    $err.print("haml render: -o and --out-dir are mutually exclusive\n");
    return 2;
  }
  if $watch && !($output-path.defined || $out-dir.defined) {
    $err.print("haml render: --watch requires -o or --out-dir\n");
    return 2;
  }
  if $out-dir.defined && !$out-dir.IO.d {
    $err.print("haml render: --out-dir directory not found: $out-dir\n");
    return 2;
  }

  my @raw-positional = $parsed<positional>.list;
  my $has-stdin = so @raw-positional.grep('-');
  if $has-stdin && ($watch || $out-dir.defined) {
    $err.print("haml render: '-' (stdin) cannot be combined with --watch or --out-dir\n");
    return 2;
  }

  my @glob-args   = @raw-positional.grep(* ~~ /<[*?]>/);
  my @plain-args  = @raw-positional.grep({ $_ !~~ /<[*?]>/ });

  my @expanded;
  for @glob-args -> $g {
    my @hits = Template::HAML::Watch::expand-inputs([$g]).list;
    unless @hits.elems {
      $err.print("haml render: glob matched no files: $g\n");
      return 1;
    }
    @expanded.append(@hits);
  }

  my @files-from-positional;
  my @stdin-args;
  for @plain-args -> $f {
    if $f eq '-' {
      @stdin-args.push($f);
    } else {
      @files-from-positional.push($f.IO);
    }
  }

  my @all-files = (@files-from-positional, @expanded).flat;
  my $multi-file = (@all-files.elems + @stdin-args.elems) > 1;

  if @stdin-args.elems > 1 {
    $err.print("haml render: '-' (stdin) may be given at most once\n");
    return 2;
  }

  if $output-path.defined && $multi-file {
    $err.print("haml render: -o accepts only a single input; use --out-dir for multiple files\n");
    return 2;
  }

  if !$output-path.defined && !$out-dir.defined && $multi-file {
    # falls through to stdout concatenation (legacy behavior).
  }

  if $watch {
    my $out-dir-io = $out-dir.defined ?? $out-dir.IO !! IO::Path;
    my &render-one = sub ($f --> Bool) {
      my $src = $f.slurp(:bin);
      my $result = render-file($f.Str, $src, $config, %locals, $err);
      return False unless $result.defined;
      my $target = $output-path.defined
        ?? $output-path.IO
        !! Template::HAML::Watch::mirror-output($f, $out-dir-io);
      $target.spurt($result);
      True;
    };

    my $watcher = Template::HAML::Watch::Watcher.new(
      :patterns(@raw-positional.grep(* ne '-').list),
      :&render-one,
      :max-rebuilds($max-rebuilds.defined ?? $max-rebuilds.Int !! Int),
      :poll-ms($poll-ms),
      :use-polling($poll-ms > 0),
    );
    return $watcher.run;
  }

  my @rendered;
  for @stdin-args -> $_dash {
    my $src   = $in.slurp;
    my $label = '<stdin>';
    my $r     = render-file($label, $src, $config, %locals, $err);
    return 1 unless $r.defined;
    @rendered.push($r);
  }
  for @all-files -> $file {
    unless $file.e {
      $err.print("haml render: file not found: $file\n");
      return 1;
    }
    my $src = $file.slurp(:bin);
    my $r   = render-file($file.Str, $src, $config, %locals, $err);
    return 1 unless $r.defined;
    if $out-dir.defined {
      Template::HAML::Watch::mirror-output($file, $out-dir.IO).spurt($r);
    } else {
      @rendered.push($r);
    }
  }

  unless $out-dir.defined {
    my $joined = @rendered.join('');
    if $output-path.defined {
      $output-path.IO.spurt($joined);
    } else {
      $out.print($joined);
    }
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

our sub cmd-lint(@args, IO::Handle :$out, IO::Handle :$err, IO::Handle :$in --> Int) is export {
  my $parsed;
  {
    CATCH {
      default {
        $err.print(.message);
        return 2;
      }
    }
    $parsed = parse-lint-args(@args);
  }

  if $parsed<opts><help> {
    $out.print(LINT-HELP);
    return 0;
  }

  unless $parsed<positional>.elems {
    $err.print("haml lint: missing file argument\n");
    $err.print(LINT-HELP);
    return 2;
  }

  my $exit        = 0;
  my $stdin-count = 0;
  my %locals      = $parsed<opts><locals> // %();
  for $parsed<positional>.list -> $file {
    my $src;
    my $label = $file;
    if $file eq '-' {
      $stdin-count++;
      if $stdin-count > 1 {
        $err.print("haml lint: '-' (stdin) may be given at most once\n");
        return 2;
      }
      $label = '<stdin>';
      $src = $in.slurp;
    } else {
      unless $file.IO.e {
        $err.print("haml lint: file not found: $file\n");
        $exit = 1;
        next;
      }
      $src = $file.IO.slurp(:bin);
    }

    my @diags;
    {
      CATCH {
        default {
          $err.print("haml lint: $label: " ~ .message ~ "\n");
          $exit = 1;
          next;
        }
      }
      my $linter = Template::HAML::Lint::Linter.new;
      @diags = $linter.lint(:$src, :path($label), :%locals).list;
    }

    for @diags -> $d {
      $out.print($d.format ~ "\n");
    }
    $exit = 1 if @diags.elems;
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

our sub run(@args, IO::Handle :$out = $*OUT, IO::Handle :$err = $*ERR, IO::Handle :$in = $*IN --> Int) is export {
  my @a = @args;
  if !@a.elems {
    $err.print(HELP-TEXT);
    return 2;
  }
  my $cmd = @a.shift;
  given $cmd {
    when 'render'                 { return cmd-render(@a, :$out, :$err, :$in); }
    when 'check'                  { return cmd-check(@a, :$out, :$err); }
    when 'fmt'                    { return cmd-fmt(@a,   :$out, :$err); }
    when 'lint'                   { return cmd-lint(@a,  :$out, :$err, :$in); }
    when 'help' | '--help' | '-h' {
      if @a.elems {
        given @a[0] {
          when 'render' { $out.print(RENDER-HELP); return 0; }
          when 'check'  { $out.print(CHECK-HELP);  return 0; }
          when 'fmt'    { $out.print(FMT-HELP);    return 0; }
          when 'lint'   { $out.print(LINT-HELP);   return 0; }
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
