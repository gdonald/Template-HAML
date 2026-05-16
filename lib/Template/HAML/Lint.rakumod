
use Template::HAML;
use Template::HAML::Config;
use Template::HAML::Node;
use Template::HAML::Visitor;
use Template::HAML::X;

unit module Template::HAML::Lint;

class Diagnostic is export {
  has Str $.rule;
  has Str $.severity = 'warning';
  has Int $.line     = 0;
  has Int $.column   = 0;
  has Str $.message;
  has Str $.path;

  method format(--> Str) {
    my $p = $!path // '<input>';
    "$p:$!line:$!column: $!severity: $!message ($!rule)";
  }
}

role Rule is export {
  method id(--> Str)                             { ... }
  method check(Node :$tree, Str :$src --> List)  { ... }
}

class DeprecatedSyntaxRule does Rule is export {
  method id(--> Str) { 'deprecated-syntax' }

  method check(Node :$tree, :$src!, :%locals --> List) {
    my $text = $src ~~ Str ?? $src !! $src.decode('UTF-8');
    my @diags;
    for $text.lines.kv -> $i, $line {
      if $line ~~ / ^ (\h*) ':ruby' \h* $ / {
        @diags.push: Diagnostic.new(
          :rule<deprecated-syntax>, :severity<warning>,
          :line($i + 1), :column($0.chars + 1),
          :message(":ruby filter is no longer supported; use :raku for Raku code"),
        );
      }
    }
    @diags.List;
  }
}

class MalformedIndentRule does Rule is export {
  method id(--> Str) { 'malformed-indent' }

  method check(Node :$tree, :$src!, :%locals --> List) {
    my $text = $src ~~ Str ?? $src !! $src.decode('UTF-8');
    my @diags;
    for $text.lines.kv -> $i, $line {
      next unless $line.chars;
      if $line !~~ / \S / {
        @diags.push: Diagnostic.new(
          :rule<malformed-indent>, :severity<warning>,
          :line($i + 1), :column(1),
          :message('blank line contains whitespace'),
        );
        next;
      }
      my $stripped = $line.subst(/ \h+ $ /, '');
      if $stripped.chars != $line.chars {
        @diags.push: Diagnostic.new(
          :rule<malformed-indent>, :severity<warning>,
          :line($i + 1), :column($stripped.chars + 1),
          :message('trailing whitespace'),
        );
      }
    }
    @diags.List;
  }
}

class UnusedLocalsRule does Rule is export {
  method id(--> Str) { 'unused-locals' }

  method check(Node :$tree, :$src!, :%locals --> List) {
    return ().List unless %locals.elems;

    my $text = $src ~~ Str ?? $src !! $src.decode('UTF-8');
    my %used;
    for $text ~~ m:g/ '$' (<[A..Za..z_]> <[A..Za..z0..9_]>*) / -> $m {
      %used{~$m[0]} = True;
    }

    my @diags;
    for %locals.keys.sort -> $key {
      next if %used{$key};
      @diags.push: Diagnostic.new(
        :rule<unused-locals>, :severity<warning>,
        :line(1), :column(1),
        :message("local '\$$key' is never referenced"),
      );
    }
    @diags.List;
  }
}

our sub default-rules(--> List) is export {
  (
    DeprecatedSyntaxRule.new,
    MalformedIndentRule.new,
    UnusedLocalsRule.new,
  ).List;
}

my @registered;

our sub register-rule(Rule:D $rule) is export {
  @registered.push: $rule;
}

our sub clear-rules(--> Int) is export {
  my $n = @registered.elems;
  @registered = ();
  $n;
}

our sub registered-rules(--> List) is export {
  @registered.List;
}

class Linter is export {
  has @.rules;

  submethod BUILD(:$rules) {
    with $rules {
      @!rules = $rules.list;
    } else {
      @!rules = (default-rules(), @registered).flat.list;
    }
  }

  method lint(:$src!, Str :$path, :%locals, Template::HAML::Config :$config --> List) {
    my $cfg  = $config // Template::HAML::Config.new;
    my $text = $src ~~ Str ?? $src !! $src.decode($cfg.encoding);
    my $tree;
    {
      CATCH {
        when X::HAML {
          return (Diagnostic.new(
            :rule<parse-error>, :severity<error>,
            :line($_.line   // 0),
            :column($_.column // 0),
            :message($_.message),
            :$path,
          ),).List;
        }
      }
      $tree = HAML.parse-source(:src($text), :config($cfg));
    }

    my @diags;
    for @!rules -> $rule {
      for $rule.check(:$tree, :src($text), :%locals).list -> $d {
        @diags.push: Diagnostic.new(
          :rule($d.rule    // $rule.id),
          :severity($d.severity),
          :line($d.line),
          :column($d.column),
          :message($d.message),
          :$path,
        );
      }
    }
    @diags.sort({ ($_.line, $_.column) }).List;
  }
}
