use lib 'lib', 'specs/lib';
use BDD::Behave;
use CLIRunner;
use Template::HAML::Format;

sub write-haml(Str:D $content --> Str) {
  my $path = $*TMPDIR.add("haml-fmt-in-{$*PID}-{(^999999).pick}.haml");
  $path.spurt($content);
  $path.Str;
}

my $nl = "\n";

describe 'haml fmt command', {
  context 'fmt --help', {
    it 'exits 0 and lists the command and flags', {
      my $r = capture(['fmt', '--help']);
      expect($r<exit>).to.be(0);
      expect($r<out>).to.match(/'haml fmt'/);
      expect($r<out>).to.match(/'--in-place'/);
      expect($r<out>).to.match(/'--check'/);
    }
  }

  context 'top-level help', {
    it 'mentions fmt', {
      my $r = capture(['help']);
      expect($r<out>).to.match(/'fmt'/);
    }
  }

  context 'missing arguments', {
    it 'fmt without args exits 2 and reports missing file', {
      my $r = capture(['fmt']);
      expect($r<exit>).to.be(2);
      expect($r<err>).to.match(/'missing file argument'/);
    }

    it 'fmt with a non-existent file exits 1', {
      my $r = capture(['fmt', '/no/such/path-haml-test.haml']);
      expect($r<exit>).to.be(1);
      expect($r<err>).to.match(/'file not found'/);
    }
  }

  context 'fmt basic output', {
    it 'prints canonical output for a simple file', {
      my $path = write-haml('%p hello' ~ $nl);
      my $r = capture(['fmt', $path]);
      expect($r<exit>).to.be(0);
      expect($r<out>).to.be('%p hello' ~ $nl);
      $path.IO.unlink;
    }

    it 'normalizes HTML-style attrs to brace form', {
      my $path = write-haml(q{%a(href='/about')} ~ $nl);
      my $r = capture(['fmt', $path]);
      expect($r<out>).to.be(q{%a{href: '/about'}} ~ $nl);
      $path.IO.unlink;
    }
  }

  context 'fmt -o', {
    it 'writes canonical output to a file', {
      my $in  = write-haml('%p hi' ~ $nl);
      my $out-path = $*TMPDIR.add("haml-fmt-out-{$*PID}-{(^999999).pick}.haml");
      my $r = capture(['fmt', $in, '-o', $out-path.Str]);
      expect($r<exit>).to.be(0);
      expect($out-path.slurp).to.be('%p hi' ~ $nl);
      $in.IO.unlink;
      $out-path.unlink;
    }
  }

  context 'fmt --in-place', {
    it 'rewrites the file in place', {
      my $path = write-haml('%a(href=\'/\')' ~ $nl);
      my $r = capture(['fmt', '--in-place', $path]);
      expect($r<exit>).to.be(0);
      expect($path.IO.slurp).to.be(q{%a{href: '/'}} ~ $nl);
      $path.IO.unlink;
    }
  }

  context 'fmt --check', {
    it 'returns 0 with no stdout when canonical', {
      my $path = write-haml('%p hi' ~ $nl);
      my $r = capture(['fmt', '--check', $path]);
      expect($r<exit>).to.be(0);
      expect($r<out>).to.be('');
      $path.IO.unlink;
    }

    it 'returns 1 when non-canonical and explains', {
      my $path = write-haml('%a(href=\'/\')' ~ $nl);
      my $r = capture(['fmt', '--check', $path]);
      expect($r<exit>).to.be(1);
      expect($r<err>).to.match(/'not in canonical form'/);
      $path.IO.unlink;
    }
  }

  context 'invalid flag combinations', {
    it '--in-place + -o exits 2', {
      my $path = write-haml('%p hi' ~ $nl);
      my $r = capture(['fmt', '--in-place', '-o', '/tmp/x', $path]);
      expect($r<exit>).to.be(2);
      $path.IO.unlink;
    }
  }

  context 'idempotency', {
    it 'produces identical output on a second pass', {
      my $src = '!!! 5'                                ~ $nl
              ~ '%html'                                ~ $nl
              ~ '  %head'                              ~ $nl
              ~ '    %title= $title'                   ~ $nl
              ~ '  %body'                              ~ $nl
              ~ '    .container'                       ~ $nl
              ~ '      %h1 Welcome'                    ~ $nl
              ~ '      / a comment'                    ~ $nl
              ~ '      - for $x in @items'             ~ $nl
              ~ '        %li= $x'                      ~ $nl;
      my $path = write-haml($src);
      my $once  = capture(['fmt', $path]);
      my $second-in = write-haml($once<out>);
      my $twice = capture(['fmt', $second-in]);
      expect($once<out>).to.be($twice<out>);
      $path.IO.unlink;
      $second-in.IO.unlink;
    }
  }
}
