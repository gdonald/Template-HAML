use lib 'lib', 'specs/lib';
use BDD::Behave;
use SpecHelpers;
use Template::HAML;
use Template::HAML::X;

describe 'HAML statement lines', {
  context '= expression output', {
    it 'simple arithmetic', {
      expect(HAML.render(:src("= 1 + 2\n"))).to.eq("3\n");
    }

    it 'literal string', {
      expect(HAML.render(:src("= 'hi'\n"))).to.eq("hi\n");
    }

    it 'reads local', {
      expect(HAML.render(:src("= \$name\n"), :locals(%(:name<World>)))).to.eq("World\n");
    }

    it 'reads multiple locals', {
      expect(HAML.render(:src("= \$x * \$y\n"), :locals(%(:x(3), :y(4))))).to.eq("12\n");
    }

    it 'HTML-escapes output', {
      expect(HAML.render(:src("= '<b>x</b>'\n"))).to.eq("&lt;b&gt;x&lt;/b&gt;\n");
    }

    it '!= leaves raw HTML', {
      expect(HAML.render(:src("!= '<b>x</b>'\n"))).to.eq("<b>x</b>\n");
    }

    it '&= escapes output', {
      expect(HAML.render(:src("&= '<b>x</b>'\n"))).to.eq("&lt;b&gt;x&lt;/b&gt;\n");
    }

    it 'string concat', {
      expect(HAML.render(:src("= 'a' ~ 'b'\n"))).to.eq("ab\n");
    }

    it '= Nil emits empty', {
      expect(HAML.render(:src("= Nil\n"))).to.eq("\n");
    }

    it '= 0 emits 0', {
      expect(HAML.render(:src("= 0\n"))).to.eq("0\n");
    }

    it '= True renders True', {
      expect(HAML.render(:src("= True\n"))).to.eq("True\n");
    }

    it '= False renders False', {
      expect(HAML.render(:src("= False\n"))).to.eq("False\n");
    }

    it 'multiple = lines emit each', {
      expect(HAML.render(:src("= 1\n= 2\n= 3\n"))).to.eq("1\n2\n3\n");
    }
  }

  context '- silent statement', {
    it 'emits nothing', {
      expect(HAML.render(:src("- 1 + 2\n"))).to.eq('');
    }

    it 'does not break sibling rendering', {
      expect(HAML.render(:src("- my \$x = 1\n%p hi\n"))).to.eq("<p>hi</p>\n");
    }

    it 'can declare a lexical without affecting other lines', {
      expect(HAML.render(:src("- my \$count = 5\n%p hi\n"))).to.eq("<p>hi</p>\n");
    }
  }

  context 'nesting and locals', {
    it '= respects indent within tag', {
      expect(HAML.render(:src("%div\n  = 1 + 1\n"))).to.eq("<div>\n  2\n</div>\n");
    }

    it 'locals visible inside nested block', {
      expect(HAML.render(:src("%ul\n  = \$item\n"), :locals(%(:item<one>)))).to.eq("<ul>\n  one\n</ul>\n");
    }

    it '= sees array-typed local', {
      expect(HAML.render(:src("= \$items.elems\n"), :locals(%(:items([1,2,3,4]))))).to.eq("4\n");
    }

    it '= sees hash-typed local', {
      expect(HAML.render(:src("= \$cfg<title>\n"), :locals(%(:cfg(%(:title<Hello>)))))).to.eq("Hello\n");
    }
  }

  context 'eval errors', {
    it 'undefined sub raises X::HAML::Eval', {
      expect({ HAML.render(:src("= no_such_sub_xyzzy()\n")) }).to.raise-error(X::HAML::Eval);
    }

    it 'X::HAML::Eval carries source line', {
      my $err = catch-it({ HAML.render(:src("\n= no_such_sub_xyzzy()\n")) });
      expect($err).to.not.be-nil;
      expect($err).to.be-a(X::HAML::Eval);
      expect($err.line).to.be(2);
    }
  }
}
