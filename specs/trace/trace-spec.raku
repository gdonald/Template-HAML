use lib 'lib', 'specs/lib';
use BDD::Behave;
use SpecHelpers;
use MONKEY-SEE-NO-EVAL;
use Template::HAML;
use Template::HAML::Codegen;
use Template::HAML::Config;
use Template::HAML::Eval;
use Template::HAML::X;

describe 'trace mode', {
  context 'Config.trace defaults and toggling', {
    it 'defaults to False', {
      my $cfg = Template::HAML::Config.new;
      expect($cfg.trace).to.be-falsy;
    }

    it 'honors :trace and supports clone-with toggling', {
      my $cfg = Template::HAML::Config.new(:trace);
      expect($cfg.trace).to.be-truthy;
      my $c2 = $cfg.clone-with(:!trace);
      expect($c2.trace).to.be-falsy;
      my $c3 = Template::HAML::Config.new.clone-with(:trace);
      expect($c3.trace).to.be-truthy;
    }
  }

  context 'eval failure with trace off', {
    it 'raises with line preserved and no block-source', {
      clear-eval-cache();
      my $cfg = Template::HAML::Config.new;
      my $src = "%p ok\n= no_such_sub_xyzzy()\n";
      my $err = trap-eval({ HAML.render(:$src, :config($cfg)) });
      expect($err).to.not.be-nil;
      expect($err.line).to.be(2);
      expect($err.block-source).to.be-falsy;
      expect($err.message.contains('compiled block')).to.be-falsy;
    }
  }

  context 'eval failure with trace on', {
    it 'attaches block-source with user code and template-to-block mapping', {
      clear-eval-cache();
      my $cfg = Template::HAML::Config.new(:trace);
      my $src = "%p ok\n= no_such_sub_xyzzy()\n";
      my $err = trap-eval({ HAML.render(:$src, :config($cfg)) });
      expect($err).to.not.be-nil;
      expect($err.line).to.be(2);
      expect($err.block-source).to.not.be-nil;
      expect($err.block-source).to.include('no_such_sub_xyzzy');
      expect($err.block-source.starts-with('->')).to.be-truthy;
      expect($err.block-line).to.be(2);
      expect($err.message).to.include('compiled block');
      expect($err.message).to.include('template line 2 → block line 2');
    }
  }

  context 'trace on with locals', {
    it 'includes the signature in block-source', {
      clear-eval-cache();
      my $cfg = Template::HAML::Config.new(:trace);
      my $src = "= boom_xyzzy(\$x)\n";
      my $err = trap-eval({ HAML.render(:$src, :locals(%(x => 1)), :config($cfg)) });
      expect($err).to.not.be-nil;
      expect($err.block-source).to.include('-> $x');
    }
  }

  context 'compile-time failure with trace on', {
    it 'attaches block-source and trace header', {
      clear-eval-cache();
      my $cfg = Template::HAML::Config.new(:trace);
      my $src = "= 1 +\n";
      my $err = trap-eval({ HAML.render(:$src, :config($cfg)) });
      expect($err).to.not.be-nil;
      expect($err.block-source).to.not.be-nil;
      expect($err.message).to.include('compiled block');
    }
  }

  context 'codegen path', {
    it 'maps line to template and attaches block-source when trace is on', {
      clear-eval-cache();
      my $cfg = Template::HAML::Config.new(:trace);
      my $src = "%p first\n= no_such_sub_xyzzy()\n";
      my $code = HAML.compile-source-to-raku(:$src, :config($cfg));
      my &fn   = EVAL $code;
      my $err  = trap-eval({ fn(%(), :ctx(Nil)) });
      expect($err).to.not.be-nil;
      expect($err.line).to.be(2);
      expect($err.block-source).to.not.be-nil;
    }

    it 'omits block-source when trace is off', {
      clear-eval-cache();
      my $cfg = Template::HAML::Config.new;
      my $src = "%p first\n= no_such_sub_xyzzy()\n";
      my $code = HAML.compile-source-to-raku(:$src, :config($cfg));
      my &fn   = EVAL $code;
      my $err  = trap-eval({ fn(%(), :ctx(Nil)) });
      expect($err).to.not.be-nil;
      expect($err.block-source).to.be-falsy;
    }
  }

  context 'direct eval-haml', {
    it 'raises without block-source when called without a renderer', {
      clear-eval-cache();
      my $err = trap-eval({ eval-haml('die "boom"', %(), :line(5), :column(2)) });
      expect($err).to.not.be-nil;
      expect($err.block-source).to.be-falsy;
    }
  }
}
