use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Config;
use Template::HAML::Cache;

describe 'HAML remove-whitespace', {
  it 'remove-whitespace defaults to False', {
    my $cfg = Template::HAML::Config.new;
    expect($cfg.remove-whitespace).to.be-falsy;
  }

  it 'remove-whitespace strips trailing newline on lone tag', {
    my $cfg = Template::HAML::Config.new(:remove-whitespace);
    expect(HAML.render(:src("%p hi\n"), :config($cfg))).to.eq("<p>hi</p>");
  }

  it 'remove-whitespace eats whitespace between siblings', {
    my $cfg = Template::HAML::Config.new(:remove-whitespace);
    expect(HAML.render(:src("%p first\n%p middle\n%p last\n"), :config($cfg)))
      .to.eq("<p>first</p><p>middle</p><p>last</p>");
  }

  it 'remove-whitespace strips indent inside nested tag', {
    my $cfg = Template::HAML::Config.new(:remove-whitespace);
    expect(HAML.render(:src("%div\n  %p hi\n"), :config($cfg)))
      .to.eq("<div><p>hi</p></div>");
  }

  it 'remove-whitespace strips indent across multiple levels', {
    my $cfg = Template::HAML::Config.new(:remove-whitespace);
    expect(HAML.render(:src("%div\n  %p\n    %span hi\n"), :config($cfg)))
      .to.eq("<div><p><span>hi</span></p></div>");
  }

  it 'remove-whitespace collapses whitespace between plain text and tags', {
    my $cfg = Template::HAML::Config.new(:remove-whitespace);
    expect(HAML.render(:src("%div\n  Hello\n  %p world\n"), :config($cfg)))
      .to.eq("<div>Hello<p>world</p></div>");
  }

  it 'remove-whitespace works with void elements', {
    my $cfg = Template::HAML::Config.new(:remove-whitespace);
    expect(HAML.render(:src("%img\n%img\n%img\n"), :config($cfg)))
      .to.eq("<img><img><img>");
  }

  it 'preserve list overrides inner trim for <pre>', {
    my $cfg = Template::HAML::Config.new(:remove-whitespace);
    expect(HAML.render(:src("%pre\n  Line 1\n  Line 2\n"), :config($cfg)))
      .to.eq("<pre>&#x000A;  Line 1&#x000A;  Line 2&#x000A;</pre>");
  }

  it 'outer trim still applies to preserved tag', {
    my $cfg = Template::HAML::Config.new(:remove-whitespace);
    expect(HAML.render(:src("%div\n  %pre\n    hi\n"), :config($cfg)))
      .to.eq("<div><pre>&#x000A;  hi&#x000A;</pre></div>");
  }

  it 'custom preserve list interacts with remove-whitespace', {
    my $cfg = Template::HAML::Config.new(:remove-whitespace, :preserve(['code']));
    expect(HAML.render(:src("%code\n  x = 1\n  y = 2\n"), :config($cfg)))
      .to.eq("<code>&#x000A;  x = 1&#x000A;  y = 2&#x000A;</code>");
  }

  it 'remove-whitespace works under pretty output-style', {
    my $cfg = Template::HAML::Config.new(:remove-whitespace, :output-style<pretty>);
    expect(HAML.render(:src("%div\n  %p hi\n"), :config($cfg)))
      .to.eq("<div><p>hi</p></div>");
  }

  it 'explicit > modifier coexists with remove-whitespace', {
    my $cfg = Template::HAML::Config.new(:remove-whitespace);
    expect(HAML.render(:src("%p> hi\n%p there\n"), :config($cfg)))
      .to.eq("<p>hi</p><p>there</p>");
  }

  it 'attributes render normally under remove-whitespace', {
    my $cfg = Template::HAML::Config.new(:remove-whitespace);
    expect(HAML.render(:src("%a\{href: '/'\} home\n"), :config($cfg)))
      .to.eq("<a href='/'>home</a>");
  }

  context 'clone-with', {
    it 'preserves remove-whitespace and applies override', {
      my $cfg  = Template::HAML::Config.new(:remove-whitespace);
      my $cfg2 = $cfg.clone-with(:format<xhtml>);
      expect($cfg2.remove-whitespace).to.be-truthy;
      expect($cfg2.format).to.be('xhtml');
    }
  }

  it 'cache key differs when remove-whitespace differs', {
    my $on  = Template::HAML::Config.new(:remove-whitespace);
    my $off = Template::HAML::Config.new;
    expect(compute-cache-key("%p hi\n", $on))
      .to.not.be(compute-cache-key("%p hi\n", $off));
  }

  it 'render-cached honors remove-whitespace', {
    my $cfg = Template::HAML::Config.new(:remove-whitespace);
    my $h   = HAML.new(:config($cfg));
    expect($h.render-cached(:src("%div\n  %p hi\n")))
      .to.eq("<div><p>hi</p></div>");
  }
}
