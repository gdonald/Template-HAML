
class X::HAML is Exception {
  has Int $.line;
  has Int $.column;
  has Str $.file;

  method loc {
    '[HAML ' ~ ($!file // 'source') ~ ':' ~ ($!line // '?') ~ ':' ~ ($!column // '?') ~ ']';
  }
}

class X::HAML::IllegalIndent is X::HAML {
  method message { self.loc ~ ' illegal indentation' }
}

class X::HAML::IndentMixed is X::HAML {
  method message { self.loc ~ ' mixed tabs and spaces in indent' }
}

class X::HAML::IndentInconsistent is X::HAML {
  has Int $.unit;
  has Int $.got;
  method message {
    self.loc ~ " indent of $!got chars, expected a multiple of $!unit"
  }
}

class X::HAML::DuplicateId is X::HAML {
  method message { self.loc ~ ' duplicate id attribute' }
}

class X::HAML::VoidWithChildren is X::HAML {
  has Str $.name;
  method message { self.loc ~ " void element <$!name> cannot have children" }
}

class X::HAML::ParseFail is X::HAML {
  has Str $.snippet;
  method message {
    self.loc ~ ' parse failed' ~ ($!snippet ?? ": near '$!snippet'" !! '')
  }
}

class X::HAML::UnknownDoctype is X::HAML {
  has Str $.arg;
  method message {
    self.loc ~ " unknown doctype '$!arg'; expected one of: 5 1.1 Strict Frameset Mobile RDFa Basic XML"
  }
}

class X::HAML::DoctypeNotFirst is X::HAML {
  method message {
    self.loc ~ ' doctype must be the first non-blank line of the template'
  }
}

class X::IllegalIndent is X::HAML::IllegalIndent { }
class X::DuplicateId  is X::HAML::DuplicateId   { }

sub illegal-indent(Int :$line, Int :$column, Str :$file) is export {
  die X::HAML::IllegalIndent.new(:$line, :$column, :$file);
}

sub duplicate-id(Int :$line, Int :$column, Str :$file) is export {
  die X::HAML::DuplicateId.new(:$line, :$column, :$file);
}

sub indent-mixed(Int :$line, Int :$column, Str :$file) is export {
  die X::HAML::IndentMixed.new(:$line, :$column, :$file);
}

sub indent-inconsistent(Int :$line, Int :$column, Str :$file, Int :$unit, Int :$got) is export {
  die X::HAML::IndentInconsistent.new(:$line, :$column, :$file, :$unit, :$got);
}
