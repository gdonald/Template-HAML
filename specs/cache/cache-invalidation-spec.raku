use lib 'lib', 'specs/lib';
use BDD::Behave;
use SpecHelpers;
use Template::HAML;
use Template::HAML::Cache;
use Template::HAML::Config;

describe 'Template::HAML cache invalidation', {
  context 'file cache key', {
    it 'is stable when file unchanged', {
      my $dir   = fresh-dir;
      my $tpl   = fresh-file($dir, "%p hi\n");
      my $haml  = HAML.new(:compiled-cache-dir($dir.add('cache')));
      my $a     = $haml.compiled-cache-key-for-file(:file($tpl.absolute));
      my $b     = $haml.compiled-cache-key-for-file(:file($tpl.absolute));
      expect($a).to.be($b);
      expect($a.chars).to.be(16);
      expect($a).to.match(/^ <[0..9 a..f]>+ $/);
    }

    it 'mtime change yields a different cache key', {
      my $dir  = fresh-dir;
      my $tpl  = fresh-file($dir, "%p hi\n");
      my $haml = HAML.new(:compiled-cache-dir($dir.add('cache')));
      my $a    = $haml.compiled-cache-key-for-file(:file($tpl.absolute));

      sleep 1.1;
      $tpl.spurt("%p hi\n");
      my $b    = $haml.compiled-cache-key-for-file(:file($tpl.absolute));
      expect($a).to.not.be($b);
    }

    it 'differs across configs', {
      my $dir  = fresh-dir;
      my $tpl  = fresh-file($dir, "%br\n");
      my $h-html5 = HAML.new(
        :compiled-cache-dir($dir.add('cache')),
        :config(Template::HAML::Config.new(:format<html5>)),
      );
      my $h-xhtml = HAML.new(
        :compiled-cache-dir($dir.add('cache')),
        :config(Template::HAML::Config.new(:format<xhtml>)),
      );
      my $a = $h-html5.compiled-cache-key-for-file(:file($tpl.absolute));
      my $b = $h-xhtml.compiled-cache-key-for-file(:file($tpl.absolute));
      expect($a).to.not.be($b);
    }
  }

  context 'compile-file-to-cache', {
    it 'changed source produces a new cache path with different contents', {
      my $dir  = fresh-dir;
      my $tpl  = fresh-file($dir, "%p hi\n");
      my $haml = HAML.new(:compiled-cache-dir($dir.add('cache')));
      my $p1   = $haml.compile-file-to-cache(:file($tpl.absolute));
      expect($p1.e).to.be-truthy;
      my $contents1 = $p1.slurp;

      sleep 1.1;
      $tpl.spurt("%p bye\n");
      my $p2 = $haml.compile-file-to-cache(:file($tpl.absolute));
      expect($p2.absolute).to.not.be($p1.absolute);
      expect($p2.e).to.be-truthy;
      my $contents2 = $p2.slurp;
      expect($contents1).to.not.be($contents2);
    }

    it 'second compile returns same path when file unchanged', {
      my $dir  = fresh-dir;
      my $tpl  = fresh-file($dir, "%p hello\n");
      my $haml = HAML.new(:compiled-cache-dir($dir.add('cache')));
      my $p1   = $haml.compile-file-to-cache(:file($tpl.absolute));
      my $m1   = $p1.modified.Num;
      sleep 1.1;
      my $p2   = $haml.compile-file-to-cache(:file($tpl.absolute));
      expect($p2.absolute).to.be($p1.absolute);
      expect($p2.modified.Num).to.be($m1);
    }
  }

  context 'render-file-cached', {
    it 'matches interpreter output', {
      my $dir  = fresh-dir;
      my $tpl  = fresh-file($dir, "%p\n  = \$name\n");
      my $haml = HAML.new(:compiled-cache-dir($dir.add('cache')));
      my $out  = $haml.render-file-cached(
        :file($tpl.absolute),
        :locals(%(:name<World>)),
      );
      expect($out).to.be(HAML.new.render(:file($tpl.absolute), :locals(%(:name<World>))));
    }

    it 'reflects updated file content after mtime bump', {
      my $dir  = fresh-dir;
      my $tpl  = fresh-file($dir, "%p one\n");
      my $haml = HAML.new(:compiled-cache-dir($dir.add('cache')));
      expect($haml.render-file-cached(:file($tpl.absolute))).to.be("<p>one</p>\n");

      sleep 1.1;
      $tpl.spurt("%p two\n");
      expect($haml.render-file-cached(:file($tpl.absolute))).to.be("<p>two</p>\n");
    }

    it 'resolves bare template name via search-paths', {
      my $dir   = fresh-dir;
      my $views = $dir.add('views');
      $views.mkdir;
      my $tpl   = $views.add('home.haml');
      $tpl.spurt("%p home\n");

      my $haml = HAML.new(
        :compiled-cache-dir($dir.add('cache')),
        :search-paths($views.absolute),
      );
      my $path = $haml.compile-file-to-cache(:file<home>);
      expect($path.e).to.be-truthy;
      expect($haml.render-file-cached(:file<home>)).to.be("<p>home</p>\n");
    }
  }
}
