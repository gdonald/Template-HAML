
use Template::HAML::Actions;
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
  has %!compiled-cache;

  submethod BUILD(
    Template::HAML::Config :$config,
    :$search-paths,
    Bool :$cache = True,
  ) {
    $!config = $config // Template::HAML::Config.new;
    @!search-paths = do given $search-paths {
      when !.defined { () }
      when Str       { ($search-paths,) }
      default        { $search-paths.list }
    };
    $!cache = $cache;
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
}

=begin pod

=head1 NAME

Template::HAML - HTML Abstraction Markup Language for Raku

=head1 SYNOPSIS

=begin code :lang<raku>
use Template::HAML;

say HAML.render(
  :src("%h1 Hello, #{$name}!\n"),
  :locals(%(:name<world>)),
);
=end code

=head1 DESCRIPTION

Template::HAML compiles HAML source to HTML.  It is a Raku-flavored
port of Ruby HAML built on Raku Grammars.

=head1 METHODS

=head2 render(:$src!, :%locals, :$config)

Render a HAML source string to HTML.  C<%locals> become lexicals
visible to embedded C<= expr> and C<- expr> operators.

=head2 render(:$file!, :$layout, :%locals, :$config)

Render a HAML source file resolved against the instance's
C<@search-paths>.  When C<:layout> is supplied, the file is rendered
first, then its output is exposed as C<= yield> inside the layout.

=head2 resolve-template(Str $name --> Str)

Resolve a template name to an absolute path using the configured
search paths and the C<name.html.haml> / C<_name.html.haml> naming
conventions.

=head2 compile-file(Str $path --> Node)

Compile (and cache, if C<$.cache>) the parsed tree for a path.
Cache entries are keyed on path and mtime.

=head2 clear-cache()

Drop all cached compiled templates.

=head1 SEE ALSO

L<Template::HAML::Config>, L<Template::HAML::Filters>,
L<Template::HAML::Helpers>, L<Template::HAML::X>.

=end pod
