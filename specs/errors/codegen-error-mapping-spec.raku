use lib 'lib', 'specs/lib';
use BDD::Behave;
use SpecHelpers;
use MONKEY-SEE-NO-EVAL;
use Template::HAML;
use Template::HAML::Codegen;
use Template::HAML::Config;
use Template::HAML::X;

sub compile-source(Str $src, Template::HAML::Config :$config) {
  my $code = HAML.compile-source-to-raku(:$src, :$config);
  EVAL $code;
}

describe 'codegen eval error line mapping', {
  it 'maps = statement eval failures to the template line', {
    my $src = "%p first\n= no_such_sub_xyzzy()\n";
    my &fn  = compile-source($src);
    my $err = trap-eval({ fn(%(), :ctx(Nil)) });
    expect($err).to.not.be-nil;
    expect($err.line).to.be(2);
  }

  it 'maps != statement eval failures to the template line', {
    my $src = "%p hi\n%p body\n!= boom_xyzzy()\n";
    my &fn  = compile-source($src);
    my $err = trap-eval({ fn(%(), :ctx(Nil)) });
    expect($err).to.not.be-nil;
    expect($err.line).to.be(3);
  }

  it 'maps &= statement eval failures to the template line', {
    my $src = "\n\n&= boom_xyzzy()\n";
    my &fn  = compile-source($src);
    my $err = trap-eval({ fn(%(), :ctx(Nil)) });
    expect($err).to.not.be-nil;
    expect($err.line).to.be(3);
  }

  it 'maps == interpolation eval failures to the template line', {
    my $src = "%p first\n%p second\n== bad: #\{boom_xyzzy()}\n";
    my &fn  = compile-source($src);
    my $err = trap-eval({ fn(%(), :ctx(Nil)) });
    expect($err).to.not.be-nil;
    expect($err.line).to.be(3);
  }

  it 'maps if-condition eval failures to the template line', {
    my $src = "%p ok\n- if boom_xyzzy()\n  %p inside\n";
    my &fn  = compile-source($src);
    my $err = trap-eval({ fn(%(), :ctx(Nil)) });
    expect($err).to.not.be-nil;
    expect($err.line).to.be(2);
  }

  it 'maps for-iterator eval failures to the template line', {
    my $src = "\n- for boom_xyzzy() -> \$i\n  %li= \$i\n";
    my &fn  = compile-source($src);
    my $err = trap-eval({ fn(%(), :ctx(Nil)) });
    expect($err).to.not.be-nil;
    expect($err.line).to.be(2);
  }

  it 'maps while statement eval failures to the template line', {
    my $src = "%p first\n- while boom_xyzzy()\n  %p loop\n";
    my &fn  = compile-source($src);
    my $err = trap-eval({ fn(%(), :ctx(Nil)) });
    expect($err).to.not.be-nil;
    expect($err.line).to.be(2);
  }

  it 'maps attribute splat eval failures to the template line', {
    my $src = Q[%p ok] ~ "\n" ~ Q[%a{|boom_xyzzy()} link] ~ "\n";
    my &fn  = compile-source($src);
    my $err = trap-eval({ fn(%(), :ctx(Nil)) });
    expect($err).to.not.be-nil;
    expect($err.line).to.be(2);
  }

  it 'maps when clause eval failures to the template line', {
    my $src = "%p ok\n- given 1\n  - when boom_xyzzy()\n    %p inside\n";
    my &fn  = compile-source($src);
    my $err = trap-eval({ fn(%(), :ctx(Nil)) });
    expect($err).to.not.be-nil;
    expect($err.line).to.be(3);
  }

  it 'maps interpolated plain-text eval failures to the template line', {
    my $src = "%p ok\n#\{boom_xyzzy()}\n";
    my &fn  = compile-source($src);
    my $err = trap-eval({ fn(%(), :ctx(Nil)) });
    expect($err).to.not.be-nil;
    expect($err.line).to.be(2);
  }

  it 'maps render-cached eval failures to the template line', {
    my $dir  = fresh-dir;
    my $haml = HAML.new(:compiled-cache-dir($dir));
    my $src  = "%p first\n%p second\n= boom_xyzzy()\n";
    my $err  = trap-eval({ $haml.render-cached(:$src) });
    expect($err).to.not.be-nil;
    expect($err.line).to.be(3);
  }

  it 'maps render-file-cached eval failures to the template line', {
    my $dir  = fresh-dir;
    my $tpl  = fresh-file($dir, "%p first\n%p second\n%p third\n= boom_xyzzy()\n");
    my $haml = HAML.new(:compiled-cache-dir($dir.add('cache')));
    my $err  = trap-eval({ $haml.render-file-cached(:file($tpl.absolute)) });
    expect($err).to.not.be-nil;
    expect($err.line).to.be(4);
  }
}
