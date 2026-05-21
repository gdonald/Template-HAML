use lib 'lib', 'specs/lib';
use BDD::Behave;
use CLIRunner;
use Template::HAML::Lint;

sub diags-for(:$src --> List) {
  my $rule   = Template::HAML::Lint::DeprecatedSyntaxRule.new;
  my $linter = Template::HAML::Lint::Linter.new(:rules(($rule,)));
  $linter.lint(:$src).list;
}

describe 'DeprecatedSyntaxRule', {
  context ':ruby filter', {
    it 'flags a bare :ruby with severity, line, and replacement suggestion', {
      my @d = diags-for(:src(":ruby\n"));
      expect(@d.elems).to.be(1);
      expect(@d[0].rule).to.be('deprecated-syntax');
      expect(@d[0].severity).to.be('warning');
      expect(@d[0].line).to.be(1);
      expect(@d[0].message).to.match(/':ruby'/);
      expect(@d[0].message).to.match(/':raku'/);
    }

    it 'reports the header line, not body lines, and column past indent', {
      my @d = diags-for(:src("%div\n  :ruby\n    say 'hi'\n"));
      expect(@d.elems).to.be(1);
      expect(@d[0].line).to.be(2);
      expect(@d[0].column).to.be(3);
    }
  }

  context 'non-matches', {
    it 'does not flag :raku', {
      my @d = diags-for(:src(":raku\n  say 'ok'\n"));
      expect(@d.elems).to.be(0);
    }

    it 'does not flag text mentioning :ruby', {
      my @d = diags-for(:src("%p contains :ruby word in text\n"));
      expect(@d.elems).to.be(0);
    }
  }

  context 'CLI', {
    it 'flags :ruby with exit 1 and names the rule', {
      my $dir  = $*TMPDIR.add("haml-dep-{$*PID}-{(^999999).pick}");
      $dir.mkdir;
      my $file = $dir.add('legacy.haml');
      $file.spurt("%div\n  :ruby\n    puts 'legacy'\n");
      my $r = capture(['lint', $file.Str]);
      expect($r<exit>).to.be(1);
      expect($r<out>).to.match(/'deprecated-syntax'/);
      $file.unlink;
      $dir.rmdir;
    }
  }
}
