use lib 'lib', 'specs/lib';
use BDD::Behave;
use CLIRunner;
use SpecHelpers;

describe 'haml CLI', {
  context 'help', {
    it 'top-level help exits 0 and lists commands', {
      my $r = capture(['help']);
      expect($r<exit>).to.be(0);
      expect($r<out>).to.match(/'Usage: haml'/);
      expect($r<out>).to.match(/'render'/);
      expect($r<out>).to.match(/'check'/);
    }

    it 'render --help exits 0 and lists options', {
      my $r = capture(['render', '--help']);
      expect($r<exit>).to.be(0);
      expect($r<out>).to.match(/'--locals'/);
      expect($r<out>).to.match(/'--format'/);
    }

    it 'check -h exits 0 and mentions command', {
      my $r = capture(['check', '-h']);
      expect($r<exit>).to.be(0);
      expect($r<out>).to.match(/'haml check'/);
    }
  }

  context 'unknown command', {
    it 'returns non-zero and reports unknown command', {
      my $r = capture(['frobnicate']);
      expect($r<exit>).to.not.be(0);
      expect($r<err>).to.match(/'unknown command'/);
    }
  }

  context 'render from file', {
    it 'renders to stdout', {
      my $dir  = fresh-dir;
      my $file = $dir.add('hello.haml');
      $file.spurt("%p hello\n");
      my $r = capture(['render', $file.Str]);
      expect($r<exit>).to.be(0);
      expect($r<out>.chomp).to.be('<p>hello</p>');
      $file.unlink;
      $dir.rmdir;
    }

    it 'writes to file with -o and leaves stdout empty', {
      my $dir  = fresh-dir;
      my $file = $dir.add('hello.haml');
      my $out  = $dir.add('out.html');
      $file.spurt("%h1 hi\n");
      my $r = capture(['render', $file.Str, '-o', $out.Str]);
      expect($r<exit>).to.be(0);
      expect($r<out>).to.be('');
      expect($out.slurp.chomp).to.be('<h1>hi</h1>');
      $file.unlink;
      $out.unlink;
      $dir.rmdir;
    }
  }

  context 'render --locals', {
    it 'threads locals into rendered output', {
      my $dir  = fresh-dir;
      my $file = $dir.add('locals.haml');
      $file.spurt("%p Hello \#\{\$name\}\n");
      my $r = capture(['render', '--locals', 'name=Alice', $file.Str]);
      expect($r<exit>).to.be(0);
      expect($r<out>.chomp).to.be('<p>Hello Alice</p>');
      $file.unlink;
      $dir.rmdir;
    }
  }

  context 'render --format', {
    it 'distinguishes html5 from xhtml void output', {
      my $dir  = fresh-dir;
      my $file = $dir.add('void.haml');
      $file.spurt("%br\n");
      my $r-html5 = capture(['render', '--format', 'html5', $file.Str]);
      my $r-xhtml = capture(['render', '--format', 'xhtml', $file.Str]);
      expect($r-html5<out>).to.match(/'<br>'/);
      expect($r-xhtml<out>).to.match(/'<br />'/);
      $file.unlink;
      $dir.rmdir;
    }
  }

  context 'render escape flags', {
    it 'escapes html by default and --no-escape-html disables it', {
      my $dir  = fresh-dir;
      my $file = $dir.add('esc.haml');
      $file.spurt("= '<b>'\n");
      my $r-esc   = capture(['render', '--escape-html', $file.Str]);
      my $r-noesc = capture(['render', '--no-escape-html', $file.Str]);
      expect($r-esc<out>).to.match(/'&lt;b&gt;'/);
      expect($r-noesc<out>).to.match(/'<b>'/);
      expect($r-noesc<out>).to.not.match(/'&lt;'/);
      $file.unlink;
      $dir.rmdir;
    }
  }

  context 'render --ugly', {
    it 'removes indentation from rendered output', {
      my $dir  = fresh-dir;
      my $file = $dir.add('ugly.haml');
      $file.spurt("%div\n  %p hi\n");
      my $r = capture(['render', '--ugly', $file.Str]);
      expect($r<exit>).to.be(0);
      expect($r<out>).to.not.match(/\n \s+ '<p>'/);
      $file.unlink;
      $dir.rmdir;
    }
  }

  context 'missing file', {
    it 'returns non-zero and reports not found', {
      my $r = capture(['render', 'does-not-exist.haml']);
      expect($r<exit>).to.not.be(0);
      expect($r<err>).to.match(/'not found'/);
    }
  }

  context 'check command', {
    it 'reports OK on a valid file', {
      my $dir  = fresh-dir;
      my $file = $dir.add('ok.haml');
      $file.spurt("%p ok\n");
      my $r = capture(['check', $file.Str]);
      expect($r<exit>).to.be(0);
      expect($r<out>).to.match(/'OK'/);
      $file.unlink;
      $dir.rmdir;
    }

    it 'returns non-zero on a broken file', {
      my $dir  = fresh-dir;
      my $file = $dir.add('bad.haml');
      $file.spurt("\t %p mixed\n  %p indent\n");
      my $r = capture(['check', $file.Str]);
      expect($r<exit>).to.not.be(0);
      $file.unlink;
      $dir.rmdir;
    }
  }

  context 'unknown option', {
    it 'returns non-zero and reports unknown option', {
      my $r = capture(['render', '--bogus', 'foo']);
      expect($r<exit>).to.not.be(0);
      expect($r<err>).to.match(/'unknown option'/);
    }
  }

  context 'render from stdin', {
    it 'renders source piped on stdin via -', {
      my $r = capture(['render', '-'], :stdin("%p hello\n"));
      expect($r<exit>).to.be(0);
      expect($r<out>.chomp).to.be('<p>hello</p>');
    }

    it 'threads --locals through stdin render', {
      my $r = capture(['render', '--locals', 'name=Bob', '-'],
                      :stdin("%p Hi \#\{\$name\}\n"));
      expect($r<exit>).to.be(0);
      expect($r<out>.chomp).to.be('<p>Hi Bob</p>');
    }

    it 'writes stdin render to -o file', {
      my $dir = fresh-dir;
      my $out = $dir.add('stdin-out.html');
      my $r = capture(['render', '-', '-o', $out.Str], :stdin("%h2 stdin\n"));
      expect($r<exit>).to.be(0);
      expect($out.slurp.chomp).to.be('<h2>stdin</h2>');
      $out.unlink;
      $dir.rmdir;
    }

    it 'reports parse errors with <stdin> label', {
      my $r = capture(['render', '-'], :stdin("\t %p mixed\n  %p indent\n"));
      expect($r<exit>).to.not.be(0);
      expect($r<err>).to.match(/'<stdin>'/);
    }

    it "rejects two '-' positionals", {
      my $r = capture(['render', '-', '-'], :stdin("%p ok\n"));
      expect($r<exit>).to.not.be(0);
      expect($r<err>).to.match(/"at most once"/);
    }

    it 'render --help mentions standard input', {
      my $r = capture(['render', '--help']);
      expect($r<out>).to.match(/"standard input"/);
    }
  }
}
