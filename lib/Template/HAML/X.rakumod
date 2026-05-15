
class X::HAML is Exception {
  has Int $.line;
  has Int $.column;
  has Str $.file;
  has Str $.snippet;

  method loc {
    '[HAML ' ~ ($!file // 'source') ~ ':' ~ ($!line // '?') ~ ':' ~ ($!column // '?') ~ ']';
  }

  method caret(--> Str) {
    return '' unless $!snippet.defined && $!snippet.chars;
    my $line-no = ($!line // 0).Str;
    my $gutter  = ' ' x $line-no.chars;
    my $col     = ($!column // 1) max 1;
    my $pointer = (' ' x ($col - 1)) ~ '^';
    "\n  $line-no | $!snippet\n  $gutter | $pointer";
  }
}

class X::HAML::IllegalIndent is X::HAML {
  method message { self.loc ~ ' illegal indentation' ~ self.caret }
}

class X::HAML::IndentMixed is X::HAML {
  method message { self.loc ~ ' mixed tabs and spaces in indent' ~ self.caret }
}

class X::HAML::IndentInconsistent is X::HAML {
  has Int $.unit;
  has Int $.got;
  method message {
    self.loc ~ " indent of $!got chars, expected a multiple of $!unit" ~ self.caret
  }
}

class X::HAML::DuplicateId is X::HAML {
  method message { self.loc ~ ' duplicate id attribute' ~ self.caret }
}

class X::HAML::VoidWithChildren is X::HAML {
  has Str $.name;
  method message { self.loc ~ " void element <$!name> cannot have children" ~ self.caret }
}

class X::HAML::ParseFail is X::HAML {
  method message {
    self.loc ~ ' parse failed' ~ self.caret
  }
}

class X::HAML::UnknownDoctype is X::HAML {
  has Str $.arg;
  method message {
    self.loc ~ " unknown doctype '$!arg'; expected one of: 5 1.1 Strict Frameset Mobile RDFa Basic XML" ~ self.caret
  }
}

class X::HAML::DoctypeNotFirst is X::HAML {
  method message {
    self.loc ~ ' doctype must be the first non-blank line of the template' ~ self.caret
  }
}

class X::HAML::Eval is X::HAML {
  has Str $.code;
  has Str $.reason;
  has Str $.block-source;
  has Int $.block-line;

  method trace-block(--> Str) {
    return '' unless $!block-source.defined && $!block-source.chars;
    my @src-lines = $!block-source.lines;
    my $width = @src-lines.elems.Str.chars;
    my @rendered = @src-lines.kv.map(-> $i, $l {
      my $no = ($i + 1).fmt('%' ~ $width ~ 'd');
      "    $no | $l"
    });
    my $header   = "\n  compiled block";
    my $tpl-line = self.line // '?';
    my $arrow    = '';
    if $!block-line.defined && $!block-line >= 1 && $!block-line <= @src-lines.elems {
      $arrow = " (template line $tpl-line → block line $!block-line)";
    }
    $header ~ $arrow ~ ":\n" ~ @rendered.join("\n");
  }

  method message {
    self.loc
      ~ " failed to evaluate `$!code`"
      ~ ($!reason ?? ": $!reason" !! '')
      ~ self.caret
      ~ self.trace-block
  }
}

class X::HAML::UnbalancedExpression is X::HAML {
  has Str $.code;
  method message {
    self.loc ~ " expression spans end of input without balancing: `$!code`" ~ self.caret
  }
}

class X::HAML::OrphanElse is X::HAML {
  has Str $.kind;
  method message {
    self.loc ~ " '$!kind' has no preceding 'if' or 'unless'" ~ self.caret
  }
}

class X::HAML::UnknownFilter is X::HAML {
  has Str $.name;
  method message {
    self.loc ~ " unknown filter ':$!name'" ~ self.caret
  }
}

class X::HAML::MarkdownBackendMissing is X::HAML {
  method message {
    self.loc
      ~ " no markdown backend registered;"
      ~ " call register-markdown-backend(:&handler) before rendering a :markdown filter"
      ~ self.caret
  }
}

class X::HAML::InvalidEncoding is X::HAML {
  has Str $.name;
  method message {
    self.loc ~ " unknown encoding '$!name'"
  }
}

class X::HAML::EncodingError is X::HAML {
  has Str $.encoding;
  has Str $.reason;
  method message {
    self.loc
      ~ " input is not valid $!encoding"
      ~ ($!reason ?? ": $!reason" !! '')
  }
}

class X::HAML::TemplateNotFound is X::HAML {
  has Str $.name;
  has @.search-paths;
  method message {
    my $paths = @!search-paths.elems
      ?? @!search-paths.join(', ')
      !! '(no search paths configured)';
    self.loc ~ " template '$!name' not found in: $paths"
  }
}

class X::HAML::PartialDepthExceeded is X::HAML {
  has Str $.name;
  has Int $.limit;
  method message {
    self.loc ~ " partial '$!name' exceeded recursion depth $!limit"
  }
}

class X::HAML::YieldOutsideLayout is X::HAML {
  method message {
    self.loc ~ ' yield() called outside of a layout rendering context'
  }
}

class X::IllegalIndent is X::HAML::IllegalIndent { }
class X::DuplicateId  is X::HAML::DuplicateId   { }

sub illegal-indent(Int :$line, Int :$column, Str :$file, Str :$snippet) is export {
  die X::HAML::IllegalIndent.new(:$line, :$column, :$file, :$snippet);
}

sub duplicate-id(Int :$line, Int :$column, Str :$file, Str :$snippet) is export {
  die X::HAML::DuplicateId.new(:$line, :$column, :$file, :$snippet);
}

sub indent-mixed(Int :$line, Int :$column, Str :$file, Str :$snippet) is export {
  die X::HAML::IndentMixed.new(:$line, :$column, :$file, :$snippet);
}

sub indent-inconsistent(Int :$line, Int :$column, Str :$file, Int :$unit, Int :$got, Str :$snippet) is export {
  die X::HAML::IndentInconsistent.new(:$line, :$column, :$file, :$unit, :$got, :$snippet);
}

sub haml-debug(*@msg) is export {
  return unless ?%*ENV<HAML_DEBUG>;
  note '[HAML DEBUG] ', @msg.map(*.gist).join(' ');
}
