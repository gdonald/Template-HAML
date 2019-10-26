
use Template::Haml::Lines;

class Compiler is export {
  method compile {
    my @lines = Lines.entries;
    self.compile-line(@lines, 0);
  }

  method compile-line(@lines, $cur) {
    my $closed = False;
    my $current-line = @lines[$cur];
    my $next-line = @lines[$cur + 1];

    my $out = $current-line.open;

    if $next-line {
      if $next-line.indent == $current-line.indent {
        $out ~= $current-line.content;
        $out ~= $current-line.close;
        $closed = True;
        $out ~= self.compile-line(@lines, $cur + 1);
      } else {
        $out ~= "\n";
        $out ~= self.compile-line(@lines, $cur + 1);
      }
    } else {
      $out ~= $current-line.content;
    }

    $out ~= $current-line.close unless $closed;
    $out;
  }
}
