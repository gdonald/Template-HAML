
use Template::HAML::Actions;
use Template::HAML::Cache;
use Template::HAML::Codegen;
use Template::HAML::Config;
use Template::HAML::Context;
use Template::HAML::Multiline;
use Template::HAML::Node;
use Template::HAML::Renderer;
use Template::HAML::TagTransformers;
use Template::HAML::ViewContext;
use Template::HAML::Visitor;
use Template::HAML::Grammar;
use Template::HAML::X;

sub default-user-context() {
  Template::HAML::ViewContext.new;
}

my %fn-cache;
my %repo-cache;

sub fn-cache-clear(--> Int) {
  my $n = %fn-cache.elems;
  %fn-cache = ();
  $n;
}

sub rm-rf(IO::Path:D $dir) {
  return unless $dir.e;
  if $dir.d {
    for $dir.dir -> $child {
      rm-rf($child);
    }
    $dir.rmdir;
  } else {
    $dir.unlink;
  }
}

sub cache-repo-for(IO::Path:D $cache-dir --> CompUnit::Repository::FileSystem) {
  my $abs = $cache-dir.absolute;
  %repo-cache{$abs} //= CompUnit::Repository::FileSystem.new(
    :prefix($abs),
    :next-repo($*REPO),
  );
}

sub load-render-fn(IO::Path:D $cache-dir, Str:D $key --> Code) {
  my $repo     = cache-repo-for($cache-dir);
  my $mod-name = compiled-module-name($key);
  my $spec     = CompUnit::DependencySpecification.new(:short-name($mod-name));
  my $cu       = $repo.need($spec);
  my $stash    = $cu.handle.globalish-package;
  for $mod-name.split('::') -> $part {
    $stash = $stash{$part}.WHO;
  }
  $stash<&render>;
}

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

  multi method render(HAML:U: Str:D :$src!, :%locals, Template::HAML::Config :$config, :$context) {
    my $cfg = $config // Template::HAML::Config.new;
    my $ctx = Template::HAML::Context.new(
      :haml(self.WHAT),
      :user-context($context // default-user-context()),
    );
    self!do-render-src($src, %locals, $cfg, $ctx);
  }

  multi method render(HAML:D: Str:D :$src!, :%locals, Template::HAML::Config :$config, :$context) {
    my $cfg = $config // $!config // Template::HAML::Config.new;
    my $ctx = Template::HAML::Context.new(
      :haml(self),
      :user-context($context // default-user-context()),
    );
    self!do-render-src($src, %locals, $cfg, $ctx);
  }

  multi method render(
    HAML:D:
    Str:D :$file!,
    :$layout,
    :%locals,
    Template::HAML::Config :$config,
    :$context,
  ) {
    my $cfg  = $config // $!config // Template::HAML::Config.new;
    my $path = self.resolve-template($file);
    my $ctx  = Template::HAML::Context.new(
      :haml(self),
      :current-dir($path.IO.dirname),
      :user-context($context // default-user-context()),
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
    my $visited = apply-visitors($actions.tree);
    apply-tag-transformers($visited);
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
    my $key  = self.compiled-cache-key(:$src, :config($cfg));
    my $path = cache-path($!compiled-cache-dir, $key);
    return $path if $path.e;
    my $tree = self!compile-source($src, $cfg);
    my $code = Codegen.new(:config($cfg)).emit-module($tree, :module-name(compiled-module-name($key)));
    write-cache-file($path, $code);
    $path;
  }

  method load-from-cache(IO::Path:D $path --> Code) {
    my $base = $path.basename;
    $base ~~ s/ '.rakumod' $ //;
    $base ~~ s/^ 'T' //;
    load-render-fn($!compiled-cache-dir, $base);
  }

  method render-cached(Str:D :$src!, :%locals, Template::HAML::Config :$config, :$context --> Str) {
    my $cfg = $config // ($!config // Template::HAML::Config.new);
    my $key = self.compiled-cache-key(:$src, :config($cfg));
    unless %fn-cache{$key}:exists {
      self.compile-to-cache(:$src, :config($cfg));
      %fn-cache{$key} = load-render-fn($!compiled-cache-dir, $key);
    }
    my &fn = %fn-cache{$key};
    my $ctx = Template::HAML::Context.new(
      :haml(self.WHAT === HAML ?? self.WHAT !! self),
      :user-context($context // default-user-context()),
    );
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
    my $key  = self.compiled-cache-key-for-file(:$file, :config($cfg));
    my $path = cache-path($!compiled-cache-dir, $key);
    return $path if $path.e;
    my $src  = self!resolve-file-for-cache($file).slurp;
    my $tree = self!compile-source($src, $cfg);
    my $code = Codegen.new(:config($cfg)).emit-module($tree, :module-name(compiled-module-name($key)));
    write-cache-file($path, $code);
    $path;
  }

  method render-file-cached(Str:D :$file!, :%locals, Template::HAML::Config :$config, :$context --> Str) {
    my $cfg      = $config // ($!config // Template::HAML::Config.new);
    my $resolved = self!resolve-file-for-cache($file);
    my $key      = self.compiled-cache-key-for-file(:$file, :config($cfg));
    unless %fn-cache{$key}:exists {
      self.compile-file-to-cache(:$file, :config($cfg));
      %fn-cache{$key} = load-render-fn($!compiled-cache-dir, $key);
    }
    my &fn = %fn-cache{$key};
    my $ctx = Template::HAML::Context.new(
      :haml(self),
      :current-dir($resolved.dirname),
      :user-context($context // default-user-context()),
    );
    fn(%locals, :config($cfg), :$ctx);
  }

  method clear-compiled-cache(--> Int) {
    fn-cache-clear();
    %repo-cache{$!compiled-cache-dir.absolute}:delete;
    my $root = $!compiled-cache-dir;
    return 0 unless $root.e;
    my $count = 0;
    my $compiled-dir = $root.add('Template').add('HAML').add('Compiled');
    if $compiled-dir.e {
      for $compiled-dir.dir(:test(/ '.rakumod' $/)) -> $f {
        $f.unlink;
        $count++;
      }
      $compiled-dir.rmdir if $compiled-dir.dir.elems == 0;
      my $haml-parent = $root.add('Template').add('HAML');
      $haml-parent.rmdir if $haml-parent.e && $haml-parent.dir.elems == 0;
      my $tpl-parent = $root.add('Template');
      $tpl-parent.rmdir if $tpl-parent.e && $tpl-parent.dir.elems == 0;
    }
    my $precomp = $root.add('.precomp');
    if $precomp.e && $precomp.d {
      rm-rf($precomp);
    }
    $count;
  }

  method compiled-fn-cache-size(--> Int) { %fn-cache.elems }

  method clear-compiled-fn-cache(--> Int) { fn-cache-clear() }
}
