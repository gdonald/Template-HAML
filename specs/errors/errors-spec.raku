use lib 'lib', 'specs/lib';
use BDD::Behave;
use SpecHelpers;
use Template::HAML;
use Template::HAML::Config;
use Template::HAML::Eval;
use Template::HAML::X;

describe 'X::HAML base attributes', {
  it 'exposes line, column, file, snippet, loc, and caret', {
    my $e = X::HAML.new(:line(7), :column(3), :file('foo.haml'), :snippet('%bad'));
    expect($e.line).to.be(7);
    expect($e.column).to.be(3);
    expect($e.file).to.be('foo.haml');
    expect($e.snippet).to.be('%bad');
    expect($e.loc).to.be('[HAML foo.haml:7:3]');
    expect($e.caret).to.include('^');
    expect($e.caret).to.include('%bad');
  }
}

describe 'X::HAML subclasses inherit base fields', {
  for X::HAML::ParseFail, X::HAML::IndentMixed, X::HAML::IllegalIndent,
      X::HAML::DuplicateId, X::HAML::DoctypeNotFirst -> $cls {
    it "{$cls.^name} inherits line, column, and snippet", {
      my $e = $cls.new(:line(2), :column(1), :file('a.haml'), :snippet('  bad'));
      expect($e.line).to.be(2);
      expect($e.column).to.be(1);
      expect($e.snippet).to.be('  bad');
    }
  }
}

describe 'X::HAML::IndentInconsistent', {
  it 'exposes unit and got and reports expected multiple in message', {
    my $e = X::HAML::IndentInconsistent.new(
      :line(3), :column(1), :unit(2), :got(3), :snippet('   x'),
    );
    expect($e.unit).to.be(2);
    expect($e.got).to.be(3);
    expect($e.message).to.include('expected a multiple of 2');
    expect($e.message).to.include('^');
  }
}

describe 'parse failures', {
  it 'raises X::HAML on a malformed first line', {
    my $e = catch-it({ HAML.render(:src("\%9bad\n")) });
    expect($e).to.be-a(X::HAML);
    expect($e.line).to.not.be-nil;
    expect($e.column).to.not.be-nil;
  }

  it 'raises X::HAML::ParseFail with snippet on multi-line input', {
    my $src = "\%p hello\n\%9bad\n";
    my $e = catch-it({ HAML.render(:src($src)) });
    expect($e).to.be-a(X::HAML::ParseFail);
    expect($e.message).to.include('parse failed');
    expect($e.snippet).to.not.be-nil;
  }
}

describe 'indentation errors', {
  it 'raises X::HAML::IndentMixed when tabs and spaces are mixed', {
    my $src = "\%p\n  \%a hi\n\t\%b bye\n";
    my $e = catch-it({ HAML.render(:src($src)) });
    expect($e).to.be-a(X::HAML::IndentMixed);
    expect($e.line).to.be(3);
    expect($e.column).to.be(1);
    expect($e.snippet).to.not.be-nil;
  }

  it 'raises X::HAML::IndentInconsistent when indent units do not align', {
    my $src = "\%p\n  \%a hi\n   \%b bye\n";
    my $e = catch-it({ HAML.render(:src($src)) });
    expect($e).to.be-a(X::HAML::IndentInconsistent);
    expect($e.line).to.be(3);
  }
}

describe 'doctype errors', {
  it 'raises X::HAML::DoctypeNotFirst when !!! follows another line', {
    my $src = "\%p hi\n!!! 5\n";
    my $e = catch-it({ HAML.render(:src($src)) });
    expect($e).to.be-a(X::HAML::DoctypeNotFirst);
    expect($e.line).to.be(2);
    expect($e.snippet).to.not.be-nil;
  }

  it 'raises X::HAML::UnknownDoctype on an unrecognised doctype argument', {
    my $e = catch-it({ HAML.render(:src("!!! Bogus\n")) });
    expect($e).to.be-a(X::HAML::UnknownDoctype);
    expect($e.arg).to.be('Bogus');
  }
}

describe 'filter errors', {
  it 'raises X::HAML::UnknownFilter for an unrecognised :filter name', {
    my $e = catch-it({ HAML.render(:src(":nope\n  body\n")) });
    expect($e).to.be-a(X::HAML::UnknownFilter);
    expect($e.name).to.be('nope');
  }
}

describe 'void tag errors', {
  it 'raises X::HAML::VoidWithChildren when a void tag has children', {
    my $src = "\%br\n  \%span hi\n";
    my $e = catch-it({ HAML.render(:src($src)) });
    expect($e).to.be-a(X::HAML::VoidWithChildren);
    expect($e.name).to.be('br');
  }
}

describe 'control flow errors', {
  it 'raises X::HAML::OrphanElse for an unmatched else', {
    my $e = catch-it({ HAML.render(:src("- else\n  \%p hi\n")) });
    expect($e).to.be-a(X::HAML::OrphanElse);
    expect($e.kind).to.be('else');
  }
}

describe 'eval errors', {
  it 'raises X::HAML::Eval with line, column, and captured code', {
    my $e = catch-it({ eval-haml('die "boom"', %(), :line(5), :column(2)) });
    expect($e).to.be-a(X::HAML::Eval);
    expect($e.line).to.be(5);
    expect($e.column).to.be(2);
    expect($e.code).to.not.be-nil;
  }
}

describe 'missing template', {
  it 'raises X::HAML::TemplateNotFound with the requested name', {
    my $haml = HAML.new;
    my $e = catch-it({ $haml.render(:file('does-not-exist')) });
    expect($e).to.be-a(X::HAML::TemplateNotFound);
    expect($e.name).to.be('does-not-exist');
  }
}

describe 'haml-debug', {
  it 'is a no-op when HAML_DEBUG is unset', {
    %*ENV<HAML_DEBUG>:delete;
    expect({ haml-debug('quiet') }).to.not.raise-error;
  }
}
