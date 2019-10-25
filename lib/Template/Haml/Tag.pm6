
use Template::Haml::X;

class Tag is export {
  has Int $.indent;
  has Str $.name;
  has Str $.sigil;
  has %.params;
  has Str $.content;
  has @.classes of Str;
  has Str $.open;

  submethod BUILD(:$!indent, :$!sigil, :$!name, :%!params, :$!content, :@!classes) {
    given $!sigil {
      when '.' { self.name-to-class }
      when '#' { self.name-to-id }
    }

    self.build-open;
  }

  method full {
    self.open ~ $!content ~ self.close;
  }

  method build-open {
    my $attrs = self.build-attrs;
    $!open = '<' ~ $!name ~ $attrs ~ '>';
  }

  method close {
    '</' ~ $!name ~ '>';
  }

  method build-attrs {
    self.merge-classes;
    my $attrs = %!params.keys.map({ $_ ~ "='" ~ %!params{$_} ~ "'" }).join: ' ';
    $attrs.chars ?? ' ' ~ $attrs !! '';
  }

  method merge-classes {
    return unless @!classes.elems;

    if %!params<class> {
      my $klasses = %!params<class>.split: ' ';
      for @!classes { $klasses ~= ' ' ~ $_ }
      %!params<class> = $klasses.unique;
    } else {
      %!params<class> = @!classes.join: ' ';
    }
  }

  method name-to-class {
    if %!params<class> {
      my $class = %!params<class>.chars ?? ' ' ~ $!name !! $!name;
      %!params<class> ~= $class;
    } else {
      %!params<class> = $!name;
    }

    $!name = 'div';
  }

  method name-to-id {
    duplicate-id if %!params<id>;

    %!params<id> = $!name;
    $!name = 'div';
  }
}
