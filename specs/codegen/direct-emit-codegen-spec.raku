use lib 'lib', 'specs/lib';
use BDD::Behave;
use CodegenHelpers;
use Template::HAML;
use Template::HAML::Config;
use Template::HAML::DirectCodegen;

describe 'Template::HAML::DirectCodegen', {
  context 'emitted source shape', {
    it 'calls interpolate, builds via concat, avoids Renderer/Node construction', {
      my $tree = HAML.parse-source(:src(qq[%p Hello #\{\$n\}\n]));
      my $code = DirectCodegen.new.emit-direct($tree);
      expect($code).to.include('interpolate(');
      expect($code).to.include('$_haml_out ~=');
      expect($code).to.not.include('Renderer.new');
      expect($code).to.not.include('Node.new');
    }
  }

  context 'tag round-trips', {
    it 'plain inline tag', { round-trip-check "%p hello\n", %(); }
    it 'nested tags', { round-trip-check "%div\n  %p first\n  %p second\n", %(); }
    it 'void element self-closes', { round-trip-check "%br\n", %(); }
    it 'explicit self-close marker', { round-trip-check "%hr/\n", %(); }
    it 'static shorthand classes and id', { round-trip-check "%p.x.y#main hi\n", %(); }

    it 'tag content with interpolation', {
      round-trip-check Q[%p Hello #{$name}] ~ "\n", %(name => 'World');
    }

    it 'escaped interpolation in tag content', {
      round-trip-check Q[%p \#{$name} stays literal] ~ "\n", %(name => 'X');
    }

    it 'static html-style attrs', {
      round-trip-check Q[%a(href='/' title='Home') home] ~ "\n", %();
    }

    it 'static hash-style attrs', {
      round-trip-check Q[%div{foo: 'bar'} body] ~ "\n", %();
    }

    it 'boolean html attr', {
      round-trip-check Q[%input(type='checkbox' checked)] ~ "\n", %();
    }
  }

  context 'plain text round-trips', {
    it 'plain text node', { round-trip-check "Plain at top\n", %(); }
    it 'two plain text lines', { round-trip-check "Hello\nWorld\n", %(); }
    it 'plain text with interpolation', {
      round-trip-check qq[Hello #\{\$name\}\n], %(name => 'World');
    }
  }

  context 'doctype round-trips', {
    it 'html5 doctype', { round-trip-check "!!!\n%html\n  %body\n", %(); }
    it 'explicit html5 doctype', { round-trip-check "!!! 5\n", %(); }
    it 'XML declaration', { round-trip-check "!!! XML\n", %(); }
  }

  context 'comment round-trips', {
    it 'visible comment', { round-trip-check "/ a comment\n", %(); }
    it 'silent comment emits nothing', { round-trip-check "-# silent\n", %(); }
    it 'conditional comment block', { round-trip-check "/[if IE]\n  %p hi\n", %(); }
  }

  context 'whitespace round-trips', {
    it 'trim-outer strips surrounding whitespace', {
      round-trip-check "%p first\n%p> trimmed\n%p last\n", %();
    }

    it 'ugly output collapses whitespace', {
      my $cfg = Template::HAML::Config.new(:output-style<ugly>);
      round-trip-check "%div\n  %p hi\n", %(), :config($cfg);
    }

    it 'xhtml self-close adds slash', {
      my $cfg = Template::HAML::Config.new(:format<xhtml>);
      round-trip-check "%br\n", %(), :config($cfg);
    }
  }

  context 'module emission', {
    it 'emits unit module declaration and haml-render entry point', {
      my $tree = HAML.parse-source(:src("%p hello\n"));
      my $mod-src = DirectCodegen.new.emit-direct-module($tree, :module-name<DirectEmitTest>);
      expect($mod-src).to.include('unit module DirectEmitTest;');
      expect($mod-src).to.include('our sub haml-render');
    }
  }

  context 'control-flow and filters', {
    it 'simple for loop renders', {
      round-trip-check "- for ^3 -> \$i\n  %li= \$i\n", %();
    }

    it 'plain filter renders', { round-trip-check ":plain\n  hi\n", %(); }

    it 'unknown filter throws at codegen', {
      my $tree = HAML.parse-source(:src(":nosuchfilter\n  hi\n"));
      expect({ DirectCodegen.new.emit-direct($tree) }).to.raise-error;
    }
  }

  context 'dynamic and object attrs', {
    it 'InterpString attribute value renders', {
      round-trip-check Q[%a(href="hello #{$x}") hi] ~ "\n", %(x => 'world');
    }

    it 'attribute splat renders', {
      round-trip-check Q[%div{|$attrs} body] ~ "\n",
        %(attrs => { href => '/about', title => 'About' });
    }

    it 'object-ref args render', {
      my class _DocAcc {
        has Int $.id;
        method haml-object-ref(--> Str) { 'account' }
      }
      my $a = _DocAcc.new(:id(7));
      round-trip-check Q[%div[$user] hi] ~ "\n", %(user => $a);
    }
  }
}
