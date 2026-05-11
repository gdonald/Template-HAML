
class Plain is export {
  has Int $.indent;
  has Int $.line;
  has Int $.column;
  has Int $.output-indent-width = 2;
  has Str $.text = '';

  submethod BUILD(
    Int :$!indent, Int :$!line, Int :$!column,
    Int :$!output-indent-width = 2,
    Str :$!text = '',
  ) {}

  method get-indent(Int :$offset = 0) {
    my $tab = (try { $*HAML-TAB-OFFSET }) // 0;
    my $level = $!indent - $offset + $tab;
    $level = 0 if $level < 0;
    ' ' x ($level * $!output-indent-width);
  }
}
