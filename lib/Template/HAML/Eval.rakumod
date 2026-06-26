
use MONKEY-SEE-NO-EVAL;

use Template::HAML::Helpers;
use Template::HAML::X;

unit module Template::HAML::Eval;

my %compiled-cache;
my %source-cache;
my %helper-name-cache{Mu};

sub compile-key(Str $code, @keys, @helpers) {
  $code ~ "\0" ~ @keys.join("\0") ~ "\0\0" ~ @helpers.join("\0");
}

# The built-in helpers are already bare-callable through the Helpers import, so
# they need no per-context binding; only user-added methods do.
my constant BUILTIN-HELPERS = set <
  html-safe haml-concat escape-once surround precede succeed list-of
  find-and-preserve capture-haml yield content-for tab-up tab-down
  partial page-class
>;

# Methods a view-context object adds beyond the universal Any/Mu surface and the
# built-in helpers are its template helpers. Cached per context type.
sub context-helper-names($user) is export {
  return [] without $user;

  with %helper-name-cache{$user.WHAT} { return @$_ }

  my %base   = Any.^methods(:all).map(*.name).Set;
  my @names  = $user.^methods(:all)
    .map(*.name)
    .grep({ $_ ~~ / ^ <[a..z_]> <[\w-]>* $ / && !%base{$_} && !BUILTIN-HELPERS{$_} })
    .unique
    .sort
    .Array;

  %helper-name-cache{$user.WHAT} = @names;
  @names
}

sub helpers-in(Str $code, $user) {
  my @names = context-helper-names($user);
  return [] unless @names;
  @names.grep({ $code.contains($_) }).List
}

sub current-user-context() {
  my $ctx = (try { $*HAML-CTX }) // Nil;
  $ctx.defined ?? $ctx.user-context !! Nil
}

sub trace-on(--> Bool) {
  my $cfg = (try { $*HAML-CFG }) // Nil;
  $cfg.defined && $cfg.trace.so;
}

sub block-source-for(Str $key --> Str) {
  %source-cache{$key} // '';
}

sub block-line-for(Str $code --> Int) {
  # User-visible code starts on line 2 of the wrapper (line 1 is `-> { ` / `-> $x { `).
  2;
}

sub compile-block(Str $code, @keys, @helpers, Int :$line, Int :$column) {
  my $sig  = @keys.elems ?? @keys.map({ '$' ~ $_ }).join(', ') !! '';

  # Bind each context helper named in the code as a lexical sub, so it is
  # callable bare with arguments. Kept on one line so user code stays on line 2.
  my $preamble = @helpers.map({
    "my \&$_ = -> |__haml \{ \$*HAML-CTX.user-context.\"$_\"(|__haml) };"
  }).join(' ');

  my $body = $sig ?? "-> $sig \{ $preamble\n$code\n}" !! "-> \{ $preamble\n$code\n}";

  my $block;
  {
    CATCH {
      default {
        my %args =
          :$line, :$column, :$code, :reason(.message);
        if trace-on() {
          %args<block-source> = $body;
          %args<block-line>   = block-line-for($code);
        }
        X::HAML::Eval.new(|%args).throw;
      }
    }
    $block = EVAL $body;
  }
  ($block, $body);
}

sub eval-haml(Str $code, %locals, Int :$line = 0, Int :$column = 0) is export {
  my @keys    = %locals.keys.sort;
  my @helpers = helpers-in($code, current-user-context());
  my $key     = compile-key($code, @keys, @helpers);

  my $block = %compiled-cache{$key};
  unless $block.defined {
    my ($b, $source) = compile-block($code, @keys, @helpers, :$line, :$column);
    %compiled-cache{$key} = $block = $b;
    %source-cache{$key}   = $source;
  }

  my @args = @keys.map({ %locals{$_} });

  CATCH {
    when X::HAML { .rethrow }
    default {
      my %args =
        :$line, :$column, :$code, :reason(.message);
      if trace-on() {
        %args<block-source> = block-source-for($key);
        %args<block-line>   = block-line-for($code);
      }
      X::HAML::Eval.new(|%args).throw;
    }
  }
  $block(|@args);
}

sub clear-eval-cache() is export {
  %compiled-cache    = ();
  %source-cache      = ();
  %helper-name-cache = ();
}
