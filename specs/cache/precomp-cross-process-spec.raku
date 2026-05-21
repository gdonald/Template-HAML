use lib 'lib', 'specs/lib';
use BDD::Behave;
use SpecHelpers;
use Template::HAML;

describe 'precomp cross-process cache', {
  context '.precomp directory', {
    it 'is created after first render-cached', {
      my $dir  = fresh-dir;
      my $haml = HAML.new(:compiled-cache-dir($dir));
      $haml.clear-compiled-fn-cache;
      $haml.render-cached(:src("%p hi\n"));

      my $precomp = $dir.add('.precomp');
      expect($precomp.e && $precomp.d).to.be-truthy;
    }
  }

  context 'cached module layout', {
    it 'cache path is a CompUnit::Repository::FileSystem tree', {
      my $dir  = fresh-dir;
      my $haml = HAML.new(:compiled-cache-dir($dir));
      my $path = $haml.compile-to-cache(:src("%p hello\n"));
      my $key  = $haml.compiled-cache-key(:src("%p hello\n"));

      expect($path.absolute).to.be(
        $dir.add('Template').add('HAML').add('Compiled').add('T' ~ $key ~ '.rakumod').absolute
      );

      my $contents = $path.slurp;
      expect($contents.starts-with('unit module Template::HAML::Compiled::T' ~ $key)).to.be-truthy;
      expect($contents.contains('our sub render') || $contents.contains('our sub haml-render')).to.be-truthy;
    }
  }

  context 'cross-process reuse', {
    it 'subprocess renders same output via cached module', {
      my $dir  = fresh-dir;
      my $haml = HAML.new(:compiled-cache-dir($dir));
      my $src  = "%p\n  Hello, \#\{\$name\}!\n";
      my $first = $haml.render-cached(:$src, :locals(%(:name<World>)));

      my $lib  = $*CWD.add('lib').absolute;
      my $cache-abs = $dir.absolute;
      my $code = qq:to/CHILD/;
        use lib "$lib";
        use Template::HAML;
        my \$haml = HAML.new(:compiled-cache-dir("$cache-abs".IO));
        my \$out  = \$haml.render-cached(:src("%p\\n  Hello, \\\#\\\{\\\$name\\\}!\\n"), :locals(%(:name<World>)));
        print \$out;
        CHILD

      my $proc = run('raku', '-e', $code, :out, :err);
      my $stdout = $proc.out.slurp(:close);
      my $stderr = $proc.err.slurp(:close);
      expect($stdout).to.be($first);
      expect($proc.exitcode).to.be(0);
    }
  }
}
