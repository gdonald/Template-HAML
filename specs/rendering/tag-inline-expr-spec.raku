use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Config;

describe 'inline embedded code after a tag head', {
  context 'documented %tag= form', {
    it 'evaluates and emits a local as content', {
      expect(HAML.render(:src("%h1= \$title\n"), :locals(%(title => 'Welcome'))))
        .to.eq("<h1>Welcome</h1>\n");
    }

    it 'allows whitespace between the tag head and the operator', {
      expect(HAML.render(:src("%h1 = \$title\n"), :locals(%(title => 'W'))))
        .to.eq("<h1>W</h1>\n");
    }

    it 'works on multiple tags in a single template', {
      expect(HAML.render(:src("%p= \$x\n%li= \$x\n"), :locals(%(x => 'X'))))
        .to.eq("<p>X</p>\n<li>X</li>\n");
    }
  }

  context 'escape rules per operator', {
    it 'HTML-escapes the result of = by default', {
      expect(HAML.render(:src(Q[%p= '<b>'] ~ "\n")))
        .to.eq("<p>&lt;b&gt;</p>\n");
    }

    it '!= emits the result raw', {
      expect(HAML.render(:src("%p!= \$raw\n"), :locals(%(raw => '<b>bold</b>'))))
        .to.eq("<p><b>bold</b></p>\n");
    }

    it '&= forces escape even when escape-html is off', {
      my $cfg = Template::HAML::Config.new(:!escape-html);
      expect(HAML.render(
        :src("%p&= \$x\n"),
        :locals(%(x => '<x>')),
        :config($cfg),
      )).to.eq("<p>&lt;x&gt;</p>\n");
    }

    it '== performs interpolation only', {
      expect(HAML.render(
        :src("%h1== Hello, \#\{\$name\}!\n"),
        :locals(%(name => 'World')),
      )).to.eq("<h1>Hello, World!</h1>\n");
    }

    it '~ replaces newlines with the &#x000A; entity', {
      expect(HAML.render(:src(Q[%pre~ "a\nb"] ~ "\n")))
        .to.eq("<pre>a&#x000A;b</pre>\n");
    }
  }

  context 'combination with attrs and shorthand', {
    it 'works with class shorthand', {
      expect(HAML.render(:src("%p.lead= \$msg\n"), :locals(%(msg => 'hi'))))
        .to.eq("<p class='lead'>hi</p>\n");
    }

    it 'works with html-style attrs', {
      expect(HAML.render(
        :src(Q[%a(href='/')= $label] ~ "\n"),
        :locals(%(label => 'home')),
      )).to.eq("<a href='/'>home</a>\n");
    }

    it 'works with hash-style attrs', {
      expect(HAML.render(
        :src(Q[%a{href: '/'}= $label] ~ "\n"),
        :locals(%(label => 'home')),
      )).to.eq("<a href='/'>home</a>\n");
    }

    it 'works with an implicit div from shorthand', {
      expect(HAML.render(:src(".lead= \$msg\n"), :locals(%(msg => 'hi'))))
        .to.eq("<div class='lead'>hi</div>\n");
    }
  }

  context 'works inside control flow', {
    it 'binds the for-loop variable for %li= \$i', {
      expect(HAML.render(:src("%ul\n  - for ^3 -> \$i\n    %li= \$i\n")))
        .to.eq("<ul>\n  <li>0</li>\n  <li>1</li>\n  <li>2</li>\n</ul>\n");
    }
  }

  context 'parity across emit modes', {
    it 'renders correctly under :emit<ast>', {
      my $cfg = Template::HAML::Config.new(:emit<ast>);
      expect(HAML.render(
        :src("%h1= \$title\n"),
        :locals(%(title => 'AST!')),
        :config($cfg),
      )).to.eq("<h1>AST!</h1>\n");
    }
  }
}
