use lib 'lib', 'specs/lib';
use BDD::Behave;
use SpecHelpers;
use Template::HAML;
use Template::HAML::HelpersRole;

class SiteContext does Template::HAML::HelpersRole {
  has $.name;
  method site-name { $!name }
}

class GreetContext does Template::HAML::HelpersRole {
  has $.who;
  method greeting { "Hello, $!who" }
}

sub views-and-layouts(IO::Path $dir) {
  my $views   = $dir.add('views');
  my $layouts = $views.add('layouts');
  $views.mkdir;
  $layouts.mkdir;
  ($views, $layouts);
}

describe 'render-file-cached resolves context helpers', {
  context 'a helper in the inner template and the layout', {
    my ($haml, $views, $out);

    before-each {
      my $dir = fresh-dir;
      my ($v, $layouts) = views-and-layouts($dir);
      $views = $v;

      $views.add('page.html.haml').spurt("%h1= site-name\n");
      $layouts.add('app.html.haml').spurt(qq:to/END/);
      %html
        %head
          %title= site-name
        %body
          = yield
      END

      $haml = HAML.new(
        :compiled-cache-dir($dir.add('cache')),
        :search-paths($views.absolute),
      );

      $out = $haml.render-file-cached(
        :file<page>, :layout<layouts/app>, :context(SiteContext.new(:name('Acme'))),
      );
    }

    it 'calls the helper in the inner template', {
      expect($out).to.match(/'<h1>Acme</h1>'/);
    }

    it 'calls the helper in the layout', {
      expect($out).to.match(/'<title>Acme</title>'/);
    }

    it 'matches the interpreter output', {
      my $plain = HAML.new(:search-paths($views.absolute)).render(
        :file<page>, :layout<layouts/app>, :context(SiteContext.new(:name('Acme'))),
      );
      expect($out).to.be($plain);
    }
  }

  context 'a second identical render reuses the compiled fn', {
    my ($haml, $views);

    before-each {
      my $dir = fresh-dir;
      my ($v, $layouts) = views-and-layouts($dir);
      $views = $v;
      $views.add('page.html.haml').spurt("%h1= site-name\n");
      $layouts.add('app.html.haml').spurt("%body\n  = yield\n");
      $haml = HAML.new(
        :compiled-cache-dir($dir.add('cache')),
        :search-paths($views.absolute),
      );
    }

    it 'gives the same output on both renders', {
      my $first  = $haml.render-file-cached(:file<page>, :layout<layouts/app>, :context(SiteContext.new(:name('One'))));
      my $second = $haml.render-file-cached(:file<page>, :layout<layouts/app>, :context(SiteContext.new(:name('One'))));
      expect($first).to.be($second);
    }
  }

  context 'a template rendered against two contexts with different helper sets', {
    my ($haml, $views);

    before-each {
      my $dir = fresh-dir;
      my ($v, $layouts) = views-and-layouts($dir);
      $views = $v;
      $views.add('site.html.haml').spurt("%h1= site-name\n");
      $views.add('greet.html.haml').spurt("%h1= greeting\n");
      $layouts.add('app.html.haml').spurt("%body\n  = yield\n");
      $haml = HAML.new(
        :compiled-cache-dir($dir.add('cache')),
        :search-paths($views.absolute),
      );
    }

    it 'binds the site helper for the site context', {
      my $out = $haml.render-file-cached(:file<site>, :layout<layouts/app>, :context(SiteContext.new(:name('Acme'))));
      expect($out).to.match(/'<h1>Acme</h1>'/);
    }

    it 'binds the greeting helper for the greet context', {
      my $out = $haml.render-file-cached(:file<greet>, :layout<layouts/app>, :context(GreetContext.new(:who('World'))));
      expect($out).to.match(/'<h1>Hello, World</h1>'/);
    }
  }

  context 'the file cache key factors in the context helper names', {
    my ($haml);

    before-each {
      my $dir = fresh-dir;
      my ($views, $layouts) = views-and-layouts($dir);
      $views.add('page.html.haml').spurt("%h1 hi\n");
      $haml = HAML.new(
        :compiled-cache-dir($dir.add('cache')),
        :search-paths($views.absolute),
      );
    }

    it 'gives different keys for contexts with different helper sets', {
      my $site  = $haml.compiled-cache-key-for-file(:file<page>, :context(SiteContext.new(:name('Acme'))));
      my $greet = $haml.compiled-cache-key-for-file(:file<page>, :context(GreetContext.new(:who('World'))));
      expect($site).to.not.be($greet);
    }

    it 'gives a different key than a render with no context', {
      my $site = $haml.compiled-cache-key-for-file(:file<page>, :context(SiteContext.new(:name('Acme'))));
      my $bare = $haml.compiled-cache-key-for-file(:file<page>);
      expect($site).to.not.be($bare);
    }
  }
};
