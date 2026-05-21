use lib 'lib', 'specs/lib';
use BDD::Behave;
use CodegenHelpers;
use Template::HAML;
use Template::HAML::Config;
use Template::HAML::DirectCodegen;

class FakeCtx {
  method page-class(--> Str) { 'page' }
}

describe 'direct-emit statements', {
  context 'emitted code structure', {
    it 'non-bare expression does not call eval-haml and predeclares local', {
      my $tree = HAML.parse-source(:src("= \$name\n"));
      my $code = DirectCodegen.new.emit-direct($tree);
      expect($code).to.not.include('eval-haml(');
      expect($code).to.include('my $name');
    }

    it 'bare-ident expression goes through eval-bare-ident', {
      my $tree = HAML.parse-source(:src("= name\n"));
      my $code = DirectCodegen.new.emit-direct($tree);
      expect($code).to.include('eval-bare-ident(');
    }

    it 'unreferenced locals are not predeclared', {
      my $tree = HAML.parse-source(:src("%p hi\n"));
      my $code = DirectCodegen.new.emit-direct($tree);
      expect($code).to.not.include('my $unused');
    }

    it 'user vars starting with _haml_ are not predeclared (reserved namespace)', {
      my $tree = HAML.parse-source(:src("= \$_haml_x // 'fallback'\n"));
      my $code = DirectCodegen.new.emit-direct($tree);
      expect($code).to.not.include('my $_haml_x = ');
    }
  }

  context 'output statement round-trips', {
    it 'simple = output', { round-trip-check "= \$name\n", %(name => 'World'); }
    it '= escapes html by default', { round-trip-check "= \$name\n", %(name => '<b>'); }
    it '!= leaves html raw', { round-trip-check "!= \$raw\n", %(raw => '<b>x</b>'); }
    it '&= force-escapes', { round-trip-check "&= \$x\n", %(x => '<x>'); }
    it '== interpolation statement', {
      round-trip-check "== Hello, \#\{\$name\}!\n", %(name => 'World');
    }
    it '~ encodes newlines', { round-trip-check "~ \"line1\\nline2\"\n", %(); }
  }

  context 'bare-ident statements', {
    it 'bare-ident statement reads from %locals', {
      round-trip-check "= name\n", %(name => 'Bare');
    }
  }

  context 'silent statements', {
    it 'silent statement produces no output', { round-trip-check "- 1 + 2\n", %(); }
    it 'silent statement between tags', { round-trip-check "%p hi\n- 1\n%p bye\n", %(); }
  }

  context 'method/expression evaluation', {
    it 'method call on local', { round-trip-check "= \$user.uc\n", %(user => 'world'); }
    it 'list method', { round-trip-check "= \$items.elems\n", %(items => [1, 2, 3]); }
    it 'binary expression with two locals', { round-trip-check "= \$x + \$y\n", %(x => 2, y => 3); }
  }

  context 'mixed templates', {
    it 'mixed tags and statements', {
      round-trip-check Q:to/HAML/, %(name => 'World');
      %h1
        = "Hello, " ~ $name
      %p done
      HAML
    }

    it 'statement carrying a child block', {
      round-trip-check Q:to/HAML/, %(label => 'L');
      = $label
        %p inner
      HAML
    }
  }

  context 'context-based bare-ident', {
    it 'bare-ident resolves to context method', {
      round-trip-check "= page-class\n", %(), :context(FakeCtx.new);
    }
  }

  context 'helpers and safe strings', {
    it 'SafeString bypasses escaping', {
      round-trip-check "= html-safe('<b>x</b>')\n", %();
    }

    it 'haml-concat buffered output is preserved', {
      round-trip-check "= haml-concat('A') ~ haml-concat('B')\n", %();
    }
  }

  context 'config-driven behavior', {
    it 'escape-html=false leaves = output raw', {
      my $cfg = Template::HAML::Config.new(:!escape-html);
      round-trip-check "= \$x\n", %(x => '<b>'), :config($cfg);
    }

    it 'suppress-eval skips = eval', {
      my $cfg = Template::HAML::Config.new(:suppress-eval);
      round-trip-check "= \$name\n", %(name => 'X'), :config($cfg);
    }

    it 'suppress-eval still interpolates ==', {
      my $cfg = Template::HAML::Config.new(:suppress-eval);
      round-trip-check "== Hello \#\{\$name\}!\n", %(name => 'X'), :config($cfg);
    }
  }

  context 'filters via direct emit', {
    it 'filter now renders via direct emit', { round-trip-check ":plain\n  hi\n", %(); }
  }
}
