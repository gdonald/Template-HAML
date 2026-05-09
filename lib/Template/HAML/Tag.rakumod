
use Template::HAML::X;

constant @VOID-ELEMENTS = <
  area base br col embed hr img input link meta param source track wbr
>;

class Tag is export {
  has Int  $.indent;
  has Int  $.output-indent-width = 2;
  has Int  $.line;
  has Int  $.column;
  has Str  $.name           is rw;
  has %.params              is rw;
  has Str  $.content;
  has @.classes             of Str;
  has @.ids                 of Str;
  has Bool $.self-close     is rw = False;
  has Bool $.trim-outer     = False;
  has Bool $.trim-inner     = False;
  has Str  $.open;

  submethod BUILD(
    :$!indent, :$!name, :%!params, :$!content,
    :@!classes, :@!ids,
    Bool :$!self-close = False,
    Bool :$!trim-outer = False,
    Bool :$!trim-inner = False,
    Int  :$!output-indent-width = 2,
    Int  :$!line, Int :$!column,
  ) {
    self.merge-shorthands;

    if !$!self-close && self.is-void && $!content.chars == 0 {
      $!self-close = True;
    }

    self.build-open;
  }

  method is-void {
    $!name (elem) @VOID-ELEMENTS;
  }

  method full {
    self.open ~ $!content ~ self.close;
  }

  method build-open {
    my $attrs = self.build-attrs;
    $!open = self.get-indent ~ '<' ~ $!name ~ $attrs ~ '>';
  }

  method close {
    return "\n" if $!self-close;
    '</' ~ $!name ~ '>' ~ "\n";
  }

  method build-attrs {
    my $attrs = %!params.keys.map({ $_ ~ "='" ~ %!params{$_} ~ "'" }).join: ' ';
    $attrs.chars ?? ' ' ~ $attrs !! '';
  }

  method get-indent {
    ' ' x ($!indent * $!output-indent-width);
  }

  method merge-shorthands {
    if @!ids.elems {
      if %!params<id> {
        %!params<id> = (@!ids, %!params<id>).flat.join('_');
      } else {
        %!params<id> = @!ids.join('_');
      }
    }

    if @!classes.elems {
      if %!params<class> {
        my @existing = %!params<class>.split(' ');
        %!params<class> = (|@existing, |@!classes).unique.join(' ');
      } else {
        %!params<class> = @!classes.unique.join(' ');
      }
    }
  }
}
