use lib 'lib';
use BDD::Behave;
use Template::HAML;

describe 'string interpolation', {
  context '#{...} in tag content', {
    it 'interpolates local in tag content', {
      expect(HAML.render(:src(Q[%p Hello, #{$name}!] ~ "\n"), :locals(%(name => 'world'))))
        .to.eq("<p>Hello, world!</p>\n");
    }

    it 'interpolates numeric value', {
      expect(HAML.render(:src(Q[%p Count: #{$n}] ~ "\n"), :locals(%(n => 42))))
        .to.eq("<p>Count: 42</p>\n");
    }

    it 'backslash escape produces literal', {
      expect(HAML.render(:src(Q[%p \#{x}] ~ "\n")))
        .to.eq(Q[<p>#{x}</p>] ~ "\n");
    }

    it '!{...} non-escaped interpolation', {
      expect(HAML.render(:src(Q[%p !{$raw}] ~ "\n"), :locals(%(raw => '<b>bold</b>'))))
        .to.eq("<p><b>bold</b></p>\n");
    }

    it '#{...} HTML-escapes value', {
      expect(HAML.render(:src(Q[%p #{$tag}] ~ "\n"), :locals(%(tag => '<b>'))))
        .to.eq("<p>&lt;b&gt;</p>\n");
    }

    it 'handles multiple interpolations on one line', {
      expect(HAML.render(:src(Q[%p Two: #{1+1} and three: #{1+2}] ~ "\n")))
        .to.eq("<p>Two: 2 and three: 3</p>\n");
    }
  }

  context 'in attributes', {
    it '#{...} inside double-quoted attr value', {
      expect(HAML.render(
        :src(Q[%a{href: "/users/#{$id}"}link] ~ "\n"),
        :locals(%(id => 7))
      )).to.eq("<a href='/users/7'>link</a>\n");
    }

    it 'no interpolation in single-quoted strings', {
      expect(HAML.render(
        :src(Q[%a{title: 'Hello #{$name}'}link] ~ "\n"),
        :locals(%(name => 'foo'))
      )).to.eq(Q[<a title='Hello #{$name}'>link</a>] ~ "\n");
    }

    it 'interpolated attr value is HTML-escaped', {
      expect(HAML.render(
        :src(Q[%a{href: "/q?x=#{$v}"}link] ~ "\n"),
        :locals(%(v => 'a&b'))
      )).to.eq("<a href='/q?x=a&amp;b'>link</a>\n");
    }

    it 'HTML-attr style double-quoted value supports interp', {
      expect(HAML.render(
        :src(Q[%a(href="/u/#{$id}")go] ~ "\n"),
        :locals(%(id => 5))
      )).to.eq("<a href='/u/5'>go</a>\n");
    }

    it 'HTML-attr style single-quoted value does not interp', {
      expect(HAML.render(
        :src(Q[%a(title='a #{1}')go] ~ "\n")
      )).to.eq(Q[<a title='a #{1}'>go</a>] ~ "\n");
    }

    it 'backslash n decodes when no interp markers', {
      expect(HAML.render(:src(Q[%a{title: "x\ny"}go] ~ "\n")))
        .to.eq("<a title='x\ny'>go</a>\n");
    }

    it 'backslash n decodes inside string with interp', {
      expect(HAML.render(:src(Q[%a{title: "x\ny#{$v}"}go] ~ "\n"), :locals(%(v => 'Z'))))
        .to.eq("<a title='x\nyZ'>go</a>\n");
    }

    it 'backslash escape in attrs is literal', {
      expect(HAML.render(:src(Q[%a{title: "literal \#{x}"}go] ~ "\n")))
        .to.eq(Q[<a title='literal #{x}'>go</a>] ~ "\n");
    }
  }

  context 'plain text', {
    it '#{...} in plain text', {
      expect(HAML.render(:src(Q[Hello, #{$name}!] ~ "\n"), :locals(%(name => 'world'))))
        .to.eq("Hello, world!\n");
    }

    it '!{...} in plain text', {
      expect(HAML.render(:src(Q[!{$raw}] ~ "\n"), :locals(%(raw => '<x>'))))
        .to.eq("<x>\n");
    }

    it '#{...} in plain text escapes', {
      expect(HAML.render(:src(Q[#{$x}] ~ "\n"), :locals(%(x => '<x>'))))
        .to.eq("&lt;x&gt;\n");
    }

    it '#{...} in indented plain text', {
      expect(HAML.render(
        :src("%div\n" ~ Q[  Hello, #{$name}!] ~ "\n"),
        :locals(%(name => 'foo'))
      )).to.eq("<div>\n  Hello, foo!\n</div>\n");
    }
  }

  context 'escaping in #{...}', {
    it '& is escaped', {
      expect(HAML.render(:src(Q[%p #{$s}] ~ "\n"), :locals(%(s => '&')))).to.eq("<p>&amp;</p>\n");
    }

    it '< is escaped', {
      expect(HAML.render(:src(Q[%p #{$s}] ~ "\n"), :locals(%(s => '<')))).to.eq("<p>&lt;</p>\n");
    }

    it '> is escaped', {
      expect(HAML.render(:src(Q[%p #{$s}] ~ "\n"), :locals(%(s => '>')))).to.eq("<p>&gt;</p>\n");
    }

    it 'double-quote is escaped', {
      expect(HAML.render(:src(Q[%p #{$s}] ~ "\n"), :locals(%(s => '"')))).to.eq("<p>&quot;</p>\n");
    }

    it 'single-quote is escaped', {
      expect(HAML.render(:src(Q[%p #{$s}] ~ "\n"), :locals(%(s => "'")))).to.eq("<p>&#39;</p>\n");
    }

    it '!{} does not escape HTML chars', {
      expect(HAML.render(:src(Q[%p !{$s}] ~ "\n"), :locals(%(s => '<&>')))).to.eq("<p><&></p>\n");
    }
  }

  context '== plain content with interpolation', {
    it '== is plain content with interpolation', {
      expect(HAML.render(:src(Q[== Hello, #{$name}!] ~ "\n"), :locals(%(name => 'world'))))
        .to.eq("Hello, world!\n");
    }

    it '== without interp emits literal text', {
      expect(HAML.render(:src(Q[== Plain text without interp] ~ "\n")))
        .to.eq("Plain text without interp\n");
    }

    it '== supports !{} too', {
      expect(HAML.render(:src(Q[== !{$x}] ~ "\n"), :locals(%(x => '<b>'))))
        .to.eq("<b>\n");
    }
  }
}
