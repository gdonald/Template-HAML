
use Template::HAML::Config;

unit module Template::HAML::Cache;

constant FNV-OFFSET = 0xcbf29ce484222325;
constant FNV-PRIME  = 0x100000001b3;
constant MASK64     = 0xFFFFFFFFFFFFFFFF;

sub fnv1a64(Str $s --> Int) {
  my Int $h = FNV-OFFSET;
  for $s.encode('utf8').list -> $byte {
    $h = ($h +^ $byte) +& MASK64;
    $h = ($h * FNV-PRIME) +& MASK64;
  }
  $h;
}

sub config-fingerprint(Template::HAML::Config $cfg --> Str) is export {
  return '∅' unless $cfg.defined;
  (
    $cfg.format,
    $cfg.escape-html.Str,
    $cfg.escape-attrs.Str,
    $cfg.output-style,
    $cfg.attr-quote,
    $cfg.encoding,
    $cfg.suppress-eval.Str,
    $cfg.cdata.Str,
    $cfg.mime-type,
    $cfg.hyphenate-data-attrs.Str,
    $cfg.output-indent-width.Str,
    $cfg.remove-whitespace.Str,
    $cfg.trace.Str,
    $cfg.emit,
    $cfg.autoclose.sort.join(','),
    $cfg.preserve.sort.join(','),
  ).join("\x[1F]");
}

sub compute-cache-key(
  Str:D $src,
  Template::HAML::Config $config,
  :@helper-names,
  --> Str
) is export {
  my $material = $src ~ "\x[1E]" ~ config-fingerprint($config) ~ "\x[1D]" ~ @helper-names.join(',');
  my $h        = fnv1a64($material);
  $h.fmt('%016x');
}

sub compute-file-cache-key(
  IO::Path:D $path,
  Numeric:D  $mtime,
  Template::HAML::Config $config,
  :@helper-names,
  --> Str
) is export {
  my $material =
    $path.absolute
    ~ "\x[1F]" ~ $mtime.Str
    ~ "\x[1E]" ~ config-fingerprint($config)
    ~ "\x[1D]" ~ @helper-names.join(',');
  my $h = fnv1a64($material);
  $h.fmt('%016x');
}

sub default-cache-dir(--> IO::Path) is export {
  my $env = %*ENV<HAML_COMPILED_CACHE>;
  return $env.IO if $env.defined && $env.chars;
  my $tmp = $*TMPDIR // '/tmp'.IO;
  $tmp.add('Template-HAML');
}

sub compiled-module-name(Str:D $key --> Str) is export {
  'Template::HAML::Compiled::T' ~ $key;
}

sub cache-path(IO::Path $root, Str $key --> IO::Path) is export {
  $root.add('Template').add('HAML').add('Compiled').add('T' ~ $key ~ '.rakumod');
}

sub ensure-dir(IO::Path $dir) is export {
  return if $dir.e;
  $dir.mkdir;
}

sub write-cache-file(IO::Path $path, Str $contents) is export {
  ensure-dir($path.parent);
  $path.spurt($contents);
}

sub read-cache-file(IO::Path $path --> Str) is export {
  $path.slurp;
}

my @invalidation-listeners;

sub register-invalidation-listener(&cb) is export {
  @invalidation-listeners.push: &cb;
}

sub notify-cache-invalidated() is export {
  for @invalidation-listeners -> &cb { cb(); }
}
