
use MONKEY-SEE-NO-EVAL;

use Template::HAML::Actions;
use Template::HAML::Cache;
use Template::HAML::Codegen;
use Template::HAML::Config;
use Template::HAML::Context;
use Template::HAML::Multiline;
use Template::HAML::Node;
use Template::HAML::Renderer;
use Template::HAML::Grammar;
use Template::HAML::X;

class HAML is export {
  has Template::HAML::Config $.config;
  has @.search-paths is rw;
  has Bool $.cache is rw = True;
  has IO::Path $.compiled-cache-dir is rw;
  has %!compiled-cache;

  submethod BUILD(
    Template::HAML::Config :$config,
    :$search-paths,
    Bool :$cache = True,
    :$compiled-cache-dir,
  ) {
    $!config = $config // Template::HAML::Config.new;
    @!search-paths = do given $search-paths {
      when !.defined { () }
      when Str       { ($search-paths,) }
      default        { $search-paths.list }
    };
    $!cache = $cache;
    $!compiled-cache-dir = do given $compiled-cache-dir {
      when !.defined { default-cache-dir() }
      when IO::Path  { $compiled-cache-dir }
      default        { $compiled-cache-dir.IO }
    };
  }

  multi method render(HAML:U: Str:D :$src!, :%locals, Template::HAML::Config :$config) {
    my $cfg = $config // Template::HAML::Config.new;
    my $ctx = Template::HAML::Context.new(:haml(self.WHAT));
    self!do-render-src($src, %locals, $cfg, $ctx);
  }

  multi method render(HAML:D: Str:D :$src!, :%locals, Template::HAML::Config :$config) {
    my $cfg = $config // $!config // Template::HAML::Config.new;
    my $ctx = Template::HAML::Context.new(:haml(self));
    self!do-render-src($src, %locals, $cfg, $ctx);
  }

  multi method render(
    HAML:D:
    Str:D :$file!,
    :$layout,
    :%locals,
    Template::HAML::Config :$config,
  ) {
    my $cfg  = $config // $!config // Template::HAML::Config.new;
    my $path = self.resolve-template($file);
    my $ctx  = Template::HAML::Context.new(
      :haml(self),
      :current-dir($path.IO.dirname),
    );

    my $src = $path.IO.slurp;
    my $inner = self!do-render-src($src, %locals, $cfg, $ctx);

    return $inner unless $layout.defined;

    my $layout-path = self.resolve-template($layout);
    my $layout-src  = $layout-path.IO.slurp;
    $ctx.yield-content = $inner;
    $ctx.current-dir   = $layout-path.IO.dirname;
    self!do-render-src($layout-src, %locals, $cfg, $ctx);
  }

  method resolve-template(Str:D $name --> Str) {
    my @candidates;
    if $name.IO.is-absolute {
      @candidates.push: $name;
      @candidates.push: $name ~ '.haml';
      @candidates.push: $name ~ '.html.haml';
    } else {
      my @bases = @!search-paths.elems ?? @!search-paths !! ['.'];
      for @bases -> $base {
        my $b = $base.IO;
        @candidates.push: ($b.add($name)).Str;
        @candidates.push: ($b.add($name ~ '.haml')).Str;
        @candidates.push: ($b.add($name ~ '.html.haml')).Str;
        my $dir   = $name.IO.dirname;
        my $bname = $name.IO.basename;
        @candidates.push: ($b.add($dir).add('_' ~ $bname)).Str;
        @candidates.push: ($b.add($dir).add('_' ~ $bname ~ '.haml')).Str;
        @candidates.push: ($b.add($dir).add('_' ~ $bname ~ '.html.haml')).Str;
      }
    }

    for @candidates -> $c {
      return $c if $c.IO.e && $c.IO.f;
    }
    X::HAML::TemplateNotFound.new(
      :line(0), :column(0), :name($name),
      :search-paths(@!search-paths),
    ).throw;
  }

  method !do-render-src(Str:D $src, %locals, Template::HAML::Config $cfg, $ctx) {
    my $tree = self!compile-source($src, $cfg);

    my $*HAML-CTX = $ctx;
    Renderer.new(:%locals, :config($cfg)).render($tree);
  }

  method !compile-source(Str:D $src, Template::HAML::Config $cfg) {
    my $normalized = $src.subst(:global, /\r\n/, "\n").subst(:global, /\r/, "\n");
    my $joined = preprocess-multiline($normalized);

    my $tree = Node.new;
    $tree.add-child(Node.new);
    my $actions = Actions.new(:$tree, :config($cfg));

    my $m = Grammar.parse($joined, :$actions);
    unless $m {
      self!throw-parse-fail($joined, $cfg);
    }
    $actions.tree;
  }

  method !throw-parse-fail(Str:D $joined, Template::HAML::Config $cfg) {
    my $tmp-tree = Node.new;
    $tmp-tree.add-child(Node.new);
    my $tmp-actions = Actions.new(:tree($tmp-tree), :config($cfg));
    my $raw-to = do {
      CATCH { default { 0 } }
      my $partial = Grammar.subparse($joined, :actions($tmp-actions));
      $partial.defined ?? $partial.to !! 0;
    };
    my $pos = (($raw-to // 0) max 0) min $joined.chars;

    my $before  = $joined.substr(0, $pos);
    my $line    = 1 + $before.comb("\n").elems;
    my $last-nl = $before.rindex("\n");
    my $column  = $last-nl.defined ?? $pos - $last-nl !! $pos + 1;

    my @lines   = $joined.lines;
    my $snippet = @lines[$line - 1] // '';

    X::HAML::ParseFail.new(
      :$line, :$column, :$snippet,
    ).throw;
  }

  method compile-file(Str:D $path --> Node) {
    if $!cache {
      my $mtime = $path.IO.modified.Num;
      my $entry = %!compiled-cache{$path};
      if $entry.defined && $entry<mtime> == $mtime {
        return $entry<tree>;
      }
      my $cfg  = $!config // Template::HAML::Config.new;
      my $src  = $path.IO.slurp;
      my $tree = self!compile-source($src, $cfg);
      %!compiled-cache{$path} = { :$mtime, :$tree };
      return $tree;
    }
    my $cfg = $!config // Template::HAML::Config.new;
    self!compile-source($path.IO.slurp, $cfg);
  }

  method render-compiled-file(Str:D $path, %locals --> Str) {
    my $tree = self.compile-file($path);
    my $cfg  = $!config // Template::HAML::Config.new;
    Renderer.new(:%locals, :config($cfg)).render($tree);
  }

  method clear-cache() {
    %!compiled-cache = ();
  }

  multi method compile-source-to-raku(HAML:U: Str:D :$src!, Template::HAML::Config :$config --> Str) {
    my $cfg  = $config // Template::HAML::Config.new;
    my $tree = self!compile-source($src, $cfg);
    Codegen.new(:config($cfg)).emit($tree);
  }

  multi method compile-source-to-raku(HAML:D: Str:D :$src!, Template::HAML::Config :$config --> Str) {
    my $cfg  = $config // $!config // Template::HAML::Config.new;
    my $tree = self!compile-source($src, $cfg);
    Codegen.new(:config($cfg)).emit($tree);
  }

  method compiled-cache-key(Str:D :$src!, Template::HAML::Config :$config --> Str) {
    my $cfg = $config // ($!config // Template::HAML::Config.new);
    compute-cache-key($src, $cfg);
  }

  method compiled-cache-path(Str:D :$src!, Template::HAML::Config :$config --> IO::Path) {
    my $key = self.compiled-cache-key(:$src, :$config);
    cache-path($!compiled-cache-dir, $key);
  }

  method compile-to-cache(Str:D :$src!, Template::HAML::Config :$config --> IO::Path) {
    my $cfg  = $config // ($!config // Template::HAML::Config.new);
    my $path = self.compiled-cache-path(:$src, :config($cfg));
    return $path if $path.e;
    my $code = self.compile-source-to-raku(:$src, :config($cfg));
    write-cache-file($path, $code);
    $path;
  }

  method load-from-cache(IO::Path:D $path --> Code) {
    EVAL read-cache-file($path);
  }

  method render-cached(Str:D :$src!, :%locals, Template::HAML::Config :$config --> Str) {
    my $cfg  = $config // ($!config // Template::HAML::Config.new);
    my $path = self.compile-to-cache(:$src, :config($cfg));
    my &fn   = self.load-from-cache($path);
    my $ctx  = Template::HAML::Context.new(:haml(self.WHAT === HAML ?? self.WHAT !! self));
    fn(%locals, :config($cfg), :$ctx);
  }

  method !resolve-file-for-cache(Str:D $file --> IO::Path) {
    my $resolved = self.resolve-template($file);
    $resolved.IO;
  }

  method compiled-cache-key-for-file(Str:D :$file!, Template::HAML::Config :$config --> Str) {
    my $cfg  = $config // ($!config // Template::HAML::Config.new);
    my $path = self!resolve-file-for-cache($file);
    compute-file-cache-key($path, $path.modified.Num, $cfg);
  }

  method compiled-cache-path-for-file(Str:D :$file!, Template::HAML::Config :$config --> IO::Path) {
    my $key = self.compiled-cache-key-for-file(:$file, :$config);
    cache-path($!compiled-cache-dir, $key);
  }

  method compile-file-to-cache(Str:D :$file!, Template::HAML::Config :$config --> IO::Path) {
    my $cfg  = $config // ($!config // Template::HAML::Config.new);
    my $path = self.compiled-cache-path-for-file(:$file, :config($cfg));
    return $path if $path.e;
    my $src  = self!resolve-file-for-cache($file).slurp;
    my $code = self.compile-source-to-raku(:$src, :config($cfg));
    write-cache-file($path, $code);
    $path;
  }

  method render-file-cached(Str:D :$file!, :%locals, Template::HAML::Config :$config --> Str) {
    my $cfg     = $config // ($!config // Template::HAML::Config.new);
    my $resolved = self!resolve-file-for-cache($file);
    my $path    = self.compile-file-to-cache(:$file, :config($cfg));
    my &fn      = self.load-from-cache($path);
    my $ctx     = Template::HAML::Context.new(
      :haml(self),
      :current-dir($resolved.dirname),
    );
    fn(%locals, :config($cfg), :$ctx);
  }

  method clear-compiled-cache(--> Int) {
    my $root = $!compiled-cache-dir;
    return 0 unless $root.e;
    my $count = 0;
    for $root.dir -> $shard {
      next unless $shard.d;
      for $shard.dir(:test(/ '.raku-haml' $/)) -> $f {
        $f.unlink;
        $count++;
      }
      $shard.rmdir if $shard.dir.elems == 0;
    }
    $count;
  }
}
