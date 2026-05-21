use lib 'lib', 'specs/lib';
use BDD::Behave;
use CLIRunner;
use Template::HAML::Lint;

sub diags-for(:$src, :%locals --> List) {
  my $rule   = Template::HAML::Lint::UnusedLocalsRule.new;
  my $linter = Template::HAML::Lint::Linter.new(:rules(($rule,)));
  $linter.lint(:$src, :%locals).list;
}

describe 'UnusedLocalsRule', {
  context 'basic behavior', {
    it 'reports nothing when no locals are passed', {
      my @d = diags-for(:src("%p hi\n"));
      expect(@d.elems).to.be(0);
    }

    it 'reports nothing when a local is used', {
      my @d = diags-for(:src("%p Hello \#\{\$name\}\n"), :locals{ :name<Alice> });
      expect(@d.elems).to.be(0);
    }

    it 'flags a single unused local with rule, severity, and message', {
      my @d = diags-for(:src("%p hi\n"), :locals{ :name<Alice> });
      expect(@d.elems).to.be(1);
      expect(@d[0].rule).to.be('unused-locals');
      expect(@d[0].severity).to.be('warning');
      expect(@d[0].message).to.match(/'$name'/);
    }

    it 'flags each unused local separately', {
      my @d = diags-for(
        :src("%p Hi \#\{\$name\}\n"),
        :locals{ :name<x>, :age(30), :role<admin> },
      );
      expect(@d.elems).to.be(2);
      my @names = @d.map(*.message).sort;
      expect(@names[0] ~~ /'$age'/).to.be-truthy;
      expect(@names[1] ~~ /'$role'/).to.be-truthy;
    }
  }

  context 'usage contexts', {
    it 'counts an expression reference as used', {
      my @d = diags-for(
        :src("= \$total + 1\n"),
        :locals{ :total(42) },
      );
      expect(@d.elems).to.be(0);
    }

    it 'counts a reference inside silent-script as used', {
      my @d = diags-for(
        :src("- my \$x = \$base * 2\n"),
        :locals{ :base(10) },
      );
      expect(@d.elems).to.be(0);
    }

    it 'counts an attribute-hash reference as used', {
      my @d = diags-for(
        :src("%a\{:href(\$url)\} link\n"),
        :locals{ :url('/x') },
      );
      expect(@d.elems).to.be(0);
    }

    it 'respects word boundaries: $foo not satisfied by $foobar', {
      my @d = diags-for(
        :src("%p Hi \#\{\$foobar\}\n"),
        :locals{ :foo(1), :foobar(2) },
      );
      expect(@d.elems).to.be(1);
      expect(@d[0].message).to.match(/'$foo'/);
    }
  }

  context 'CLI', {
    it 'flags unused locals on the CLI and exits clean when all are used', {
      my $dir  = $*TMPDIR.add("haml-ul-{$*PID}-{(^999999).pick}");
      $dir.mkdir;
      my $file = $dir.add('greet.haml');
      $file.spurt("%p Hi \#\{\$name\}\n");

      my $r = capture(['lint', '--locals', 'name,age', $file.Str]);
      expect($r<exit>).to.be(1);
      expect($r<out>).to.match(/'unused-locals'/);
      expect($r<out>).to.match(/'$age'/);

      my $r2 = capture(['lint', '--locals', 'name', $file.Str]);
      expect($r2<exit>).to.be(0);
      expect($r2<out>).to.be('');

      $file.unlink;
      $dir.rmdir;
    }
  }
}
