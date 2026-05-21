use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Config;
use Template::HAML::X;

my $tmp = $*TMPDIR.add('haml-layouts-spec-' ~ $*PID);
$tmp.mkdir;

sub rm-rf(IO::Path $p) {
  return unless $p.e;
  for $p.dir -> $c {
    $c.d ?? rm-rf($c) !! $c.unlink;
  }
  $p.rmdir;
}

sub spit(Str $rel, Str $body) {
  my $f = $tmp.add($rel);
  $f.dirname.IO.mkdir;
  $f.spurt($body);
  $f.Str;
}

describe 'layouts and partials', {
  context 'resolve-template', {
    it 'resolves a bare name with the .haml extension', {
      spit('foo.haml', "%p hi\n");
      my $haml = HAML.new(:search-paths($tmp.Str));
      my $path = $haml.resolve-template('foo');
      expect($path.IO.basename).to.be('foo.haml');
    }

    it 'resolves a bare name to the .html.haml extension', {
      spit('bar.html.haml', "%p there\n");
      my $haml = HAML.new(:search-paths($tmp.Str));
      my $path = $haml.resolve-template('bar');
      expect($path.IO.basename).to.be('bar.html.haml');
    }
  }

  context 'render :file', {
    it 'renders from a search path', {
      spit('hello.html.haml', "%p hello\n");
      my $haml = HAML.new(:search-paths($tmp.Str));
      my $out  = $haml.render(:file<hello>);
      expect($out).to.match(/'<p>hello</p>'/);
    }

    it 'throws TemplateNotFound for a missing file', {
      my $haml = HAML.new(:search-paths($tmp.Str));
      expect({ $haml.render(:file<nope>) }).to.raise-error(X::HAML::TemplateNotFound);
    }
  }

  context 'render with layout', {
    it 'wraps inner content in the layout', {
      spit('layouts/app.html.haml', q:to/END/);
      %html
        %body
          = yield
      END
      spit('inner.html.haml', "%h1 Inner\n");

      my $haml = HAML.new(:search-paths($tmp.Str));
      my $out  = $haml.render(:file<inner>, :layout<layouts/app>);

      expect($out).to.match(/'<html>'/);
      expect($out).to.match(/'<body>'/);
      expect($out).to.match(/'<h1>Inner</h1>'/);
    }
  }

  context 'content-for / yield :name', {
    it 'fills both named and default yields', {
      spit('layouts/named.html.haml', q:to/END/);
      %html
        %head
          %title
            != yield(:name<title>)
        %body
          = yield
      END
      spit('with-title.html.haml', q:to/END/);
      - content-for('title', { 'My Page' })
      %p Body content
      END

      my $haml = HAML.new(:search-paths($tmp.Str));
      my $out  = $haml.render(:file<with-title>, :layout<layouts/named>);

      expect($out).to.match(/'<title>'/);
      expect($out).to.match(/'My Page'/);
      expect($out).to.match(/'<p>Body content</p>'/);
    }
  }

  context 'render :partial', {
    it 'renders a partial', {
      spit('_header.html.haml', "%h1 Header\n");
      spit('page.html.haml', q:to/END/);
      %div
        != render(:partial<header>)
      END

      my $haml = HAML.new(:search-paths($tmp.Str));
      my $out  = $haml.render(:file<page>);
      expect($out).to.match(/'<h1>Header</h1>'/);
    }

    it 'passes locals into the partial', {
      spit('_greeting.html.haml', q:to/END/);
      %p Hello, #{$name}!
      END
      spit('greet.html.haml', q:to/END/);
      %div
        != render(:partial<greeting>, :locals(%(name => 'World')))
      END

      my $haml = HAML.new(:search-paths($tmp.Str));
      my $out  = $haml.render(:file<greet>);
      expect($out).to.match(/'Hello, World!'/);
    }

    it 'renders a collection with :as', {
      spit('_row.html.haml', q:to/END/);
      %li #{$item}
      END
      spit('list.html.haml', q:to/END/);
      %ul
        != render(:partial<row>, :collection(<a b c>), :as<item>)
      END

      my $haml = HAML.new(:search-paths($tmp.Str));
      my $out  = $haml.render(:file<list>);
      expect($out).to.match(/'<li>a</li>'/);
      expect($out).to.match(/'<li>b</li>'/);
      expect($out).to.match(/'<li>c</li>'/);
    }
  }

  context 'partial recursion depth limit', {
    it 'triggers PartialDepthExceeded on infinite recursion', {
      spit('_loop.html.haml', q:to/END/);
      != render(:partial<loop>)
      END

      my $haml = HAML.new(:search-paths($tmp.Str));
      expect({ $haml.render(:file<loop>) }).to.raise-error(X::HAML::PartialDepthExceeded);
    }
  }

  context 'compile-file cache', {
    it 'returns the cached tree on subsequent calls', {
      my $path = spit('cached.html.haml', "%p cached\n");
      my $haml = HAML.new(:search-paths($tmp.Str));

      my $t1 = $haml.compile-file($path);
      my $t2 = $haml.compile-file($path);
      expect($t1 === $t2).to.be-truthy;

      $haml.clear-cache;
      my $t3 = $haml.compile-file($path);
      expect($t1 === $t3).to.be-falsy;
    }

    it 'produces fresh trees when cache is disabled', {
      my $path = spit('nocache.html.haml', "%p x\n");
      my $haml = HAML.new(:search-paths($tmp.Str), :!cache);
      my $t1 = $haml.compile-file($path);
      my $t2 = $haml.compile-file($path);
      expect($t1 === $t2).to.be-falsy;
    }
  }

  context 'cleanup', {
    it 'removes tmp directory', {
      rm-rf($tmp);
      expect($tmp.e).to.be-falsy;
    }
  }
}
