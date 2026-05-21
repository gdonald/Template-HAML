use lib 'lib', 'specs/lib';
use BDD::Behave;
use CodegenHelpers;
use Template::HAML;
use Template::HAML::Config;
use Template::HAML::DirectCodegen;

class FlagCtx {
  method enabled(--> Bool) { True }
}

describe 'direct-emit control flow', {
  context 'emitted code structure', {
    it 'if-cond is inlined as native Raku with template-line tracking', {
      my $tree = HAML.parse-source(:src("- if \$x\n  %p y\n"));
      my $code = DirectCodegen.new.emit-direct($tree);
      expect($code).to.include('if eval-direct({ $x }');
    }

    it 'for-loop is inlined as native Raku with template-line tracking', {
      my $tree = HAML.parse-source(:src("- for ^3 -> \$i\n  %li= \$i\n"));
      my $code = DirectCodegen.new.emit-direct($tree);
      expect($code).to.include('for @(eval-direct({ ^3 }');
      expect($code).to.include('-> $i');
    }
  }

  context 'if / elsif / else', {
    it 'if matches first branch', {
      round-trip-check Q:to/HAML/, %(n => 1);
      - if $n == 1
        %p one
      - elsif $n == 2
        %p two
      - else
        %p other
      HAML
    }

    it 'if/elsif/else picks elsif', {
      round-trip-check Q:to/HAML/, %(n => 2);
      - if $n == 1
        %p one
      - elsif $n == 2
        %p two
      - else
        %p other
      HAML
    }

    it 'if/elsif/else falls through to else', {
      round-trip-check Q:to/HAML/, %(n => 99);
      - if $n == 1
        %p one
      - elsif $n == 2
        %p two
      - else
        %p other
      HAML
    }
  }

  context 'unless', {
    it 'unless skips truthy branch', {
      round-trip-check Q:to/HAML/, %(x => True);
      - unless $x
        %p shown only when falsy
      - else
        %p truthy branch
      HAML
    }

    it 'unless renders falsy branch', {
      round-trip-check Q:to/HAML/, %(x => False);
      - unless $x
        %p shown only when falsy
      HAML
    }
  }

  context 'for loops', {
    it 'for loop iterates locals', {
      round-trip-check Q:to/HAML/, %(items => [1, 2, 3]);
      - for $items -> $i
        %li= $i
      HAML
    }

    it 'for $x in items syntax', {
      round-trip-check Q:to/HAML/, %(items => ['a', 'b']);
      - for $x in $items
        %li= $x
      HAML
    }

    it 'empty for renders nothing', {
      round-trip-check "- for ^0 -> \$i\n  %li= \$i\n", %();
    }

    it 'nested for loops', {
      round-trip-check Q:to/HAML/, %();
      - for ^2 -> $i
        %ul
          - for ^2 -> $j
            %li= "$i.$j"
      HAML
    }
  }

  context 'while', {
    it 'while drains an array', {
      round-trip-check Q:to/HAML/, %(items => [1, 2, 3].Array);
      - while $items.elems
        %li= $items.shift
      HAML
    }

    it 'while with literal condition (false initially)', {
      round-trip-check Q:to/HAML/, %();
      - while False
        %p never
      HAML
    }
  }

  context 'repeat', {
    it 'repeat literal N', { round-trip-check "- repeat 3\n  %li hi\n", %(); }
    it 'repeat dynamic N', { round-trip-check "- repeat \$n\n  %li= \"x\"\n", %(n => 4); }
    it 'repeat 0 renders nothing', { round-trip-check "- repeat 0\n  %li nope\n", %(); }
    it 'repeat negative clamps to 0', { round-trip-check "- repeat -5\n  %li nope\n", %(); }
  }

  context 'given/when', {
    it 'given/when picks matching branch', {
      round-trip-check Q:to/HAML/, %(label => 2);
      - given $label
        - when 1
          %p one
        - when 2
          %p two
        - default
          %p other
      HAML
    }

    it 'given/when falls through to default', {
      round-trip-check Q:to/HAML/, %(label => 99);
      - given $label
        - when 1
          %p one
        - when 2
          %p two
        - default
          %p other
      HAML
    }

    it 'given with string match', {
      round-trip-check Q:to/HAML/, %(label => 'apple');
      - given $label
        - when 'apple'
          %p fruit
        - when 'carrot'
          %p veg
      HAML
    }
  }

  context 'orphan branches', {
    it 'orphan elsif throws OrphanElse', {
      my $tree = HAML.parse-source(:src("- elsif \$x\n  %p y\n"));
      expect({ DirectCodegen.new.emit-direct($tree) }).to.raise-error;
    }

    it 'orphan else throws OrphanElse', {
      my $tree = HAML.parse-source(:src("- else\n  %p y\n"));
      expect({ DirectCodegen.new.emit-direct($tree) }).to.raise-error;
    }
  }

  context 'nested templates', {
    it 'nested with statements and tags', {
      round-trip-check Q:to/HAML/, %(name => 'world');
      %html
        %body
          %h1
            = "Hello, " ~ $name
          %ul
            - for ^3 -> $i
              %li= $i
      HAML
    }

    it 'bare-ident in if cond uses context method', {
      my $src = Q:to/HAML/;
      - if enabled
        %p shown
      - else
        %p hidden
      HAML
      round-trip-check $src, %(), :context(FlagCtx.new);
    }

    it 'predeclared locals visible inside and outside if', {
      round-trip-check Q:to/HAML/, %(x => 5, y => 10);
      %p= $x
      - if $x < $y
        %p= $y
      HAML
    }

    it 'loop var shadows outer local of same name', {
      round-trip-check Q:to/HAML/, %(i => 'OUT', items => [1, 2]);
      %p= $i
      - for $items -> $i
        %p= $i
      %p= $i
      HAML
    }

    it 'multiple if-chains as siblings', {
      round-trip-check Q:to/HAML/, %(a => 1, b => 2);
      - if $a
        %p A
      - if $b
        %p B
      HAML
    }

    it 'if-chain inside tag body', {
      round-trip-check Q:to/HAML/, %(cond => True, x => 'X');
      %div
        - if $cond
          %p
            = $x
      HAML
    }
  }
}
