use lib 'lib';
use BDD::Behave;
use Template::HAML::Format;

sub fmt(Str:D $src) { format-source($src) }

my $nl = "\n";

describe 'format-source: code, comments, doctype, filters', {
  context 'expressions', {
    it 'preserves expression with =', {
      expect(fmt('= 1 + 2' ~ $nl)).to.eq('= 1 + 2' ~ $nl);
    }

    it 'preserves expression with !=', {
      expect(fmt('!= raw' ~ $nl)).to.eq('!= raw' ~ $nl);
    }

    it 'preserves expression with &=', {
      expect(fmt('&= forced' ~ $nl)).to.eq('&= forced' ~ $nl);
    }

    it 'preserves expression with ~', {
      expect(fmt('~ preserved' ~ $nl)).to.eq('~ preserved' ~ $nl);
    }
  }

  context 'silent statements', {
    it 'preserves silent statement with -', {
      expect(fmt('- my $x = 1' ~ $nl)).to.eq('- my $x = 1' ~ $nl);
    }

    it 'preserves if block', {
      expect(fmt('- if $cond' ~ $nl ~ '  %p hi' ~ $nl)).to.eq(
        '- if $cond' ~ $nl ~ '  %p hi' ~ $nl
      );
    }

    it 'preserves if/elsif/else chain', {
      my $src = '- if $a' ~ $nl ~ '  %p a' ~ $nl ~ '- elsif $b' ~ $nl ~ '  %p b' ~ $nl ~ '- else' ~ $nl ~ '  %p c' ~ $nl;
      expect(fmt($src)).to.eq($src);
    }

    it 'preserves unless block', {
      expect(fmt('- unless $cond' ~ $nl ~ '  %p hi' ~ $nl)).to.eq(
        '- unless $cond' ~ $nl ~ '  %p hi' ~ $nl
      );
    }

    it 'preserves while loop', {
      expect(fmt('- while $i' ~ $nl ~ '  %p hi' ~ $nl)).to.eq(
        '- while $i' ~ $nl ~ '  %p hi' ~ $nl
      );
    }

    it 'preserves for/in canonical form', {
      expect(fmt('- for $x in @items' ~ $nl ~ '  %li hi' ~ $nl)).to.eq(
        '- for $x in @items' ~ $nl ~ '  %li hi' ~ $nl
      );
    }

    it 'canonicalizes arrow-block for to for/in', {
      expect(fmt('- for @items -> $x' ~ $nl ~ '  %li hi' ~ $nl)).to.eq(
        '- for $x in @items' ~ $nl ~ '  %li hi' ~ $nl
      );
    }

    it 'preserves given/when/default block', {
      my $src = '- given $kind' ~ $nl ~ '  - when 1' ~ $nl ~ '    %p one' ~ $nl ~ '  - default' ~ $nl ~ '    %p other' ~ $nl;
      expect(fmt($src)).to.eq($src);
    }

    it 'preserves repeat block', {
      expect(fmt('- repeat 3' ~ $nl ~ '  %p hi' ~ $nl)).to.eq(
        '- repeat 3' ~ $nl ~ '  %p hi' ~ $nl
      );
    }
  }

  context 'HTML comments', {
    it 'preserves inline HTML comment', {
      expect(fmt('/ Hello' ~ $nl)).to.eq('/ Hello' ~ $nl);
    }

    it 'preserves block HTML comment', {
      expect(fmt('/' ~ $nl ~ '  %p hi' ~ $nl)).to.eq('/' ~ $nl ~ '  %p hi' ~ $nl);
    }

    it 'preserves inline conditional comment', {
      expect(fmt('/[if IE] only IE' ~ $nl)).to.eq('/[if IE] only IE' ~ $nl);
    }

    it 'preserves block conditional comment', {
      expect(fmt('/[if IE]' ~ $nl ~ '  %p ie' ~ $nl)).to.eq(
        '/[if IE]' ~ $nl ~ '  %p ie' ~ $nl
      );
    }

    it 'preserves revealed conditional comment', {
      expect(fmt('/![if !IE] text' ~ $nl)).to.eq('/![if !IE] text' ~ $nl);
    }
  }

  context 'silent comments', {
    it 'preserves inline silent comment text', {
      expect(fmt('-# notes' ~ $nl)).to.eq('-# notes' ~ $nl);
    }

    it 'preserves block silent comment body', {
      my $src = '-#' ~ $nl ~ '  arbitrary text $^&*' ~ $nl ~ '  more notes' ~ $nl;
      expect(fmt($src)).to.eq($src);
    }

    it 'preserves silent comment with both inline and body', {
      expect(fmt('-# inline' ~ $nl ~ '  body line' ~ $nl)).to.eq(
        '-# inline' ~ $nl ~ '  body line' ~ $nl
      );
    }
  }

  context 'doctype', {
    it 'preserves bare doctype', {
      expect(fmt('!!!' ~ $nl)).to.eq('!!!' ~ $nl);
    }

    it 'preserves HTML5 doctype variant', {
      expect(fmt('!!! 5' ~ $nl)).to.eq('!!! 5' ~ $nl);
    }

    it 'preserves XHTML Strict doctype', {
      expect(fmt('!!! Strict' ~ $nl)).to.eq('!!! Strict' ~ $nl);
    }

    it 'preserves XML doctype', {
      expect(fmt('!!! XML' ~ $nl)).to.eq('!!! XML' ~ $nl);
    }

    it 'preserves XML doctype with encoding', {
      expect(fmt('!!! XML iso-8859-1' ~ $nl)).to.eq('!!! XML iso-8859-1' ~ $nl);
    }
  }

  context 'filters', {
    it 'preserves :plain filter', {
      expect(fmt(':plain' ~ $nl ~ '  hello' ~ $nl)).to.eq(
        ':plain' ~ $nl ~ '  hello' ~ $nl
      );
    }

    it 'preserves :javascript filter', {
      expect(fmt(':javascript' ~ $nl ~ '  alert(1);' ~ $nl)).to.eq(
        ':javascript' ~ $nl ~ '  alert(1);' ~ $nl
      );
    }

    it 'preserves :css filter', {
      expect(fmt(':css' ~ $nl ~ '  body { color: red; }' ~ $nl)).to.eq(
        ':css' ~ $nl ~ '  body { color: red; }' ~ $nl
      );
    }
  }

  context 'idempotence', {
    it 'is idempotent on a mixed document', {
      my $src = '!!! 5' ~ $nl ~ '%html' ~ $nl ~ '  %head' ~ $nl ~ '    %title hi' ~ $nl ~ '  %body' ~ $nl ~ '    /' ~ $nl ~ '      %p comment' ~ $nl ~ '    - for $x in @items' ~ $nl ~ '      %li= $x' ~ $nl;
      expect(fmt($src)).to.eq(fmt(fmt($src)));
    }
  }
}
