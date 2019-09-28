
use Template::Haml::Lines;
use Template::Haml::Tag;
use Template::Haml::X;

class Actions is export {
  method TOP($/) {}

  method tag($/) {
    my $indent = $/<indent>.made || 0;
    my $name = $/<tag-type><word>.Str;
    my $params = $/<params-hash>.made || {};
    my $content = $/<phrase>.Str.trim || '';
    my $sigil = $/<tag-type><sigil>.Str;
    my $classes = $/<css-classes>.made || [];

    my $obj = Tag.new(:$indent, :$sigil, :$name, :$params, :$content, :$classes);
    Lines.push(:$obj);
  }

  method indent($/) {
    my $length = $/.Str.chars;
    illegal-indent if $length mod 2;
    make $length;
  }

  method quoted-string($/) {
    if $/<double-quoted-string> {
      make $/<double-quoted-string>.Str.subst(:global, /\"/, '');
    } elsif $/<single-quoted-string> {
      make $/<single-quoted-string>.Str.subst(:global, /\'/, '');
    }
  }

  method param-value($/) {
    if $/<quoted-string> {
      make $/<quoted-string>.made.trim;
    } elsif $/<symbol> {
      make $/<symbol>.Str.subst(:global, /\:/, '').trim;
    }
  }

  method param-key($/) {
    make $/<word>.Str;
  }

  method param($/) {
    make Pair.new: $/<param-key>.made, $/<param-value>.made;
  }

  method params($/) {
    make Hash.new: $/<param>.map({ .made });
  }

  method params-hash($/) {
    make $/<params>.made;
  }

  method css-class($/) {
    make $/.Str.subst(/\./, '').trim;
  }

  method css-classes($/) {
    make $/<css-class>.map({ .made });
  }
}
