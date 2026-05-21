use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Config;

describe 'Template::HAML::Config', {
  context 'defaults', {
    it 'sets sensible defaults', {
      my $cfg = Template::HAML::Config.new;
      expect($cfg.format).to.be('html5');
      expect($cfg.escape-html).to.be-truthy;
      expect($cfg.escape-attrs).to.be-truthy;
      expect($cfg.output-style).to.be('pretty');
      expect($cfg.attr-quote).to.be("'");
      expect($cfg.encoding).to.be('utf-8');
      expect($cfg.suppress-eval).to.be-falsy;
    }
  }

  context 'invalid options', {
    it 'rejects invalid format', {
      expect({ Template::HAML::Config.new(:format<bogus>) }).to.raise-error;
    }

    it 'rejects invalid output-style', {
      expect({ Template::HAML::Config.new(:output-style<weird>) }).to.raise-error;
    }

    it 'rejects invalid attr-quote', {
      expect({ Template::HAML::Config.new(:attr-quote<x>) }).to.raise-error;
    }
  }

  context 'format', {
    it 'XHTML void emits self-close with space-slash', {
      my $cfg = Template::HAML::Config.new(:format<xhtml>);
      expect(HAML.render(:src("%br\n"), :config($cfg))).to.eq("<br />\n");
    }

    it 'XHTML void %img emits <img />', {
      my $cfg = Template::HAML::Config.new(:format<xhtml>);
      expect(HAML.render(:src("%img\n"), :config($cfg))).to.eq("<img />\n");
    }

    it 'HTML5 void emits bare tag', {
      my $cfg = Template::HAML::Config.new(:format<html5>);
      expect(HAML.render(:src("%br\n"), :config($cfg))).to.eq("<br>\n");
    }
  }

  context 'boolean attributes', {
    it 'XHTML boolean attr uses name=name form', {
      my $cfg = Template::HAML::Config.new(:format<xhtml>);
      expect(HAML.render(:src("%input\(disabled\)\n"), :config($cfg))).to.eq("<input disabled='disabled' />\n");
    }

    it 'HTML5 boolean attr is bare', {
      my $cfg5 = Template::HAML::Config.new(:format<html5>);
      expect(HAML.render(:src("%input\(disabled\)\n"), :config($cfg5))).to.eq("<input disabled>\n");
    }
  }

  context 'default doctype', {
    it 'HTML5 default doctype', {
      my $cfg-html5 = Template::HAML::Config.new(:format<html5>);
      expect(HAML.render(:src("!!!\n"), :config($cfg-html5))).to.eq("<!DOCTYPE html>\n");
    }

    it 'HTML4 default doctype', {
      my $cfg-html4 = Template::HAML::Config.new(:format<html4>);
      expect(HAML.render(:src("!!!\n"), :config($cfg-html4))).to.match(/'HTML 4.01 Transitional'/);
    }

    it 'XHTML default doctype', {
      my $cfg-xhtml = Template::HAML::Config.new(:format<xhtml>);
      expect(HAML.render(:src("!!!\n"), :config($cfg-xhtml))).to.match(/'XHTML 1.0 Transitional'/);
    }
  }

  context 'escape-html', {
    it 'escape-html False: = does not escape', {
      my $cfg = Template::HAML::Config.new(:escape-html(False));
      expect(HAML.render(:src("= \$x\n"), :locals(%(x => '<b>')), :config($cfg))).to.eq("<b>\n");
    }

    it 'escape-html True: = does escape', {
      my $cfg-on = Template::HAML::Config.new(:escape-html(True));
      expect(HAML.render(:src("= \$x\n"), :locals(%(x => '<b>')), :config($cfg-on))).to.eq("&lt;b&gt;\n");
    }

    it 'escape-html False: &= still escapes', {
      my $cfg = Template::HAML::Config.new(:escape-html(False));
      expect(HAML.render(:src("\&= \$x\n"), :locals(%(x => '<b>')), :config($cfg))).to.eq("&lt;b&gt;\n");
    }

    it 'escape-html True: != still does not escape', {
      my $cfg-on = Template::HAML::Config.new(:escape-html(True));
      expect(HAML.render(:src("!= \$x\n"), :locals(%(x => '<b>')), :config($cfg-on))).to.eq("<b>\n");
    }
  }

  context 'escape-attrs', {
    it 'escape-attrs False: ampersand left raw', {
      my $cfg-off = Template::HAML::Config.new(:escape-attrs(False));
      expect(HAML.render(:src("%a\{href: 'a&b'\}\n"), :config($cfg-off))).to.eq("<a href='a&b'></a>\n");
    }

    it 'escape-attrs True (default): ampersand escaped', {
      my $cfg-on = Template::HAML::Config.new(:escape-attrs(True));
      expect(HAML.render(:src("%a\{href: 'a&b'\}\n"), :config($cfg-on))).to.eq("<a href='a&amp;b'></a>\n");
    }
  }

  context 'output-style', {
    it 'ugly: no whitespace between tags', {
      my $cfg = Template::HAML::Config.new(:output-style<ugly>);
      expect(HAML.render(:src("%div\n  %p hi\n"), :config($cfg))).to.eq('<div><p>hi</p></div>');
    }
  }

  context 'autoclose', {
    it 'adds new void elements', {
      my $cfg = Template::HAML::Config.new(:autoclose(<custom-tag br>), :format<xhtml>);
      expect(HAML.render(:src("%custom-tag\n"), :config($cfg))).to.eq("<custom-tag />\n");
    }

    it 'omitting img makes img no longer void', {
      my $cfg = Template::HAML::Config.new(:autoclose(<custom-tag br>), :format<xhtml>);
      expect(HAML.render(:src("%img\n"), :config($cfg))).to.eq("<img></img>\n");
    }
  }

  context 'encoding', {
    it 'drives the XML declaration', {
      my $cfg = Template::HAML::Config.new(:encoding<iso-8859-1>);
      expect(HAML.render(:src("!!! XML\n"), :config($cfg))).to.eq("<?xml version='1.0' encoding='iso-8859-1' ?>\n");
    }
  }

  context 'attr-quote', {
    it 'uses the configured quote character', {
      my $cfg = Template::HAML::Config.new(:attr-quote('"'));
      expect(HAML.render(:src("%a\{href: '/'\}\n"), :config($cfg))).to.eq(qq{<a href="/"></a>\n});
    }
  }

  context 'suppress-eval', {
    it '= produces no output', {
      my $cfg = Template::HAML::Config.new(:suppress-eval);
      expect(HAML.render(:src("= \$x\n"), :locals(%(x => 'hello')), :config($cfg))).to.eq("");
    }

    it '- is skipped but tags still render', {
      my $cfg = Template::HAML::Config.new(:suppress-eval);
      expect(HAML.render(:src("- my \$z = 1\n%p hi\n"), :config($cfg))).to.eq("<p>hi</p>\n");
    }
  }

  context 'class-level and instance render', {
    it 'class-level render with no config still works', {
      expect(HAML.render(:src("%p hi\n"))).to.eq("<p>hi</p>\n");
    }

    it 'instance config XHTML produces self-close', {
      my $h = HAML.new(:config(Template::HAML::Config.new(:format<xhtml>)));
      expect($h.render(:src("%br\n"))).to.eq("<br />\n");
    }

    it 'per-render config overrides instance config', {
      my $h = HAML.new(:config(Template::HAML::Config.new(:format<xhtml>)));
      my $cfg5 = Template::HAML::Config.new(:format<html5>);
      expect($h.render(:src("%br\n"), :config($cfg5))).to.eq("<br>\n");
    }
  }
}
