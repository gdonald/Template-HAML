use lib 'lib', 'specs/lib';
use BDD::Behave;
use CodegenHelpers;
use SpecHelpers;
use Template::HAML;
use Template::HAML::Config;
use Template::HAML::DirectCodegen;
use Template::HAML::X;

describe 'direct-emit line mapping', {
  context 'emitted code structure', {
    it 'output-op statement is wrapped with a template-line CATCH', {
      my $tree = HAML.parse-source(:src("= 1/0\n"));
      my $code = DirectCodegen.new.emit-direct($tree);
      expect($code).to.include('X::HAML::Eval.new(:code');
    }
  }

  context 'inline expression errors', {
    it 'dividing by zero in inline expr throws', {
      my $src = qq[%p first\n= 1/0\n];
      expect({ direct-render($src) }).to.raise-error;
    }

    it 'inline expr error is X::HAML::Eval reporting template line 2', {
      my $src = qq[%p first\n= 1/0\n];
      my $err = catch-it({ direct-render($src) });
      expect($err).to.be-a(X::HAML::Eval);
      expect($err.line).to.be(2);
    }
  }

  context 'silent op errors', {
    it 'silent op error wrapped as X::HAML::Eval and reports line 1', {
      my $src = qq[- die "boom"\n];
      my $err = catch-it({ direct-render($src) });
      expect($err).to.be-a(X::HAML::Eval);
      expect($err.line).to.be(1);
    }
  }

  context 'for-iter errors', {
    it 'bad for-iter wrapped as X::HAML::Eval on line 1', {
      my $src = qq[- for die("oops") -> \$i\n  %p hi\n];
      my $err = catch-it({ direct-render($src) });
      expect($err).to.be-a(X::HAML::Eval);
      expect($err.line).to.be(1);
    }
  }

  context 'if-cond errors', {
    it 'if-cond error reports correct template line', {
      my $src = qq[%p first\n%p second\n- if die("noo")\n  %p inner\n];
      my $err = catch-it({ direct-render($src) });
      expect($err.line).to.be(3);
    }
  }
}
