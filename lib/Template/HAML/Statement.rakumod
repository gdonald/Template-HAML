
class Statement is export {
  has Int $.indent;
  has Int $.line;
  has Int $.column;
  has Str $.op;
  has Str $.expr;
  has Str $.kind = 'expression';
  has Str $.loop-var = '';
  has Str $.loop-iter = '';
  has Int $.output-indent-width = 2;

  submethod BUILD(
    Int :$!indent, Str :$!op, Str :$!expr,
    Int :$!line, Int :$!column,
    Str :$!kind = 'expression',
    Str :$!loop-var = '',
    Str :$!loop-iter = '',
    Int :$!output-indent-width = 2,
  ) {}

  method get-indent(Int :$offset = 0) {
    my $tab = (try { $*HAML-TAB-OFFSET }) // 0;
    my $level = $!indent - $offset + $tab;
    $level = 0 if $level < 0;
    ' ' x ($level * $!output-indent-width);
  }

  method silent     { $!op eq '-'                    }
  method escape     { $!op eq '=' || $!op eq '&='   }
  method raw-output { $!op eq '!='                   }
  method outputs    { !self.silent                   }
  method is-control { $!kind ne 'expression'         }
}
