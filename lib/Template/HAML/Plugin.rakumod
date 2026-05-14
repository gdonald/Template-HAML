
use Template::HAML::Visitor;
use Template::HAML::TagTransformers;
use Template::HAML::Filters;

unit module Template::HAML::Plugin;

class Plugin is export {
  has Str  $.name is required;
  has      @.visitors;
  has      @.tag-transformers;
  has      @.filters;
  has      &.markdown-backend;
  has Bool $.installed = False;

  submethod BUILD(
    Str:D :$!name,
    :@visitors,
    :@tag-transformers,
    :@filters,
    :&markdown-backend,
  ) {
    @!visitors          = @visitors;
    @!tag-transformers  = @tag-transformers;
    @!filters           = @filters;
    &!markdown-backend  = &markdown-backend;
    self!validate-hooks;
  }

  method !validate-hooks() {
    for @!visitors -> $v {
      die "Plugin '$!name': visitor entries must be hashes with :name and :handler"
        unless $v ~~ Associative && $v<name>.defined && $v<handler>.defined;
    }
    for @!tag-transformers -> $t {
      die "Plugin '$!name': tag-transformer entries must be hashes with :name and :handler"
        unless $t ~~ Associative && $t<name>.defined && $t<handler>.defined;
    }
    for @!filters -> $f {
      die "Plugin '$!name': filter entries must be hashes with :name and :handler"
        unless $f ~~ Associative && $f<name>.defined && $f<handler>.defined;
    }
  }

  method install(--> Plugin) {
    return self if $!installed;
    for @!visitors -> $v {
      Template::HAML::Visitor::register-visitor(:name($v<name>), :handler($v<handler>));
    }
    for @!tag-transformers -> $t {
      Template::HAML::TagTransformers::register-tag-transformer(:name($t<name>), :handler($t<handler>));
    }
    for @!filters -> $f {
      Template::HAML::Filters::register-filter(:name($f<name>), :handler($f<handler>));
    }
    if &!markdown-backend.defined {
      Template::HAML::Filters::register-markdown-backend(:handler(&!markdown-backend));
    }
    $!installed = True;
    self;
  }

  method uninstall(--> Plugin) {
    return self unless $!installed;
    for @!visitors -> $v {
      Template::HAML::Visitor::clear-visitor($v<name>);
    }
    for @!tag-transformers -> $t {
      Template::HAML::TagTransformers::clear-tag-transformer($t<name>);
    }
    for @!filters -> $f {
      Template::HAML::Filters::clear-filter($f<name>);
    }
    if &!markdown-backend.defined {
      Template::HAML::Filters::clear-markdown-backend();
    }
    $!installed = False;
    self;
  }
}

my @installed;

our sub install-plugin(Plugin:D $p --> Plugin) is export {
  $p.install;
  @installed.push: $p unless @installed.first({ $_ === $p });
  $p;
}

our sub uninstall-plugin(Plugin:D $p --> Plugin) is export {
  $p.uninstall;
  @installed = @installed.grep({ $_ !=== $p });
  $p;
}

our sub installed-plugins() is export {
  @installed.list;
}

our sub installed-plugin-names() is export {
  @installed.map(*.name).list;
}

our sub installed-plugin(Str:D $name --> Plugin) is export {
  @installed.first({ .name eq $name }) // Plugin;
}

our sub clear-plugins(--> Int) is export {
  my $n = @installed.elems;
  for @installed.reverse -> $p { $p.uninstall }
  @installed = ();
  $n;
}
