
use MONKEY-SEE-NO-EVAL;

use Template::HAML::Helpers;
use Template::HAML::X;

unit module Template::HAML::Eval;

my %compiled-cache;
my %source-cache;

sub compile-key(Str $code, @keys) {
  $code ~ "\0" ~ @keys.join("\0");
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

sub compile-block(Str $code, @keys, Int :$line, Int :$column) {
  my $sig  = @keys.elems ?? @keys.map({ '$' ~ $_ }).join(', ') !! '';
  my $body = $sig ?? "-> $sig \{\n$code\n}" !! "-> \{\n$code\n}";

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
  my @keys = %locals.keys.sort;
  my $key  = compile-key($code, @keys);

  my $block = %compiled-cache{$key};
  unless $block.defined {
    my ($b, $source) = compile-block($code, @keys, :$line, :$column);
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
  %compiled-cache = ();
  %source-cache   = ();
}
