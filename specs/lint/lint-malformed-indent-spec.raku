use lib 'lib', 'specs/lib';
use BDD::Behave;
use CLIRunner;
use Template::HAML::Lint;

sub diags-for(:$src --> List) {
  my $rule   = Template::HAML::Lint::MalformedIndentRule.new;
  my $linter = Template::HAML::Lint::Linter.new(:rules(($rule,)));
  $linter.lint(:$src).list;
}

describe 'MalformedIndentRule', {
  context 'clean source', {
    it 'has no diagnostics', {
      my @d = diags-for(:src("%p hi\n%p there\n"));
      expect(@d.elems).to.be(0);
    }
  }

  context 'trailing whitespace', {
    it 'flags trailing spaces with rule/line/column/message', {
      my @d = diags-for(:src("%p hi   \n"));
      expect(@d.elems).to.be(1);
      expect(@d[0].rule).to.be('malformed-indent');
      expect(@d[0].line).to.be(1);
      expect(@d[0].column).to.be(6);
      expect(@d[0].message).to.match(/'trailing whitespace'/);
    }

    it 'flags trailing tabs', {
      my @d = diags-for(:src("%p hi\t\n"));
      expect(@d.elems).to.be(1);
      expect(@d[0].message).to.match(/'trailing whitespace'/);
    }

    it 'flags multiple trailing-whitespace lines independently', {
      my @d = diags-for(:src("%p a \n%p b  \n%p c\n"));
      expect(@d.elems).to.be(2);
      expect(@d[0].line).to.be(1);
      expect(@d[1].line).to.be(2);
    }
  }

  context 'blank lines', {
    it 'flags an all-whitespace blank line', {
      my @d = diags-for(:src("%p one\n   \n%p two\n"));
      expect(@d.elems).to.be(1);
      expect(@d[0].line).to.be(2);
      expect(@d[0].message).to.match(/'blank line contains whitespace'/);
    }

    it 'does not flag empty blank lines', {
      my @d = diags-for(:src("%p one\n\n%p two\n"));
      expect(@d.elems).to.be(0);
    }
  }

  context 'CLI', {
    it 'flags trailing whitespace with exit 1 and names the rule', {
      my $dir  = $*TMPDIR.add("haml-mi-{$*PID}-{(^999999).pick}");
      $dir.mkdir;
      my $file = $dir.add('messy.haml');
      $file.spurt("%p hi   \n");
      my $r = capture(['lint', $file.Str]);
      expect($r<exit>).to.be(1);
      expect($r<out>).to.match(/'malformed-indent'/);
      $file.unlink;
      $dir.rmdir;
    }
  }
}
