
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
  method message {
    self.loc ~ " failed to evaluate `$!code`" ~ ($!reason ?? ": $!reason" !! '') ~ self.caret
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

=begin pod

=head1 NAME

Template::HAML::X - exception hierarchy

=head1 EXCEPTIONS

All exceptions inherit from C<X::HAML> and carry C<:line>, C<:column>,
C<:file>, and C<:snippet> attributes.  Their C<message> includes a
caret-pointer snippet showing the offending source location.

=item C<X::HAML::ParseFail> - generic grammar parse failure.
=item C<X::HAML::IllegalIndent> - indentation that breaks structural rules.
=item C<X::HAML::IndentMixed> - tabs and spaces mixed in one indent.
=item C<X::HAML::IndentInconsistent> - indent is not a multiple of the detected unit.
=item C<X::HAML::DuplicateId> - duplicate C<id> attributes (legacy; current renderer concatenates).
=item C<X::HAML::VoidWithChildren> - void element used with children.
=item C<X::HAML::UnknownDoctype> - C<!!!> with an unknown variant.
=item C<X::HAML::DoctypeNotFirst> - C<!!!> not the first non-blank line.
=item C<X::HAML::Eval> - embedded code evaluation failed.
=item C<X::HAML::UnbalancedExpression> - multi-line expression never closed.
=item C<X::HAML::OrphanElse> - C<- else>/C<- elsif> with no preceding C<- if>.
=item C<X::HAML::UnknownFilter> - unknown filter name.
=item C<X::HAML::TemplateNotFound> - partial/layout not found in search paths.
=item C<X::HAML::PartialDepthExceeded> - recursive partial depth limit reached.
=item C<X::HAML::YieldOutsideLayout> - C<yield> called outside a layout render.

=end pod
