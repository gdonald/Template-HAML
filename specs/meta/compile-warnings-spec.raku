use lib 'lib';
use BDD::Behave;

sub find-rakumod(IO::Path $dir) {
  gather for $dir.dir {
    when .d                      { .take for find-rakumod($_) }
    when .extension eq 'rakumod' { .take }
  }
}

sub compile-stderr(IO::Path $file) {
  my $proc   = run $*EXECUTABLE, '-Ilib', '-c', $file, :out, :err;
  my $stderr = $proc.err.slurp(:close);
  $proc.out.slurp(:close);

  $stderr;
}

my @lib-rakumod = find-rakumod('lib'.IO).sort;

describe 'compiling each module under lib', {
  for @lib-rakumod -> $file {
    it "prints no warnings for {$file.relative}", {
      expect(compile-stderr($file)).to.be('');
    }
  }
}
