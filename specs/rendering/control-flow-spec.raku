use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::X;

describe 'HAML control flow', {
  context 'if / unless', {
    it '- if True renders body', {
      expect(HAML.render(:src("- if True\n  %p hi\n"))).to.eq("<p>hi</p>\n");
    }

    it '- if False renders nothing', {
      expect(HAML.render(:src("- if False\n  %p hi\n"))).to.eq('');
    }

    it '- if reads local', {
      expect(HAML.render(:src("- if \$x\n  %p yes\n"), :locals(%(:x(1))))).to.eq("<p>yes</p>\n");
    }

    it '- if with falsey local', {
      expect(HAML.render(:src("- if \$x\n  %p yes\n"), :locals(%(:x(0))))).to.eq('');
    }

    it '- unless False renders body', {
      expect(HAML.render(:src("- unless False\n  %p hi\n"))).to.eq("<p>hi</p>\n");
    }

    it '- unless True renders nothing', {
      expect(HAML.render(:src("- unless True\n  %p hi\n"))).to.eq('');
    }
  }

  context 'if / else / elsif', {
    it 'if-branch fires', {
      expect(HAML.render(:src("- if True\n  %p a\n- else\n  %p b\n"))).to.eq("<p>a</p>\n");
    }

    it 'else-branch fires', {
      expect(HAML.render(:src("- if False\n  %p a\n- else\n  %p b\n"))).to.eq("<p>b</p>\n");
    }

    it 'if-chain first branch', {
      expect(HAML.render(
        :src("- if \$x == 1\n  %p one\n- elsif \$x == 2\n  %p two\n- else\n  %p other\n"),
        :locals(%(:x(1))),
      )).to.eq("<p>one</p>\n");
    }

    it 'if-chain elsif branch', {
      expect(HAML.render(
        :src("- if \$x == 1\n  %p one\n- elsif \$x == 2\n  %p two\n- else\n  %p other\n"),
        :locals(%(:x(2))),
      )).to.eq("<p>two</p>\n");
    }

    it 'if-chain else branch', {
      expect(HAML.render(
        :src("- if \$x == 1\n  %p one\n- elsif \$x == 2\n  %p two\n- else\n  %p other\n"),
        :locals(%(:x(9))),
      )).to.eq("<p>other</p>\n");
    }

    it 'if-chain third elsif', {
      expect(HAML.render(
        :src("- if \$x == 1\n  %p a\n- elsif \$x == 2\n  %p b\n- elsif \$x == 3\n  %p c\n"),
        :locals(%(:x(3))),
      )).to.eq("<p>c</p>\n");
    }

    it 'if nested under tag', {
      expect(HAML.render(:src("%div\n  - if True\n    %p hi\n"))).to.eq("<div>\n  <p>hi</p>\n</div>\n");
    }

    it 'if/elsif (no else) elsif fires', {
      expect(HAML.render(:src("- if False\n  %p a\n- elsif True\n  %p b\n"))).to.eq("<p>b</p>\n");
    }

    it 'if/elsif (no else) nothing matches', {
      expect(HAML.render(:src("- if False\n  %p a\n- elsif False\n  %p b\n"))).to.eq('');
    }
  }

  context 'for loops', {
    it 'for ITER -> VAR loops', {
      expect(HAML.render(
        :src("- for \$items -> \$x\n  = \$x\n"),
        :locals(%(:items([1,2,3]))),
      )).to.eq("1\n2\n3\n");
    }

    it 'for VAR in ITER loops', {
      expect(HAML.render(
        :src("- for \$x in \$items\n  = \$x\n"),
        :locals(%(:items(<a b c>))),
      )).to.eq("a\nb\nc\n");
    }

    it 'for over empty array emits nothing', {
      expect(HAML.render(
        :src("- for \$x in \$items\n  %li = \$x\n"),
        :locals(%(:items([]))),
      )).to.eq('');
    }

    it 'for nested inside tag', {
      expect(HAML.render(
        :src("%ul\n  - for \$x in \$items\n    = \$x\n"),
        :locals(%(:items([1,2]))),
      )).to.eq("<ul>\n  1\n  2\n</ul>\n");
    }

    it 'loop variable visible in deeper nested =', {
      expect(HAML.render(
        :src("- for \$x in \$items\n  %p\n    = \$x\n"),
        :locals(%(:items([10]))),
      )).to.eq("<p>\n  10\n</p>\n");
    }

    it 'loop variable does not leak to siblings', {
      expect({
        HAML.render(
          :src("- for \$x in \$items\n  = \$x\n= \$x\n"),
          :locals(%(:items([1]))),
        )
      }).to.raise-error(X::HAML::Eval);
    }

    it '= sees loop variable inside body', {
      expect(HAML.render(
        :src("- for \$nums -> \$n\n  = \$n * 10\n"),
        :locals(%(:nums([1,2,3]))),
      )).to.eq("10\n20\n30\n");
    }

    it 'nested for produces cartesian output', {
      expect(HAML.render(
        :src("- for \$x in \$as\n  - for \$y in \$bs\n    %p\n      = \$x ~ \$y\n"),
        :locals(%(:as(<x y>), :bs(<1 2>))),
      )).to.eq("<p>\n  x1\n</p>\n<p>\n  x2\n</p>\n<p>\n  y1\n</p>\n<p>\n  y2\n</p>\n");
    }

    it 'if/else nested inside for', {
      expect(HAML.render(
        :src("- for \$x in \$xs\n  - if \$x > 1\n    %p big\n  - else\n    %p small\n"),
        :locals(%(:xs([1,2,3]))),
      )).to.eq("<p>small</p>\n<p>big</p>\n<p>big</p>\n");
    }
  }

  context 'while loops', {
    it 'while drains a mutable array', {
      expect(HAML.render(
        :src("- while \$items.elems\n  = \$items.shift\n"),
        :locals(%(:items([1,2,3]))),
      )).to.eq("1\n2\n3\n");
    }

    it 'while False emits nothing', {
      expect(HAML.render(:src("- while False\n  %p hi\n"))).to.eq('');
    }
  }

  context 'given / when', {
    it 'first match', {
      expect(HAML.render(
        :src("- given \$x\n  - when 1\n    %p one\n  - when 2\n    %p two\n  - default\n    %p other\n"),
        :locals(%(:x(1))),
      )).to.eq("<p>one</p>\n");
    }

    it 'second match', {
      expect(HAML.render(
        :src("- given \$x\n  - when 1\n    %p one\n  - when 2\n    %p two\n  - default\n    %p other\n"),
        :locals(%(:x(2))),
      )).to.eq("<p>two</p>\n");
    }

    it 'default fires', {
      expect(HAML.render(
        :src("- given \$x\n  - when 1\n    %p one\n  - when 2\n    %p two\n  - default\n    %p other\n"),
        :locals(%(:x(9))),
      )).to.eq("<p>other</p>\n");
    }

    it 'no match no default', {
      expect(HAML.render(
        :src("- given \$x\n  - when 1\n    %p one\n"),
        :locals(%(:x(9))),
      )).to.eq('');
    }

    it 'first match wins (smartmatch type)', {
      expect(HAML.render(
        :src("- given \$x\n  - when Int\n    %p int\n  - when 1\n    %p one\n"),
        :locals(%(:x(1))),
      )).to.eq("<p>int</p>\n");
    }
  }

  context 'orphan branches', {
    it 'orphan elsif raises', {
      expect({ HAML.render(:src("- elsif True\n  %p x\n")) }).to.raise-error(X::HAML::OrphanElse);
    }

    it 'orphan else raises', {
      expect({ HAML.render(:src("- else\n  %p x\n")) }).to.raise-error(X::HAML::OrphanElse);
    }
  }

  context 'integration', {
    it '= inside if body', {
      expect(HAML.render(:src("- if True\n  = 'yo'\n"))).to.eq("yo\n");
    }

    it 'siblings around if-chain render correctly', {
      expect(HAML.render(:src("%p before\n- if True\n  %p mid\n%p after\n"))).to.eq("<p>before</p>\n<p>mid</p>\n<p>after</p>\n");
    }
  }
}
