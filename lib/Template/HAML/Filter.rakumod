
class Filter is export {
  has Int $.indent;
  has Int $.line;
  has Int $.column;
  has Int $.output-indent-width = 2;
  has Str $.name = '';
  has Str $.body = '';

  submethod BUILD(
    Int :$!indent, Int :$!line, Int :$!column,
    Int :$!output-indent-width = 2,
    Str :$!name = '',
    Str :$!body = '',
  ) {}

  method get-indent(Int :$offset = 0) {
    my $level = $!indent - $offset;
    $level = 0 if $level < 0;
    ' ' x ($level * $!output-indent-width);
  }
}
