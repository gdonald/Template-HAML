use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Config;

describe 'HAML.render-supply', {
  context 'default flush boundaries', {
    it 'returns a Supply with one chunk per top-level node', {
      my $src = qq:to/HAML/;
      %section.a
        %h1 One
      %section.b
        %h2 Two
      HAML

      my $supply = HAML.render-supply(:$src);
      expect($supply).to.be-a(Supply);

      my @chunks = $supply.list;
      expect(@chunks.elems).to.be(2);

      my $joined = @chunks.join('');
      my $expected = HAML.render(:$src);
      expect($joined).to.eq($expected);
    }
  }

  context 'locals interpolation', {
    it 'threads locals into chunks', {
      my $src = q:to/HAML/;
      %h1 Hello #{$name}
      %p Welcome
      HAML

      my @chunks = HAML.render-supply(:$src, :locals({:name<World>})).list;
      expect(@chunks.elems).to.be(2);
      expect(@chunks[0]).to.match(/Hello \s+ World/);
      expect(@chunks[1]).to.match(/Welcome/);
    }
  }

  context 'flush-depth=0', {
    it 'emits a single chunk equal to the full render', {
      my $src = qq:to/HAML/;
      %p one
      %p two
      %p three
      HAML

      my @chunks = HAML.render-supply(:$src, :flush-depth(0)).list;
      expect(@chunks.elems).to.be(1);
      expect(@chunks[0]).to.eq(HAML.render(:$src));
    }
  }

  context 'single top-level node', {
    it 'emits a single chunk matching the full render', {
      my $src = qq:to/HAML/;
      %html
        %body
          %h1 Hi
          %p there
      HAML

      my @chunks = HAML.render-supply(:$src).list;
      expect(@chunks.elems).to.be(1);
      expect(@chunks[0]).to.eq(HAML.render(:$src));
    }
  }

  context 'control flow at top level', {
    it 'emits one chunk for an if/else and renders the true branch', {
      my $src = qq:to/HAML/;
      - if \$show
        %p yes
      - else
        %p no
      HAML

      my @chunks = HAML.render-supply(:$src, :locals({:show(True)})).list;
      expect(@chunks.elems).to.be(1);
      expect(@chunks[0]).to.match(/'<p>yes</p>'/);
    }
  }

  context 'context helpers', {
    it 'invokes page-class via expression', {
      my $src = q:to/HAML/;
      %p
        = page-class()
      HAML

      my @chunks = HAML.render-supply(:$src).list;
      expect(@chunks.elems).to.be(1);
      expect(@chunks[0]).to.match(/\w+/);
    }
  }

  context 'instance API', {
    it 'instance render-supply emits two chunks for two top-level nodes', {
      my $haml = HAML.new;
      my $src = "%p one\n%p two\n";
      my @chunks = $haml.render-supply(:$src).list;
      expect(@chunks.elems).to.be(2);
    }
  }
}
