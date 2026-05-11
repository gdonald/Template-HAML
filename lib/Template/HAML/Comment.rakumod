
class Comment is export {
  has Int  $.indent;
  has Int  $.line;
  has Int  $.column;
  has Int  $.output-indent-width = 2;
  has Str  $.text      = '';
  has Str  $.condition = '';
  has Bool $.silent    = False;
  has Bool $.revealed  = False;

  submethod BUILD(
    Int  :$!indent, Int :$!line, Int :$!column,
    Int  :$!output-indent-width = 2,
    Str  :$!text      = '',
    Str  :$!condition = '',
    Bool :$!silent    = False,
    Bool :$!revealed  = False,
  ) {}

  method get-indent(Int :$offset = 0) {
    my $tab = (try { $*HAML-TAB-OFFSET }) // 0;
    my $level = $!indent - $offset + $tab;
    $level = 0 if $level < 0;
    ' ' x ($level * $!output-indent-width);
  }

  method open-tag(--> Str) {
    return '' if $!silent;
    if $!condition {
      return $!revealed
        ?? "<!--[$!condition]><!-->"
        !! "<!--[$!condition]>";
    }
    '<!--';
  }

  method close-tag(--> Str) {
    return '' if $!silent;
    if $!condition {
      return $!revealed ?? '<!--<![endif]-->' !! '<![endif]-->';
    }
    '-->';
  }
}
