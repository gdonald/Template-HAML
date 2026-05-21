use lib 'lib', 'specs/lib';
use BDD::Behave;
use CLIRunner;
use SpecHelpers;
use Template::HAML::CLI;
use Template::HAML::Watch;

describe 'haml render --watch and globbing', {
  context 'glob-match', {
    it 'matches *.haml against valid names', {
      expect(glob-match('*.haml', 'view.haml')).to.be-truthy;
      expect(glob-match('*.haml', 'a-b_c.haml')).to.be-truthy;
    }

    it 'rejects non-matching extensions', {
      expect(glob-match('*.haml', 'view.txt')).to.be-falsy;
    }

    it '? matches exactly one char', {
      expect(glob-match('view.?aml', 'view.haml')).to.be-truthy;
      expect(glob-match('view.?aml', 'view.heml2')).to.be-falsy;
    }

    it 'backtracks on multiple stars', {
      expect(glob-match('a*b*c', 'azbzbcc')).to.be-truthy;
    }
  }

  context 'expand-inputs', {
    it 'expands a glob to matching .haml files', {
      my $dir = fresh-dir;
      $dir.add('one.haml').spurt("%p one\n");
      $dir.add('two.haml').spurt("%p two\n");
      $dir.add('three.txt').spurt("not haml\n");

      my @hits = Template::HAML::Watch::expand-inputs([$dir.add('*.haml').Str]).list;
      expect(@hits.elems).to.be(2);

      my @sorted = @hits.map(*.basename).sort;
      expect(@sorted.join(',')).to.be('one.haml,two.haml');

      for $dir.dir -> $f { $f.unlink }
      $dir.rmdir;
    }
  }

  context 'render --out-dir', {
    it 'mirrors .haml inputs to .html outputs', {
      my $dir     = fresh-dir;
      my $out-dir = fresh-dir;
      $dir.add('a.haml').spurt("%p a\n");
      $dir.add('b.haml').spurt("%h1 b\n");

      my $r = capture(['render', $dir.add('*.haml').Str, '--out-dir', $out-dir.Str]);
      expect($r<exit>).to.be(0);
      expect($out-dir.add('a.html').slurp.chomp).to.be('<p>a</p>');
      expect($out-dir.add('b.html').slurp.chomp).to.be('<h1>b</h1>');

      for $dir.dir -> $f { $f.unlink }
      $dir.rmdir;
      for $out-dir.dir -> $f { $f.unlink }
      $out-dir.rmdir;
    }

    it 'rejects -o + --out-dir', {
      my $dir = fresh-dir;
      my $f   = $dir.add('x.haml');
      $f.spurt("%p\n");
      my $r = capture(['render', $f.Str, '-o', 'out.html', '--out-dir', $dir.Str]);
      expect($r<exit>).to.not.be(0);
      expect($r<err>).to.match(/'mutually exclusive'/);
      $f.unlink;
      $dir.rmdir;
    }
  }

  context 'render --watch validation', {
    it 'requires -o or --out-dir', {
      my $dir = fresh-dir;
      my $f   = $dir.add('x.haml');
      $f.spurt("%p\n");
      my $r = capture(['render', $f.Str, '--watch']);
      expect($r<exit>).to.not.be(0);
      expect($r<err>).to.match(/'requires -o or --out-dir'/);
      $f.unlink;
      $dir.rmdir;
    }
  }

  context 'render --watch --max-rebuilds 0', {
    it 'exits cleanly after the initial render', {
      my $dir     = fresh-dir;
      my $out-dir = fresh-dir;
      $dir.add('p.haml').spurt("%p hello\n");
      my $r = capture(['render', $dir.add('*.haml').Str, '--out-dir', $out-dir.Str,
                       '--watch', '--poll', '50', '--max-rebuilds', '0']);
      expect($r<exit>).to.be(0);
      expect($out-dir.add('p.html').slurp.chomp).to.be('<p>hello</p>');
      for $dir.dir -> $f { $f.unlink }
      $dir.rmdir;
      for $out-dir.dir -> $f { $f.unlink }
      $out-dir.rmdir;
    }
  }

  context 'polling watcher rebuilds on edit', {
    it 'rebuilds after the source file changes', {
      my $dir     = fresh-dir;
      my $out-dir = fresh-dir;
      my $src     = $dir.add('v.haml');
      $src.spurt("%p one\n");

      my $done = Promise.new;
      my $exit;
      my $err-text = '';
      start {
        my $tmp-err = $*TMPDIR.add("haml-watch-err-{$*PID}-{(^999999).pick}");
        my $err     = $tmp-err.open(:w);
        my $out     = IO::Handle.new(:path('/dev/null'.IO)).open(:w);
        $exit = Template::HAML::CLI::run(
          ['render', $dir.add('*.haml').Str, '--out-dir', $out-dir.Str,
           '--watch', '--poll', '50', '--max-rebuilds', '1'],
          :$out, :$err);
        $out.close;
        $err.close;
        $err-text = $tmp-err.slurp;
        $tmp-err.unlink;
        $done.keep(True);
      }

      sleep 0.2;
      $src.spurt("%p two\n");

      await Promise.anyof($done, Promise.in(8));
      expect($done.status ~~ Kept).to.be-truthy;
      if $done.status ~~ Kept {
        expect($exit).to.be(0);
        expect($out-dir.add('v.html').slurp.chomp).to.be('<p>two</p>');
      }

      for $dir.dir -> $f { $f.unlink }
      $dir.rmdir;
      for $out-dir.dir -> $f { $f.unlink }
      $out-dir.rmdir;
    }
  }

  context 'no matching glob', {
    it 'reports an error', {
      my $dir = fresh-dir;
      my $r = capture(['render', $dir.add('*.haml').Str]);
      expect($r<exit>).to.not.be(0);
      expect($r<err>).to.match(/'matched no files'/);
      $dir.rmdir;
    }
  }

  context 'invalid --poll', {
    it 'reports an error', {
      my $dir = fresh-dir;
      my $f   = $dir.add('x.haml');
      $f.spurt("%p\n");
      my $r = capture(['render', $f.Str, '-o', 'x.html', '--watch', '--poll', 'abc']);
      expect($r<exit>).to.not.be(0);
      expect($r<err>).to.match(/'--poll'/);
      $f.unlink;
      $dir.rmdir;
    }
  }

  context 'stdin + --watch', {
    it 'rejects the combination', {
      my $r = capture(['render', '-', '--watch', '-o', 'x.html']);
      expect($r<exit>).to.not.be(0);
      expect($r<err>).to.match(/'stdin'/);
    }
  }

  context 'render --help', {
    it 'mentions --watch', {
      my $r = capture(['render', '--help']);
      expect($r<out>).to.match(/'--watch'/);
    }
  }
}
