
use Template::HAML::Config;
use Template::HAML::Interpolation;
use Template::HAML::X;

sub html-escape(Str $s --> Str) {
  $s.subst('&', '&amp;', :g)
    .subst('<', '&lt;',  :g)
    .subst('>', '&gt;',  :g)
    .subst('"', '&quot;', :g)
    .subst("'", '&#39;', :g);
}

sub is-pair-list($value --> Bool) {
  return False unless $value ~~ Positional;
  return False unless $value.elems;
  $value[0] ~~ Pair;
}

sub camel-to-kebab(Str $s --> Str) {
  $s.subst(/ (<[a..z 0..9]>) (<[A..Z]>) /, -> $/ { $0 ~ '-' ~ $1.Str.lc }, :g).lc;
}

class Tag is export {
  has Int  $.indent;
  has Int  $.output-indent-width = 2;
  has Int  $.line;
  has Int  $.column;
  has Str  $.name           is rw;
  has @.attrs;
  has Str  $.content;
  has @.classes             of Str;
  has @.ids                 of Str;
  has @.obj-ref-args        of Str;
  has Bool $.self-close     is rw = False;
  has Bool $.trim-outer     = False;
  has Bool $.trim-inner     = False;
  has Template::HAML::Config $.config;

  submethod BUILD(
    :$!indent, :$!name, :@attrs, :$!content,
    :@!classes, :@!ids,
    :@!obj-ref-args,
    Bool :$!self-close = False,
    Bool :$!trim-outer = False,
    Bool :$!trim-inner = False,
    Int  :$!output-indent-width = 2,
    Int  :$!line, Int :$!column,
    Template::HAML::Config :$!config,
  ) {
    @!attrs = @attrs.list;
    $!config //= Template::HAML::Config.new;

    self.merge-shorthands;

    if !$!self-close && self.is-void && $!content.chars == 0 {
      $!self-close = True;
    }
  }

  method is-void { $!config.is-void($!name) }

  method open(Int :$offset = 0, :@attrs = @!attrs) {
    self.get-indent(:$offset) ~ '<' ~ $!name ~ self.render-attrs(:@attrs) ~ self.open-suffix;
  }

  method open-suffix(--> Str) {
    return ' />' if $!self-close && $!config.is-xhtml;
    return '>' if $!self-close && $!config.is-html;
    '>';
  }

  method close {
    return "\n" if $!self-close;
    '</' ~ $!name ~ '>' ~ "\n";
  }

  method get-indent(Int :$offset = 0) {
    my $tab = (try { $*HAML-TAB-OFFSET }) // 0;
    my $level = $!indent - $offset + $tab;
    $level = 0 if $level < 0;
    ' ' x ($level * $!output-indent-width);
  }

  method find-attr-index(Str $key) {
    @!attrs.first({ .key eq $key }, :k);
  }

  method find-attr-value(Str $key) {
    my $idx = self.find-attr-index($key);
    $idx.defined ?? @!attrs[$idx].value !! Nil;
  }

  method set-attr(Str $key, $value) {
    my $idx = self.find-attr-index($key);
    if $idx.defined {
      @!attrs[$idx] = $key => $value;
    } else {
      @!attrs.push: $key => $value;
    }
  }

  method maybe-interp(Str $s) {
    has-interp($s)
      ?? Template::HAML::Interpolation::InterpString.new(:raw($s))
      !! $s;
  }

  method merge-shorthands {
    if @!ids.elems {
      my @parts;
      @parts.push: self.maybe-interp($_) for @!ids;
      my $existing = self.find-attr-value('id');
      @parts.push: $existing if $existing.defined;

      if @parts.grep({ $_ !~~ Str }).elems {
        self.set-attr('id', @parts.List);
      } else {
        self.set-attr('id', @parts.join('_'));
      }
    }

    if @!classes.elems {
      my $existing = self.find-attr-value('class');
      my @parts;
      if $existing.defined {
        if $existing ~~ Template::HAML::Interpolation::InterpString {
          @parts.push: $existing;
        } elsif $existing ~~ Positional {
          @parts.push: $_ for $existing.list;
        } else {
          @parts.push: $_ for $existing.Str.split(' ');
        }
      }
      @parts.push: self.maybe-interp($_) for @!classes;

      if @parts.grep({ $_ !~~ Str }).elems {
        self.set-attr('class', @parts.List);
      } else {
        self.set-attr('class', @parts.unique.join(' '));
      }
    }
  }

  method ordered-attrs(:@attrs = @!attrs) {
    my @out;
    my %seen;

    if (my $id = @attrs.first({ .key eq 'id' })).defined {
      @out.push: $id;
      %seen<id> = True;
    }
    if (my $cls = @attrs.first({ .key eq 'class' })).defined {
      @out.push: $cls;
      %seen<class> = True;
    }
    for @attrs -> $p {
      next if %seen{$p.key};
      @out.push: $p;
    }
    @out;
  }

  method render-attrs(:@attrs = @!attrs) {
    my @rendered;
    for self.ordered-attrs(:@attrs) -> $p {
      my $r = self.render-attr-pair($p.key, $p.value);
      @rendered.push: $r if $r.defined;
    }
    @rendered.elems ?? ' ' ~ @rendered.join(' ') !! '';
  }

  method render-attr-pair(Str $key, $value) {
    return Nil if !$value.defined;
    return Nil if $value === False;
    return self.render-bool-attr($key) if $value === True;

    if ($key eq 'data' || $key eq 'aria') && is-pair-list($value) {
      my @sub = self.expand-prefix($key, $value);
      my @rendered;
      for @sub -> $sub {
        my $r = self.render-attr-pair($sub.key, $sub.value);
        @rendered.push: $r if $r.defined;
      }
      return @rendered.elems ?? @rendered.join(' ') !! Nil;
    }

    if $value ~~ Positional && $value !~~ Pair {
      my $joined = do given $key {
        when 'class' { $value.list.grep({ .defined && .so }).join(' ') }
        when 'id'    { $value.list.grep({ .defined && .so }).join('_') }
        default      { $value.list.join(' ') }
      };
      return self.format-attr($key, $joined);
    }

    self.format-attr($key, $value.Str);
  }

  method render-bool-attr(Str $key --> Str) {
    return self.format-attr($key, $key) if $!config.is-xhtml;
    $key;
  }

  method expand-prefix(Str $prefix, $value) {
    my @result;
    for $value.list -> $p {
      my $part = $!config.hyphenate-data-attrs
        ?? camel-to-kebab($p.key)
        !! $p.key;
      my $sub-key = "$prefix-$part";
      my $sub-val = $p.value;
      if is-pair-list($sub-val) {
        @result.append: self.expand-prefix($sub-key, $sub-val);
      } else {
        @result.push: $sub-key => $sub-val;
      }
    }
    @result;
  }

  method format-attr(Str $key, Str $value --> Str) {
    my $q = $!config.attr-quote;
    my $val;
    if $!config.escape-attrs {
      $val = html-escape($value);
    } else {
      $val = $value;
      my $entity = $q eq "'" ?? '&#39;' !! '&quot;';
      $val = $val.subst($q, $entity, :g);
    }
    "$key=$q" ~ $val ~ $q;
  }
}
