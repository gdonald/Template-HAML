
class Statement is export {
  has Int $.indent;
  has Str $.op;
  has Str $.cond;

  submethod BUILD(:$!indent, :$!op, :$!cond) {

  }
}
