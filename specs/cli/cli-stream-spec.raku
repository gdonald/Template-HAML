use lib 'lib', 'specs/lib';
use BDD::Behave;
use CLIRunner;

sub write-template(Str:D $body --> IO::Path) {
  my $p = $*TMPDIR.add("haml-stream-{$*PID}-{(^999999).pick}.haml");
  $p.spurt($body);
  $p;
}

describe 'haml render --stream', {
  context 'streaming a file', {
    it 'renders all tags to stdout', {
      my $f = write-template("%h1 Title\n%p body\n");
      my $r = capture(['render', '--stream', $f.Str]);
      expect($r<exit>).to.be(0);
      expect($r<out>).to.match(/'<h1>Title</h1>'/);
      expect($r<out>).to.match(/'<p>body</p>'/);
      $f.unlink;
    }
  }

  context 'streaming from stdin', {
    it 'renders source piped on stdin', {
      my $r = capture(['render', '--stream', '-'], :stdin("%p hi\n"));
      expect($r<exit>).to.be(0);
      expect($r<out>).to.match(/'<p>hi</p>'/);
    }
  }

  context 'streaming to a file with -o', {
    it 'writes streamed chunks to the output file', {
      my $f = write-template("%p one\n%p two\n");
      my $out-path = $*TMPDIR.add("haml-stream-out-{$*PID}-{(^999999).pick}.html");
      my $r = capture(['render', '--stream', '-o', $out-path.Str, $f.Str]);
      expect($r<exit>).to.be(0);
      my $content = $out-path.slurp;
      expect($content).to.match(/'<p>one</p>'/);
      expect($content).to.match(/'<p>two</p>'/);
      $f.unlink;
      $out-path.unlink;
    }
  }

  context 'invalid flag combinations', {
    it '--stream + --watch exits 2', {
      my $r = capture(['render', '--stream', '--watch', '-o', 'x.html', 'a.haml']);
      expect($r<exit>).to.be(2);
      expect($r<err>).to.match(/'cannot be combined'/);
    }
  }
}
