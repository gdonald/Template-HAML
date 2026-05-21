use Template::HAML::X;

unit module SpecHelpers;

sub catch-it(&block) is export {
  my $caught;
  {
    CATCH { default { $caught = $_; } }
    block();
  }
  $caught;
}

sub trap-eval(&body) is export {
  try { body(); CATCH { when X::HAML::Eval { return $_ } } }
  Nil;
}

sub fresh-dir(Str :$prefix = 'Template-HAML-spec' --> IO::Path) is export {
  my $base = $*TMPDIR.add(
    "$prefix-{(now.Rat * 1_000_000).Int}-{(^1_000_000).pick}"
  );
  $base.mkdir;
  $base;
}

sub fresh-file(IO::Path $root, Str $body, Str :$ext = 'haml' --> IO::Path) is export {
  my $f = $root.add("tpl-{(^1_000_000).pick}.{$ext}");
  $f.spurt($body);
  $f;
}
