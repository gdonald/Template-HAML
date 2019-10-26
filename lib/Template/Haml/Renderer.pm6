
use Template::Haml::Lines;

class Renderer is export {
  method render {
    my @lines = Lines.entries;
    self.render-line(@lines, 0);
  }

  method render-line(@lines, $cur) {
    my $closed = False;
    my $current-line = @lines[$cur];
    my $next-line = @lines[$cur + 1];

    my $out = $current-line.open;

    if $next-line {
      if $next-line.indent == $current-line.indent {
        $out ~= $current-line.content;
        $out ~= $current-line.close;
        $closed = True;
        $out ~= self.render-line(@lines, $cur + 1);
      } else {
        $out ~= self.render-line(@lines, $cur + 1);
      }
    } else {
      $out ~= $current-line.content;
    }

    $out ~= $current-line.close unless $closed;

    $out;
  }
}
