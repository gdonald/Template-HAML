use lib 'lib', 'specs/lib';
use BDD::Behave;
use SpecHelpers;
use Template::HAML;
use Template::HAML::Cache;
use Template::HAML::Config;

describe 'Template::HAML fn memoization', {
  context 'initial state', {
    it 'fn cache starts at 0', {
      my $dir  = fresh-dir;
      my $haml = HAML.new(:compiled-cache-dir($dir));
      $haml.clear-compiled-fn-cache;
      expect($haml.compiled-fn-cache-size).to.be(0);
    }
  }

  context 'render-cached growth', {
    it 'adds 1 entry and stays at 1 for the same source', {
      my $dir  = fresh-dir;
      my $haml = HAML.new(:compiled-cache-dir($dir));
      $haml.clear-compiled-fn-cache;
      $haml.render-cached(:src("%p hi\n"));
      expect($haml.compiled-fn-cache-size).to.be(1);
      $haml.render-cached(:src("%p hi\n"));
      expect($haml.compiled-fn-cache-size).to.be(1);
    }

    it 'different src yields distinct fn cache entries', {
      my $dir  = fresh-dir;
      my $haml = HAML.new(:compiled-cache-dir($dir));
      $haml.clear-compiled-fn-cache;
      $haml.render-cached(:src("%p one\n"));
      $haml.render-cached(:src("%p two\n"));
      expect($haml.compiled-fn-cache-size).to.be(2);
    }

    it 'different config yields distinct fn entries', {
      my $dir  = fresh-dir;
      my $haml = HAML.new(:compiled-cache-dir($dir));
      $haml.clear-compiled-fn-cache;
      my $src   = "%br\n";
      my $cfg-a = Template::HAML::Config.new(:format<html5>);
      my $cfg-b = Template::HAML::Config.new(:format<xhtml>);
      $haml.render-cached(:$src, :config($cfg-a));
      $haml.render-cached(:$src, :config($cfg-b));
      expect($haml.compiled-fn-cache-size).to.be(2);
    }
  }

  context 'memoization persistence', {
    it 'second render still works without disk file (fn memoized in-process)', {
      my $dir  = fresh-dir;
      my $haml = HAML.new(:compiled-cache-dir($dir));
      $haml.clear-compiled-fn-cache;
      my $src  = "%p surviving\n";
      my $out1 = $haml.render-cached(:$src);
      my $path = $haml.compiled-cache-path(:$src);
      expect($path.e).to.be-truthy;
      $path.unlink;
      expect($path.e).to.be-falsy;
      my $out2 = $haml.render-cached(:$src);
      expect($out2).to.be($out1);
    }
  }

  context 'clear-compiled-fn-cache', {
    it 'returns count and empties the fn cache', {
      my $dir  = fresh-dir;
      my $haml = HAML.new(:compiled-cache-dir($dir));
      $haml.clear-compiled-fn-cache;
      $haml.render-cached(:src("%p a\n"));
      $haml.render-cached(:src("%p b\n"));
      expect($haml.clear-compiled-fn-cache).to.be(2);
      expect($haml.compiled-fn-cache-size).to.be(0);
    }
  }

  context 'clear-compiled-cache also clears fn cache', {
    it 'fn cache becomes empty after clear-compiled-cache', {
      my $dir  = fresh-dir;
      my $haml = HAML.new(:compiled-cache-dir($dir));
      $haml.clear-compiled-fn-cache;
      $haml.render-cached(:src("%p x\n"));
      expect($haml.compiled-fn-cache-size).to.be(1);
      $haml.clear-compiled-cache;
      expect($haml.compiled-fn-cache-size).to.be(0);
    }
  }

  context 'file-based memoization', {
    it 'render-file-cached populates fn cache and dedupes', {
      my $dir  = fresh-dir;
      my $tpl  = fresh-file($dir, "%p file-memoization\n");
      my $haml = HAML.new(:compiled-cache-dir($dir.add('cache')));
      $haml.clear-compiled-fn-cache;
      $haml.render-file-cached(:file($tpl.absolute));
      expect($haml.compiled-fn-cache-size).to.be(1);
      $haml.render-file-cached(:file($tpl.absolute));
      expect($haml.compiled-fn-cache-size).to.be(1);
    }

    it 'mtime change yields a fresh fn (new key, no stale memo)', {
      my $dir  = fresh-dir;
      my $tpl  = fresh-file($dir, "%p one\n");
      my $haml = HAML.new(:compiled-cache-dir($dir.add('cache')));
      $haml.clear-compiled-fn-cache;
      expect($haml.render-file-cached(:file($tpl.absolute))).to.be("<p>one</p>\n");
      sleep 1.1;
      $tpl.spurt("%p two\n");
      expect($haml.render-file-cached(:file($tpl.absolute))).to.be("<p>two</p>\n");
      expect($haml.compiled-fn-cache-size).to.be(2);
    }
  }

  context 'cross-instance sharing', {
    it 'second instance sees the memoized entry and does not duplicate', {
      my $dir1 = fresh-dir;
      my $dir2 = fresh-dir;
      my $h1   = HAML.new(:compiled-cache-dir($dir1));
      my $h2   = HAML.new(:compiled-cache-dir($dir2));
      $h1.clear-compiled-fn-cache;
      $h1.render-cached(:src("%p shared\n"));
      expect($h2.compiled-fn-cache-size).to.be(1);
      $h2.render-cached(:src("%p shared\n"));
      expect($h2.compiled-fn-cache-size).to.be(1);
    }
  }
}
