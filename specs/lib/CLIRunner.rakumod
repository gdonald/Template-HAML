use Template::HAML::CLI;

unit module CLIRunner;

sub capture(@args, Str :$stdin --> Hash) is export {
  my $tmp     = $*TMPDIR.add("haml-cli-out-{$*PID}-{(^999999).pick}");
  my $tmp-err = $*TMPDIR.add("haml-cli-err-{$*PID}-{(^999999).pick}");
  my $out = $tmp.open(:w);
  my $err = $tmp-err.open(:w);
  my $exit;
  if $stdin.defined {
    my $tmp-in = $*TMPDIR.add("haml-cli-in-{$*PID}-{(^999999).pick}");
    $tmp-in.spurt($stdin);
    my $in = $tmp-in.open(:r);
    $exit = Template::HAML::CLI::run(@args, :$out, :$err, :$in);
    $in.close;
    $tmp-in.unlink;
  } else {
    $exit = Template::HAML::CLI::run(@args, :$out, :$err);
  }
  $out.close;
  $err.close;
  my $out-text = $tmp.slurp;
  my $err-text = $tmp-err.slurp;
  $tmp.unlink;
  $tmp-err.unlink;
  %( :$exit, :out($out-text), :err($err-text) );
}
