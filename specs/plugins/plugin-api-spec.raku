use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Plugin;
use Template::HAML::Visitor;
use Template::HAML::TagTransformers;
use Template::HAML::Filters;
use Template::HAML::Tag;

sub reset-all() {
  clear-plugins();
  clear-visitors();
  clear-tag-transformers();
  clear-markdown-backend();
}

describe 'Plugin API', {
  context 'defaults', {
    it 'has no plugins installed by default', {
      reset-all();
      expect(installed-plugins().elems).to.be(0);
      expect(installed-plugin-names().elems).to.be(0);
      expect(installed-plugin('any').defined).to.be-falsy;
    }
  }

  context 'Plugin construction', {
    it 'retains :name and reports not installed', {
      reset-all();
      my $p = Template::HAML::Plugin::Plugin.new(:name<minimal>);
      expect($p).to.be-a(Template::HAML::Plugin::Plugin);
      expect($p.name).to.be('minimal');
      expect($p.installed).to.be-falsy;
    }
  }

  context 'visitor-only plugin', {
    it 'install/uninstall registers and removes the visitor', {
      reset-all();
      my $calls = 0;
      my $p = Template::HAML::Plugin::Plugin.new(
        :name<vis-only>,
        :visitors([
          %( :name<rename-b>, :handler(-> $t {
            walk-tree($t, -> $n {
              $n.object.name = 'em' if $n.object ~~ Tag && $n.object.name eq 'b';
            });
            $calls++;
            $t;
          }) ),
        ]),
      );

      install-plugin($p);
      expect($p.installed).to.be-truthy;
      expect(has-visitor('rename-b')).to.be-truthy;
      expect(installed-plugin-names().elems).to.be(1);
      expect(installed-plugin-names()[0]).to.be('vis-only');
      expect(installed-plugin('vis-only') === $p).to.be-truthy;

      expect(HAML.render(:src("%b strong\n"))).to.eq("<em>strong</em>\n");
      expect($calls).to.be(1);

      install-plugin($p);
      expect(installed-plugin-names().elems).to.be(1);

      uninstall-plugin($p);
      expect($p.installed).to.be-falsy;
      expect(has-visitor('rename-b')).to.be-falsy;
      expect(installed-plugin-names().elems).to.be(0);

      uninstall-plugin($p);
      expect($p.installed).to.be-falsy;
    }
  }

  context 'tag-transformer plugin', {
    it 'install/uninstall registers and removes the transformer', {
      reset-all();
      my $p = Template::HAML::Plugin::Plugin.new(
        :name<card-plugin>,
        :tag-transformers([
          %( :name<card>, :handler(-> $n {
            $n.object.name = 'div';
            $n.object.attrs.push: 'class' => 'card';
            $n;
          }) ),
        ]),
      );

      install-plugin($p);
      expect(has-tag-transformer('card')).to.be-truthy;
      expect(HAML.render(:src("%card hi\n"))).to.eq(qq{<div class='card'>hi</div>\n});

      uninstall-plugin($p);
      expect(has-tag-transformer('card')).to.be-falsy;
      expect(HAML.render(:src("%p hi\n"))).to.eq("<p>hi</p>\n");
    }
  }

  context 'filter plugin', {
    it 'install/uninstall registers and removes the filter', {
      reset-all();
      my $p = Template::HAML::Plugin::Plugin.new(
        :name<filter-plugin>,
        :filters([
          %( :name<upper>, :handler(-> Str $body, %locals --> Str { $body.uc }) ),
        ]),
      );

      install-plugin($p);
      expect(has-filter('upper')).to.be-truthy;
      expect(HAML.render(:src(":upper\n  hello\n"))).to.eq("HELLO\n");

      uninstall-plugin($p);
      expect(has-filter('upper')).to.be-falsy;
    }
  }

  context 'markdown backend plugin', {
    it 'install/uninstall registers and removes the markdown backend', {
      reset-all();
      my $p = Template::HAML::Plugin::Plugin.new(
        :name<md-plugin>,
        :markdown-backend(-> Str $body --> Str {
          '<MD>' ~ $body ~ '</MD>';
        }),
      );

      install-plugin($p);
      expect(markdown-backend-registered()).to.be-truthy;
      expect(HAML.render(:src(":markdown\n  hi\n"))).to.eq("<MD>hi</MD>\n");

      uninstall-plugin($p);
      expect(markdown-backend-registered()).to.be-falsy;
    }
  }

  context 'combo plugin', {
    it 'composes visitor + transformer + filter and cleans them all up', {
      reset-all();
      my $p = Template::HAML::Plugin::Plugin.new(
        :name<combo>,
        :visitors([
          %( :name<add-class>, :handler(-> $t {
            walk-tree($t, -> $n {
              if $n.object ~~ Tag {
                $n.object.attrs.push: 'class' => 'visited'
                  unless $n.object.attrs.first({ .key eq 'class' });
              }
            });
            $t;
          }) ),
        ]),
        :tag-transformers([
          %( :name<widget>, :handler(-> $n {
            $n.object.name = 'div';
            $n;
          }) ),
        ]),
        :filters([
          %( :name<rev>, :handler(-> Str $body, %locals --> Str { $body.flip }) ),
        ]),
      );

      install-plugin($p);
      expect(HAML.render(:src("%widget hi\n"))).to.eq(
        qq{<div class='visited'>hi</div>\n}
      );

      expect(HAML.render(:src(":rev\n  abc\n"))).to.eq("cba\n");

      uninstall-plugin($p);
      expect(has-visitor('add-class')).to.be-falsy;
      expect(has-tag-transformer('widget')).to.be-falsy;
      expect(has-filter('rev')).to.be-falsy;
    }
  }

  context 'multiple plugins and clear-plugins', {
    it 'tracks coexistence and clear-plugins uninstalls each', {
      reset-all();
      my $a = Template::HAML::Plugin::Plugin.new(
        :name<alpha>,
        :tag-transformers([
          %( :name<x>, :handler(-> $n { $n.object.name = 'first'; $n }) ),
        ]),
      );
      my $b = Template::HAML::Plugin::Plugin.new(
        :name<beta>,
        :tag-transformers([
          %( :name<y>, :handler(-> $n { $n.object.name = 'second'; $n }) ),
        ]),
      );

      install-plugin($a);
      install-plugin($b);
      expect(installed-plugin-names().sort.join(',')).to.be('alpha,beta');

      expect(clear-plugins()).to.be(2);
      expect(installed-plugin-names().elems).to.be(0);
      expect(has-tag-transformer('x')).to.be-falsy;
      expect(has-tag-transformer('y')).to.be-falsy;
      expect($a.installed).to.be-falsy;
      expect($b.installed).to.be-falsy;
    }
  }

  context 'invalid plugin entries', {
    it 'rejects visitor entry without :name', {
      reset-all();
      expect({
        Template::HAML::Plugin::Plugin.new(
          :name<bad>,
          :visitors([ %( :handler(-> $t { $t }) ) ]),
        );
      }).to.raise-error;
    }

    it 'rejects tag-transformer entry without :handler', {
      reset-all();
      expect({
        Template::HAML::Plugin::Plugin.new(
          :name<bad>,
          :tag-transformers([ %( :name<oops> ) ]),
        );
      }).to.raise-error;
    }

    it 'rejects filter entry without :name', {
      reset-all();
      expect({
        Template::HAML::Plugin::Plugin.new(
          :name<bad>,
          :filters([ %( :handler(-> Str $b, %l --> Str { $b }) ) ]),
        );
      }).to.raise-error;
    }
  }

  context 'cached/compiled path', {
    it 'plugin hooks run through render-cached', {
      reset-all();
      my $tmp = $*TMPDIR.add('haml-plugin-cache-' ~ $*PID ~ '-' ~ time);
      $tmp.mkdir;

      my $p = Template::HAML::Plugin::Plugin.new(
        :name<cache-card>,
        :tag-transformers([
          %( :name<card>, :handler(-> $n {
            $n.object.name = 'div';
            $n.object.attrs.push: 'class' => 'card';
            $n;
          }) ),
        ]),
      );
      install-plugin($p);

      my $haml = HAML.new(:compiled-cache-dir($tmp));
      expect($haml.render-cached(:src("%card hi\n"))).to.eq(
        qq{<div class='card'>hi</div>\n}
      );
      $haml.clear-compiled-cache;

      uninstall-plugin($p);

      for $tmp.dir(:r) -> $f { $f.unlink if $f.f }
      $tmp.rmdir if $tmp.e;
    }
  }

  context 're-exported lookups', {
    it 'lookup-filter resolves plugin-registered filter and lookup-tag-transformer returns Nil for unknown', {
      reset-all();
      my $p = Template::HAML::Plugin::Plugin.new(
        :name<lookup-test>,
        :filters([
          %( :name<lookup>, :handler(-> Str $b, %l --> Str { 'L:' ~ $b }) ),
        ]),
      );
      install-plugin($p);

      expect(lookup-filter('lookup') ~~ Callable).to.be-truthy;
      expect(lookup-tag-transformer('lookup').^name eq 'Nil').to.be-truthy;

      uninstall-plugin($p);
    }
  }
}
