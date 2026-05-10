
class Statement is export {
  has Int $.indent;
  has Int $.line;
  has Int $.column;
  has Str $.op;
  has Str $.expr;
  has Int $.output-indent-width = 2;

  submethod BUILD(
    Int :$!indent, Str :$!op, Str :$!expr,
    Int :$!line, Int :$!column,
    Int :$!output-indent-width = 2,
  ) {}

  method get-indent { ' ' x ($!indent * $!output-indent-width) }

  method silent     { $!op eq '-'                    }
  method escape     { $!op eq '=' || $!op eq '&='   }
  method raw-output { $!op eq '!='                   }
  method outputs    { !self.silent                   }
}
