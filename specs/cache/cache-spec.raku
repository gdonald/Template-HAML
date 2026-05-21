use lib 'lib', 'specs/lib';
use BDD::Behave;
use SpecHelpers;
use Template::HAML;
use Template::HAML::Cache;
use Template::HAML::Config;

describe 'Template::HAML cache', {
  context 'cache key shape', {
    it 'is stable for identical input', {
      my $a = HAML.new.compiled-cache-key(:src("%p hi\n"));
      my $b = HAML.new.compiled-cache-key(:src("%p hi\n"));
      expect($a).to.be($b);
      expect($a.chars).to.be(16);
      expect($a).to.match(/^ <[0..9 a..f]>+ $/);
    }

    it 'differs for different source', {
      my $a = HAML.new.compiled-cache-key(:src("%p hi\n"));
      my $b = HAML.new.compiled-cache-key(:src("%p bye\n"));
      expect($a).to.not.be($b);
    }

    it 'differs for different config', {
      my $cfg-html5 = Template::HAML::Config.new(:format<html5>);
      my $cfg-xhtml = Template::HAML::Config.new(:format<xhtml>);
      my $a = HAML.new.compiled-cache-key(:src("%br\n"), :config($cfg-html5));
      my $b = HAML.new.compiled-cache-key(:src("%br\n"), :config($cfg-xhtml));
      expect($a).to.not.be($b);
    }
  }

  context 'cache path layout', {
    it 'places file at Template/HAML/Compiled/T<key>.rakumod', {
      my $dir   = fresh-dir;
      my $haml  = HAML.new(:compiled-cache-dir($dir));
      my $key   = $haml.compiled-cache-key(:src("%p hi\n"));
      my $path  = $haml.compiled-cache-path(:src("%p hi\n"));

      expect($path.basename).to.be('T' ~ $key ~ '.rakumod');
      expect($path.parent.absolute).to.be(
        $dir.add('Template').add('HAML').add('Compiled').absolute
      );
      expect($path.absolute.starts-with($dir.absolute)).to.be-truthy;
    }
  }

  context 'compile-to-cache', {
    it 'writes the file with emitted Raku source', {
      my $dir  = fresh-dir;
      my $cfg  = Template::HAML::Config.new(:emit<ast>);
      my $haml = HAML.new(:compiled-cache-dir($dir), :config($cfg));
      my $path = $haml.compile-to-cache(:src("%p hi\n"));
      expect($path.e).to.be-truthy;
      expect($path.s > 0).to.be-truthy;
      my $contents = $path.slurp;
      expect($contents).to.include('Renderer');
      expect($contents).to.include('Tag.new(');
    }

    it 'second compile is a cache hit with unchanged mtime', {
      my $dir  = fresh-dir;
      my $haml = HAML.new(:compiled-cache-dir($dir));
      my $path  = $haml.compile-to-cache(:src("%p hi\n"));
      my $mtime = $path.modified.Num;
      sleep 1.1;
      my $path2 = $haml.compile-to-cache(:src("%p hi\n"));
      expect($path2.absolute).to.be($path.absolute);
      expect($path2.modified.Num).to.be($mtime);
    }
  }

  context 'load-from-cache and render-cached', {
    it 'load-from-cache returns a Code object matching HAML.render', {
      my $dir  = fresh-dir;
      my $haml = HAML.new(:compiled-cache-dir($dir));
      my $path = $haml.compile-to-cache(:src("%p hi\n"));
      my &fn   = $haml.load-from-cache($path);
      expect(&fn).to.be-a(Code);
      expect(fn()).to.be(HAML.render(:src("%p hi\n")));
    }

    it 'render-cached produces expected output', {
      my $dir  = fresh-dir;
      my $haml = HAML.new(:compiled-cache-dir($dir));
      my $out  = $haml.render-cached(:src("= \$name\n"), :locals(%(:name<World>)));
      expect($out).to.be("World\n");
    }

    it 'render-cached matches interpreter on nested tags', {
      my $dir  = fresh-dir;
      my $haml = HAML.new(:compiled-cache-dir($dir));
      my $src  = "%div\n  %p hi\n  %p bye\n";
      expect($haml.render-cached(:$src)).to.be(HAML.render(:$src));
    }
  }

  context 'env override', {
    it 'HAML_COMPILED_CACHE env overrides the default', {
      my $dir = fresh-dir;
      temp %*ENV<HAML_COMPILED_CACHE> = $dir.absolute;
      my $haml = HAML.new;
      expect($haml.compiled-cache-dir.absolute).to.be($dir.absolute);
    }
  }

  context 'clear-compiled-cache', {
    it 'returns count of removed files and empties the cache', {
      my $dir  = fresh-dir;
      my $haml = HAML.new(:compiled-cache-dir($dir));
      $haml.compile-to-cache(:src("%p one\n"));
      $haml.compile-to-cache(:src("%p two\n"));
      $haml.compile-to-cache(:src("%p three\n"));

      my $count = $haml.clear-compiled-cache;
      expect($count).to.be(3);
      expect($haml.compiled-cache-path(:src("%p one\n")).e).to.be-falsy;
    }
  }

  context 'config preservation', {
    it 'cached xhtml render preserves config', {
      my $dir  = fresh-dir;
      my $cfg  = Template::HAML::Config.new(:format<xhtml>);
      my $haml = HAML.new(:compiled-cache-dir($dir), :config($cfg));
      expect($haml.render-cached(:src("%br\n"))).to.be(HAML.render(:src("%br\n"), :config($cfg)));
    }
  }
}
