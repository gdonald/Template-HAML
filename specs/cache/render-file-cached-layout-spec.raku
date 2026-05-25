use lib 'lib', 'specs/lib';
use BDD::Behave;
use SpecHelpers;
use Template::HAML;
use Template::HAML::Cache;
use Template::HAML::Config;

sub views-and-layouts(IO::Path $dir) {
  my $views   = $dir.add('views');
  my $layouts = $views.add('layouts');
  $views.mkdir;
  $layouts.mkdir;
  ($views, $layouts);
}

describe 'render-file-cached with :layout', {
  context 'basic layout rendering', {
    my ($haml, $views, $out);

    before-each {
      my $dir = fresh-dir;
      my ($v, $layouts) = views-and-layouts($dir);
      $views = $v;

      $views.add('inner.html.haml').spurt("%h1 Inner\n");
      $layouts.add('app.html.haml').spurt(q:to/END/);
      %html
        %body
          = yield
      END

      $haml = HAML.new(
        :compiled-cache-dir($dir.add('cache')),
        :search-paths($views.absolute),
      );

      $out = $haml.render-file-cached(:file<inner>, :layout<layouts/app>);
    }

    it 'matches interpreter output', {
      my $plain = HAML.new(:search-paths($views.absolute)).render(
        :file<inner>, :layout<layouts/app>,
      );
      expect($out).to.be($plain);
    }

    it 'includes the layout html tag', {
      expect($out).to.match(/'<html>'/);
    }

    it 'includes the layout body tag', {
      expect($out).to.match(/'<body>'/);
    }

    it 'yields the inner content into the layout', {
      expect($out).to.match(/'<h1>Inner</h1>'/);
    }
  }

  context 'fn memoization across calls', {
    my ($haml, $size-after-first);

    before-each {
      my $dir = fresh-dir;
      my ($views, $layouts) = views-and-layouts($dir);

      $views.add('home.html.haml').spurt("%p home\n");
      $layouts.add('app.html.haml').spurt("%body\n  = yield\n");

      $haml = HAML.new(
        :compiled-cache-dir($dir.add('cache')),
        :search-paths($views.absolute),
      );
      $haml.clear-compiled-fn-cache;

      $haml.render-file-cached(:file<home>, :layout<layouts/app>);
      $size-after-first = $haml.compiled-fn-cache-size;
    }

    it 'memoizes one fn per template (inner + layout)', {
      expect($size-after-first).to.be(2);
    }

    it 'does not grow on a second identical render', {
      $haml.render-file-cached(:file<home>, :layout<layouts/app>);
      expect($haml.compiled-fn-cache-size).to.be($size-after-first);
    }
  }

  context 'inner file edit invalidates inner cache only', {
    my ($haml, $page, $first, $second);

    before-each {
      my $dir = fresh-dir;
      my ($views, $layouts) = views-and-layouts($dir);

      $page = $views.add('page.html.haml');
      $page.spurt("%p one\n");
      $layouts.add('app.html.haml').spurt("%body\n  = yield\n");

      $haml = HAML.new(
        :compiled-cache-dir($dir.add('cache')),
        :search-paths($views.absolute),
      );

      $first = $haml.render-file-cached(:file<page>, :layout<layouts/app>);
      sleep 1.1;
      $page.spurt("%p two\n");
      $second = $haml.render-file-cached(:file<page>, :layout<layouts/app>);
    }

    it 'returns the initial inner on the first render', {
      expect($first).to.match(/'<p>one</p>'/);
    }

    it 'returns the edited inner on the next render', {
      expect($second).to.match(/'<p>two</p>'/);
    }
  }

  context 'layout file edit invalidates layout cache only', {
    my ($haml, $lay, $first, $second);

    before-each {
      my $dir = fresh-dir;
      my ($views, $layouts) = views-and-layouts($dir);

      $views.add('inner.html.haml').spurt("%h1 hi\n");
      $lay = $layouts.add('app.html.haml');
      $lay.spurt("%body\n  = yield\n");

      $haml = HAML.new(
        :compiled-cache-dir($dir.add('cache')),
        :search-paths($views.absolute),
      );

      $first = $haml.render-file-cached(:file<inner>, :layout<layouts/app>);
      sleep 1.1;
      $lay.spurt("%main\n  = yield\n");
      $second = $haml.render-file-cached(:file<inner>, :layout<layouts/app>);
    }

    it 'uses the original layout tag on the first render', {
      expect($first).to.match(/'<body>'/);
    }

    it 'uses the edited layout tag on the next render', {
      expect($second).to.match(/'<main>'/);
    }
  }

  context 'named yields through cached layouts', {
    my ($out);

    before-each {
      my $dir = fresh-dir;
      my ($views, $layouts) = views-and-layouts($dir);

      $layouts.add('named.html.haml').spurt(q:to/END/);
      %html
        %head
          %title
            != yield(:name<title>)
        %body
          = yield
      END
      $views.add('with-title.html.haml').spurt(q:to/END/);
      - content-for('title', { 'My Page' })
      %p Body content
      END

      my $haml = HAML.new(
        :compiled-cache-dir($dir.add('cache')),
        :search-paths($views.absolute),
      );

      $out = $haml.render-file-cached(:file<with-title>, :layout<layouts/named>);
    }

    it 'fills the named yield from content-for', {
      expect($out).to.match(/'My Page'/);
    }

    it 'still fills the default yield from the page body', {
      expect($out).to.match(/'<p>Body content</p>'/);
    }
  }

  context 'no :layout passed', {
    it 'still produces the inner template output', {
      my $dir = fresh-dir;
      my ($views, $layouts) = views-and-layouts($dir);

      $views.add('plain.html.haml').spurt("%p plain\n");

      my $haml = HAML.new(
        :compiled-cache-dir($dir.add('cache')),
        :search-paths($views.absolute),
      );

      expect($haml.render-file-cached(:file<plain>)).to.be("<p>plain</p>\n");
    }
  }
};
