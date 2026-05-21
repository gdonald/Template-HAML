use lib 'lib', 'specs/lib';
use BDD::Behave;
use CodegenHelpers;
use MONKEY-SEE-NO-EVAL;
use Template::HAML;
use Template::HAML::Config;
use Template::HAML::DirectCodegen;
use Template::HAML::Filters;

describe 'direct-emit filters', {
  context 'emitted code structure', {
    it 'filter dispatch uses lookup-filter at runtime and avoids AST Filter node', {
      my $tree = HAML.parse-source(:src(":plain\n  hi\n"));
      my $code = DirectCodegen.new.emit-direct($tree);
      expect($code).to.include('lookup-filter(');
      expect($code).to.not.include('Filter.new');
    }
  }

  context 'built-in filters', {
    it ':plain renders body verbatim', { round-trip-check ":plain\n  hello\n", %(); }

    it ':plain with interpolation', {
      round-trip-check Q:to/HAML/, %(name => 'World');
      :plain
        hello #{$name}
      HAML
    }

    it ':escaped html-escapes body', { round-trip-check ":escaped\n  <b>hi</b>\n", %(); }

    it ':preserve encodes newlines', {
      round-trip-check Q:to/HAML/, %();
      :preserve
        line1
        line2
      HAML
    }

    it ':javascript wraps body in script tag', {
      round-trip-check Q:to/HAML/, %();
      :javascript
        var x = 1;
      HAML
    }

    it ':css wraps body in style tag', {
      round-trip-check Q:to/HAML/, %();
      :css
        body { color: red; }
      HAML
    }

    it ':cdata wraps body', {
      round-trip-check Q:to/HAML/, %();
      :cdata
        some cdata
      HAML
    }

    it ':raku evaluates expression', { round-trip-check ":raku\n  1 + 2\n", %(); }

    it ':raku reads locals', {
      round-trip-check Q:to/HAML/, %(name => 'World');
      :raku
        "Hello, " ~ $name
      HAML
    }
  }

  context 'filters in context', {
    it 'filter inside tag indents correctly', {
      round-trip-check Q:to/HAML/, %();
      %div
        :plain
          nested
      HAML
    }

    it 'filter inside for loop', {
      round-trip-check Q:to/HAML/, %(items => [1, 2]);
      - for $items -> $i
        :plain
          item #{$i}
      HAML
    }
  }

  context 'markdown backend', {
    it ':markdown without backend throws MarkdownBackendMissing', {
      Template::HAML::Filters::clear-markdown-backend();
      my $tree = HAML.parse-source(:src(":markdown\n  hi\n"));
      my $code = DirectCodegen.new.emit-direct($tree);
      my &fn   = EVAL $code;
      expect({ &fn(%()) }).to.raise-error;
    }

    it ':markdown uses registered backend', {
      Template::HAML::Filters::register-markdown-backend(:handler(-> Str $body --> Str {
        "MD[$body]"
      }));
      LEAVE { Template::HAML::Filters::clear-markdown-backend() }
      round-trip-check ":markdown\n  some text\n", %();
    }
  }

  context 'edge cases', {
    it 'filter with no body emits nothing', {
      round-trip-check ":plain\n", %();
    }

    it 'user-registered filter works through direct emit', {
      Template::HAML::Filters::register-filter(
        :name<shout>,
        :handler(-> Str $body, %locals --> Str { $body.uc.chomp }),
      );
      LEAVE { Template::HAML::Filters::clear-filter('shout') }
      round-trip-check ":shout\n  whisper\n", %();
    }
  }
}
