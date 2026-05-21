use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Filters;
use Template::HAML::X;

describe 'HAML filters', {
  context 'built-in filter output', {
    it ':plain emits raw text', {
      expect(HAML.render(:src(q:to/HAML/))).to.eq("Hello world\nGoodbye\n");
      :plain
        Hello world
        Goodbye
      HAML
    }

    it ':plain does not parse sigils', {
      expect(HAML.render(:src(q:to/HAML/))).to.eq("%p not a tag\n");
      :plain
        %p not a tag
      HAML
    }

    it ':plain does not escape', {
      expect(HAML.render(:src(q:to/HAML/))).to.eq("<b>raw html</b>\n");
      :plain
        <b>raw html</b>
      HAML
    }

    it ':escaped HTML-escapes', {
      expect(HAML.render(:src(q:to/HAML/))).to.eq("&lt;b&gt;raw&lt;/b&gt; &amp; &quot;stuff&quot;\n");
      :escaped
        <b>raw</b> & "stuff"
      HAML
    }

    it ':javascript wraps in <script>', {
      expect(HAML.render(:src(q:to/HAML/))).to.eq("<script>\n  alert('hi');\n</script>\n");
      :javascript
        alert('hi');
      HAML
    }

    it ':javascript multi-line', {
      expect(HAML.render(:src(q:to/HAML/))).to.eq("<script>\n  var x = 1;\n  var y = 2;\n</script>\n");
      :javascript
        var x = 1;
        var y = 2;
      HAML
    }

    it ':css wraps in <style>', {
      expect(HAML.render(:src(q:to/HAML/))).to.eq("<style>\n  body \{ color: red; \}\n</style>\n");
      :css
        body { color: red; }
      HAML
    }

    it ':cdata wraps in CDATA', {
      expect(HAML.render(:src(q:to/HAML/))).to.eq("<![CDATA[\n  some data\n]]>\n");
      :cdata
        some data
      HAML
    }

    it ':preserve replaces newlines', {
      expect(HAML.render(:src(q:to/HAML/))).to.eq("line1&#x000A;line2\n");
      :preserve
        line1
        line2
      HAML
    }

    it ':raku evals body', {
      expect(HAML.render(:src(q:to/HAML/))).to.eq("3\n");
      :raku
        1 + 2
      HAML
    }
  }

  context 'filter locals and interpolation', {
    it ':raku sees locals', {
      expect(HAML.render(:src(q:to/HAML/), :locals(%(x => 10)))).to.eq("20\n");
      :raku
        $x * 2
      HAML
    }

    it ':plain interpolates #{}', {
      expect(HAML.render(:src(q:to/HAML/), :locals(%(name => 'World')))).to.eq("Hello, World!\n");
      :plain
        Hello, #{$name}!
      HAML
    }

    it ':javascript interpolates', {
      expect(HAML.render(:src(q:to/HAML/), :locals(%(n => 5)))).to.eq("<script>\n  var n = 5;\n</script>\n");
      :javascript
        var n = #{$n};
      HAML
    }

    it ':css interpolates', {
      expect(HAML.render(:src(q:to/HAML/), :locals(%(c => 'red')))).to.eq("<style>\n  body \{ color: red; \}\n</style>\n");
      :css
        body { color: #{$c}; }
      HAML
    }

    it ':escaped interpolates and escapes whole', {
      expect(HAML.render(:src(q:to/HAML/), :locals(%(s => 'hi')))).to.eq("hi &lt;b&gt;x&lt;/b&gt;\n");
      :escaped
        #{$s} <b>x</b>
      HAML
    }

    it ':cdata interpolates', {
      expect(HAML.render(:src(q:to/HAML/), :locals(%(v => 'hello')))).to.eq("<![CDATA[\n  data: hello\n]]>\n");
      :cdata
        data: #{$v}
      HAML
    }

    it ':raku body is code, not interpolated', {
      expect(HAML.render(:src(q:to/HAML/), :locals(%(x => 7)))).to.eq("8\n");
      :raku
        $x + 1
      HAML
    }
  }

  context 'unknown filter', {
    it 'raises X::HAML::UnknownFilter', {
      expect({ HAML.render(:src(":nope\n  body\n")) }).to.raise-error(X::HAML::UnknownFilter);
    }
  }

  context 'register-filter', {
    register-filter :name<upper>, :handler(-> Str $body, %locals --> Str {
      $body.uc;
    });

    it 'allows a custom filter', {
      expect(HAML.render(:src(q:to/HAML/))).to.eq("HELLO\n");
      :upper
        hello
      HAML
    }

    it 'allows a custom multi-line filter', {
      expect(HAML.render(:src(q:to/HAML/))).to.eq("ONE\nTWO\n");
      :upper
        one
        two
      HAML
    }
  }

  context 'filter nested under tag', {
    it 'indents output beneath the parent tag', {
      expect(HAML.render(:src(q:to/HAML/))).to.eq("<div>\n  <script>\n    alert(1);\n  </script>\n</div>\n");
      %div
        :javascript
          alert(1);
      HAML
    }

    it 'renders :plain beneath the parent tag', {
      expect(HAML.render(:src(q:to/HAML/))).to.eq("<div>\n  raw\n</div>\n");
      %div
        :plain
          raw
      HAML
    }
  }

  context 'filter body preservation', {
    it ':plain preserves relative indent in body', {
      expect(HAML.render(:src(q:to/HAML/))).to.eq("outer\n  inner\n");
      :plain
        outer
          inner
      HAML
    }

    it ':plain preserves internal blank line', {
      expect(HAML.render(:src(q:to/HAML/))).to.eq("one\n\ntwo\n");
      :plain
        one

        two
      HAML
    }
  }

  context 'filters mixed with sibling tags', {
    it 'renders filter followed by sibling tag', {
      expect(HAML.render(:src(q:to/HAML/))).to.eq("filtered\n<p>after</p>\n");
      :plain
        filtered
      %p after
      HAML
    }

    it 'renders filter between tags', {
      expect(HAML.render(:src(q:to/HAML/))).to.eq("<p>first</p>\n<script>\n  go();\n</script>\n<p>last</p>\n");
      %p first
      :javascript
        go();
      %p last
      HAML
    }
  }

  context 'has-filter / lookup-filter', {
    it 'reports built-in filters as present', {
      expect(has-filter('plain')).to.be-truthy;
      expect(has-filter('escaped')).to.be-truthy;
      expect(has-filter('javascript')).to.be-truthy;
      expect(has-filter('css')).to.be-truthy;
      expect(has-filter('cdata')).to.be-truthy;
      expect(has-filter('preserve')).to.be-truthy;
      expect(has-filter('raku')).to.be-truthy;
    }

    it 'reports unknown filters as absent', {
      expect(has-filter('does-not-exist')).to.be-falsy;
    }

    it 'returns a Callable from lookup-filter', {
      expect(lookup-filter('plain') ~~ Callable).to.be-truthy;
    }
  }
}
