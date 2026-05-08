
class Statement is export {
  has Int $.indent;
  has Int $.line;
  has Int $.column;
  has Str $.op;
  has Str $.expr;

  submethod BUILD(:$!indent, :$!op, :$!expr, Int :$!line, Int :$!column) { }
}
