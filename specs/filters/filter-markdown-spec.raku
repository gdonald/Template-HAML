use lib 'lib', 'specs/lib';
use BDD::Behave;
use SpecHelpers;
use Template::HAML;
use Template::HAML::Filters;
use Template::HAML::X;

sub install-h1-h2-backend() {
  register-markdown-backend :handler(-> Str $body --> Str {
    my @out;
    for $body.lines -> $ln {
      if $ln.starts-with('## ') {
        @out.push: '<h2>' ~ $ln.substr(3) ~ '</h2>';
      } elsif $ln.starts-with('# ') {
        @out.push: '<h1>' ~ $ln.substr(2) ~ '</h1>';
      } elsif $ln.chars == 0 {
        @out.push: '';
      } else {
        @out.push: '<p>' ~ $ln ~ '</p>';
      }
    }
    @out.join("\n");
  });
}

describe ':markdown filter', {
  it 'has :markdown as a registered filter', {
    expect(has-filter('markdown')).to.be-truthy;
  }

  it 'reports no markdown backend by default', {
    clear-markdown-backend();
    expect(markdown-backend-registered()).to.be-falsy;
  }

  it 'raises MarkdownBackendMissing when no backend is registered', {
    clear-markdown-backend();
    expect({ HAML.render(:src(":markdown\n  # heading\n")) }).to.raise-error(X::HAML::MarkdownBackendMissing);
  }

  it 'carries the source line on the backend-missing error', {
    clear-markdown-backend();
    my $err = catch-it({ HAML.render(:src(":markdown\n  # heading\n")) });
    expect($err).to.not.be-nil;
    expect($err).to.be-a(X::HAML::MarkdownBackendMissing);
    expect($err.line).to.be(1);
  }

  it 'reports the backend as registered after register-markdown-backend', {
    install-h1-h2-backend();
    expect(markdown-backend-registered()).to.be-truthy;
    clear-markdown-backend();
  }

  it 'delegates simple markdown to the backend', {
    install-h1-h2-backend();
    expect(HAML.render(:src(":markdown\n  # Hello\n"))).to.eq("<h1>Hello</h1>\n");
    clear-markdown-backend();
  }

  it 'passes multi-line body to the backend whole', {
    install-h1-h2-backend();
    expect(HAML.render(:src(":markdown\n  # Hello\n  ## Sub\n  body text\n"))).to.eq("<h1>Hello</h1>\n<h2>Sub</h2>\n<p>body text</p>\n");
    clear-markdown-backend();
  }

  it 'interpolates before invoking the backend', {
    install-h1-h2-backend();
    expect(HAML.render(:src(":markdown\n  # Hello, #\{\$name}!\n"), :locals(%(name => 'World')))).to.eq("<h1>Hello, World!</h1>\n");
    clear-markdown-backend();
  }

  it 'nested under a tag inherits indent', {
    install-h1-h2-backend();
    expect(HAML.render(:src("%div\n  :markdown\n    # Nested\n"))).to.eq("<div>\n  <h1>Nested</h1>\n</div>\n");
    clear-markdown-backend();
  }

  it 'renders nothing for an empty body', {
    install-h1-h2-backend();
    expect(HAML.render(:src(":markdown\n"))).to.eq("");
    clear-markdown-backend();
  }

  it 'works between sibling tags', {
    install-h1-h2-backend();
    expect(HAML.render(:src("%p before\n:markdown\n  # Mid\n%p after\n"))).to.eq("<p>before</p>\n<h1>Mid</h1>\n<p>after</p>\n");
    clear-markdown-backend();
  }

  it 'clear-markdown-backend returns True when removing an installed backend, False otherwise', {
    install-h1-h2-backend();
    expect(clear-markdown-backend()).to.be-truthy;
    expect(markdown-backend-registered()).to.be-falsy;
    expect(clear-markdown-backend()).to.be-falsy;
  }

  it 'replacement backend is invoked once and its output emitted verbatim', {
    clear-markdown-backend();
    my $calls = 0;
    register-markdown-backend :handler(-> Str $body --> Str {
      $calls++;
      "X:$body";
    });
    expect(HAML.render(:src(":markdown\n  one\n"))).to.eq("X:one\n");
    expect($calls).to.be(1);

    register-markdown-backend :handler(-> Str $body --> Str {
      "Y:" ~ $body.uc;
    });
    expect(HAML.render(:src(":markdown\n  hi\n"))).to.eq("Y:HI\n");
    clear-markdown-backend();
  }

  it 'current-markdown-backend is undefined when none is registered', {
    clear-markdown-backend();
    my $backend = current-markdown-backend();
    expect($backend.defined).to.be-falsy;
  }

  it 'current-markdown-backend returns the registered Callable', {
    register-markdown-backend :handler(-> Str $body --> Str { $body });
    my $backend = current-markdown-backend();
    expect($backend ~~ Callable).to.be-truthy;
    clear-markdown-backend();
  }
}
