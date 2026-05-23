use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::X;

sub render-or-fail($src, %locals = %()) {
  my $error;
  try {
    CATCH { when X::HAML::ParseFail { $error = $_; } }
    HAML.render(:$src, :%locals);
  }
  $error;
}

describe 'parse errors for malformed tag attributes', {
  context 'hash-style attrs with unsupported value', {
    it 'raises X::HAML::ParseFail when a value is a Raku variable', {
      my $e = render-or-fail(
        "%meta\{name: 'description', content: \$desc\}\n",
        %(desc => 'D'),
      );
      expect($e).to.be-a(X::HAML::ParseFail);
      expect($e.line).to.eq(1);
      expect($e.column).to.eq(6);
    }

    it 'raises X::HAML::ParseFail on a hyphen bareword key', {
      my $e = render-or-fail("%a\{aria-label: 'home'\} hi\n");
      expect($e).to.be-a(X::HAML::ParseFail);
      expect($e.column).to.eq(3);
    }

    it 'raises X::HAML::ParseFail on colon-pair attrs', {
      my $e = render-or-fail("%a\{:href<x>, :aria-label<home>\} hi\n");
      expect($e).to.be-a(X::HAML::ParseFail);
    }
  }

  context 'html-style attrs with unsupported value', {
    it 'raises X::HAML::ParseFail when a value is a Raku variable', {
      my $src = '%meta(name=' ~ Q['description'] ~ ' content=$desc)' ~ "\n";
      my $e = render-or-fail($src, %(desc => 'D'));
      expect($e).to.be-a(X::HAML::ParseFail);
      expect($e.column).to.eq(6);
    }
  }

  context 'void element with failed attrs', {
    it 'throws instead of emitting </meta>', {
      my $threw  = False;
      my $output = '';
      try {
        CATCH { when X::HAML::ParseFail { $threw = True; } }
        $output = HAML.render(
          :src("%meta\{content: \$desc\}\n"),
          :locals(%(desc => 'D')),
        );
      }
      expect($threw).to.be(True);
      expect($output).to.not.include('</meta>');
    }
  }

  context 'well-formed attrs', {
    it 'parses normal hash-attrs', {
      expect(HAML.render(:src(Q[%a{href: '/'} link] ~ "\n")))
        .to.eq("<a href='/'>link</a>\n");
    }

    it 'parses normal html-style attrs', {
      expect(HAML.render(:src(Q[%a(href='/') link] ~ "\n")))
        .to.eq("<a href='/'>link</a>\n");
    }

    it 'leaves literal { in plain content alone', {
      expect(HAML.render(:src(Q[%p hello { stuff }] ~ "\n")))
        .to.eq(Q[<p>hello { stuff }</p>] ~ "\n");
    }

    it 'accepts an empty hash-attr', {
      expect(HAML.render(:src(Q[%a{} link] ~ "\n")))
        .to.eq("<a>link</a>\n");
    }
  }
}
