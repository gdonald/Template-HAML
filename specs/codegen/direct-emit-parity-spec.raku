use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Config;

my $LT = chr(60);
my $GT = chr(62);

sub parity-check(Str $src, Template::HAML::Config :$config) {
  my $ast-cfg    = ($config // Template::HAML::Config.new).clone-with(:emit<ast>);
  my $direct-cfg = ($config // Template::HAML::Config.new).clone-with(:emit<direct>);
  my $expected = HAML.render(:$src, :config($ast-cfg));
  my $actual   = HAML.render(:$src, :config($direct-cfg));
  expect($actual).to.eq($expected);
}

describe 'direct-emit parity', {
  context 'whitespace trim modifiers', {
    it 'trim-inner inline content', { parity-check "%p$LT hi\n"; }
    it 'trim-inner strips inner whitespace', { parity-check "%blockquote$LT\n  %div\n    Foo!\n"; }
    it 'trim-inner with content + child', { parity-check "%p$LT hello\n  %strong world\n"; }
    it 'trim-inner + trim-outer combined', { parity-check "%p$LT$GT hi\n"; }
    it 'trim-outer + trim-inner combined', { parity-check "%p$GT$LT\n  %a hi\n"; }
    it 'combined trims as only child', { parity-check "%div\n  %p$LT$GT\n    %a hi\n"; }
  }

  context 'preserved elements', {
    it 'pre preserves inner ws', { parity-check "%pre\n  Line 1\n  Line 2\n"; }
    it 'textarea preserves inner ws', { parity-check "%textarea\n  hello\n  world\n"; }
    it 'pre with single-line content', { parity-check "%pre Just text\n"; }
    it 'pre nested in div', { parity-check "%div\n  %pre\n    text\n"; }

    it 'custom preserve element', {
      my $cfg = Template::HAML::Config.new(:preserve('custom-pre',));
      parity-check "%custom-pre\n  hi\n", :config($cfg);
    }

    it 'pre not preserved when removed from list', {
      my $cfg = Template::HAML::Config.new(:preserve('textarea',));
      parity-check "%pre\n  hi\n", :config($cfg);
    }
  }

  context 'remove-whitespace config', {
    it 'remove-ws lone tag', {
      my $cfg = Template::HAML::Config.new(:remove-whitespace);
      parity-check "%p hi\n", :config($cfg);
    }
    it 'remove-ws siblings', {
      my $cfg = Template::HAML::Config.new(:remove-whitespace);
      parity-check "%p first\n%p middle\n%p last\n", :config($cfg);
    }
    it 'remove-ws nested', {
      my $cfg = Template::HAML::Config.new(:remove-whitespace);
      parity-check "%div\n  %p hi\n", :config($cfg);
    }
    it 'remove-ws deeper', {
      my $cfg = Template::HAML::Config.new(:remove-whitespace);
      parity-check "%div\n  %p\n    %span hi\n", :config($cfg);
    }
    it 'remove-ws void', {
      my $cfg = Template::HAML::Config.new(:remove-whitespace);
      parity-check "%img\n%img\n%img\n", :config($cfg);
    }
    it 'remove-ws preserves pre', {
      my $cfg = Template::HAML::Config.new(:remove-whitespace);
      parity-check "%pre\n  Line 1\n  Line 2\n", :config($cfg);
    }
    it 'remove-ws outer-trim on pre', {
      my $cfg = Template::HAML::Config.new(:remove-whitespace);
      parity-check "%div\n  %pre\n    hi\n", :config($cfg);
    }
  }

  context 'tab-up / tab-down statements', {
    it 'tab-up bumps indent', { parity-check "%div\n  - tab-up\n  %p deep\n  - tab-down\n  %p back\n"; }
    it 'tab-up 2 levels', { parity-check "%div\n  - tab-up 2\n  %p deep\n  - tab-down 2\n  %p back\n"; }
    it 'tab-up on plain text', { parity-check "%div\n  - tab-up\n  hello\n  - tab-down\n"; }
  }

  context 'direct-emit state isolation', {
    it 'tab offset resets between direct-emit renders', {
      my $cfg = Template::HAML::Config.new(:emit<direct>);
      HAML.render(:src("%div\n  - tab-up\n  %p deep\n"), :config($cfg));
      expect(HAML.render(:src("%p hi\n"), :config($cfg))).to.eq("<p>hi</p>\n");
    }

    it 'find-and-preserve helper callable in direct-emit', {
      my $cfg = Template::HAML::Config.new(:emit<direct>);
      my $src = qq[!= find-and-preserve("<pre>a\\nb</pre>")\n];
      expect(HAML.render(:$src, :config($cfg))).to.eq("<pre>a&#x000A;b</pre>\n");
    }

    it 'pre preservation already &#x000A;-encoded in direct emit output', {
      my $cfg = Template::HAML::Config.new(:emit<direct>);
      my $src = "%pre\n  hello\n  world\n";
      my $rendered = HAML.render(:$src, :config($cfg));
      expect($rendered).to.eq("<pre>&#x000A;  hello&#x000A;  world&#x000A;</pre>\n");
    }
  }
}
