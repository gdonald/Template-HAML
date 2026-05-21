use lib 'lib', 'specs/lib';
use BDD::Behave;
use CLIRunner;
use Template::HAML::Lint;
use Template::HAML::Node;

describe 'Lint skeleton', {
  context 'Diagnostic.format', {
    it 'renders all fields', {
      my $d = Template::HAML::Lint::Diagnostic.new(
        :rule<example>, :severity<warning>,
        :line(3), :column(5),
        :message('something fishy'),
        :path('view.haml'),
      );
      expect($d.format).to.be('view.haml:3:5: warning: something fishy (example)');
    }

    it 'uses <input> when path is undefined and defaults severity to warning', {
      my $d = Template::HAML::Lint::Diagnostic.new(
        :rule<x>, :line(1), :column(1), :message('m'),
      );
      expect($d.format).to.be('<input>:1:1: warning: m (x)');
      expect($d.severity).to.be('warning');
    }
  }

  context 'Linter with no rules', {
    it 'reports nothing on valid source', {
      my $linter = Template::HAML::Lint::Linter.new(:rules(()));
      my @diags  = $linter.lint(:src("%p hi\n"), :path<v.haml>);
      expect(@diags.elems).to.be(0);
    }

    it 'yields one parse-error diagnostic on a parse failure', {
      my $linter = Template::HAML::Lint::Linter.new(:rules(()));
      my @diags  = $linter.lint(:src("\t %p mixed\n  %p indent\n"), :path<bad.haml>);
      expect(@diags.elems).to.be(1);
      expect(@diags[0].rule).to.be('parse-error');
      expect(@diags[0].severity).to.be('error');
      expect(@diags[0].path).to.be('bad.haml');
    }
  }

  context 'custom rule', {
    it 'contributes a diagnostic with rule id and path', {
      my class NoisyRule does Template::HAML::Lint::Rule {
        method id(--> Str) { 'noisy' }
        method check(Node :$tree, Str :$src, :%locals --> List) {
          (Template::HAML::Lint::Diagnostic.new(
            :rule<noisy>, :severity<warning>, :line(1), :column(1),
            :message('hello from the rule'),
          ),).List;
        }
      }
      my $linter = Template::HAML::Lint::Linter.new(:rules((NoisyRule.new,)));
      my @diags  = $linter.lint(:src("%p hi\n"), :path<x.haml>);
      expect(@diags.elems).to.be(1);
      expect(@diags[0].rule).to.be('noisy');
      expect(@diags[0].path).to.be('x.haml');
    }
  }

  context 'rule registry', {
    it 'clears, registers, and clears again', {
      my class CountRule does Template::HAML::Lint::Rule {
        method id(--> Str) { 'count' }
        method check(Node :$tree, Str :$src, :%locals --> List) { () }
      }
      Template::HAML::Lint::clear-rules;
      expect(Template::HAML::Lint::registered-rules.elems).to.be(0);
      Template::HAML::Lint::register-rule(CountRule.new);
      expect(Template::HAML::Lint::registered-rules.elems).to.be(1);
      Template::HAML::Lint::clear-rules;
      expect(Template::HAML::Lint::registered-rules.elems).to.be(0);
    }
  }

  context 'CLI', {
    it 'top-level help lists lint', {
      my $r = capture(['help']);
      expect($r<out>).to.match(/'lint'/);
    }

    it 'lint --help documents usage and exit codes', {
      my $r = capture(['lint', '--help']);
      expect($r<exit>).to.be(0);
      expect($r<out>).to.match(/'Usage: haml lint'/);
      expect($r<out>).to.match(/'Exit codes'/);
    }

    it 'returns 0 with no output on a clean file', {
      Template::HAML::Lint::clear-rules;
      my $dir  = $*TMPDIR.add("haml-lint-{$*PID}-{(^999999).pick}");
      $dir.mkdir;
      my $file = $dir.add('ok.haml');
      $file.spurt("%p ok\n");
      my $r = capture(['lint', $file.Str]);
      expect($r<exit>).to.be(0);
      expect($r<out>).to.be('');
      $file.unlink;
      $dir.rmdir;
    }

    it 'returns 2 when missing args', {
      my $r = capture(['lint']);
      expect($r<exit>).to.be(2);
      expect($r<err>).to.match(/'missing file argument'/);
    }

    it 'reports parse failure on stdin with <stdin> label and parse-error rule', {
      Template::HAML::Lint::clear-rules;
      my $r = capture(['lint', '-'], :stdin("\t %p mixed\n  %p indent\n"));
      expect($r<exit>).to.be(1);
      expect($r<out>).to.match(/'<stdin>'/);
      expect($r<out>).to.match(/'parse-error'/);
    }
  }
}
