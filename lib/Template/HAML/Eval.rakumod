
use MONKEY-SEE-NO-EVAL;

use Template::HAML::Helpers;
use Template::HAML::X;

unit module Template::HAML::Eval;

my %compiled-cache;

sub compile-key(Str $code, @keys) {
  $code ~ "\0" ~ @keys.join("\0");
}

sub compile-block(Str $code, @keys, Int :$line, Int :$column) {
  my $sig  = @keys.elems ?? @keys.map({ '$' ~ $_ }).join(', ') !! '';
  my $body = $sig ?? "-> $sig \{\n$code\n}" !! "-> \{\n$code\n}";

  my $block;
  {
    CATCH {
      default {
        X::HAML::Eval.new(
          :$line, :$column, :$code, :reason(.message),
        ).throw;
      }
    }
    $block = EVAL $body;
  }
  $block;
}

sub eval-haml(Str $code, %locals, Int :$line = 0, Int :$column = 0) is export {
  my @keys = %locals.keys.sort;
  my $key  = compile-key($code, @keys);

  my $block = %compiled-cache{$key} //= compile-block($code, @keys, :$line, :$column);

  my @args = @keys.map({ %locals{$_} });

  CATCH {
    when X::HAML { .rethrow }
    default {
      X::HAML::Eval.new(
        :$line, :$column, :$code, :reason(.message),
      ).throw;
    }
  }
  $block(|@args);
}

sub clear-eval-cache() is export {
  %compiled-cache = ();
}
