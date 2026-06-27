
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

sub valid-helper-name(Str() $name --> Bool) {
  so $name ~~ / ^ <[a..z_]> <[\w-]>* $ /
}

# A view-context's template helpers are the methods it adds beyond the universal
# Any/Mu surface. Built-in helper names (surround, partial, …) are included when
# the context defines them, so a context can override a built-in. A context may
# instead declare its helpers explicitly with a `haml-helper-names` method, which
# is required when the helpers are installed in a way `.^methods` does not report
# (metaprogrammed or dynamic per instance); that list is trusted and not cached.
sub context-helper-names($user) is export {
  return [] without $user;

  if $user.^can('haml-helper-names') {
    return $user.haml-helper-names.map(*.Str).grep(&valid-helper-name).unique.sort.Array;
  }

  with %helper-name-cache{$user.WHAT} { return @$_ }

  my %base   = Any.^methods(:all).map(*.name).Set;
  my @names  = $user.^methods(:all)
    .map(*.name)
    .grep({ valid-helper-name($_) && !%base{$_} })
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
