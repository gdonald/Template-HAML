
use Template::HAML::X;

constant @VOID-ELEMENTS = <
  area base br col embed hr img input link meta param source track wbr
>;

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
  has Bool $.self-close     is rw = False;
  has Bool $.trim-outer     = False;
  has Bool $.trim-inner     = False;
  has Str  $.open;

  submethod BUILD(
    :$!indent, :$!name, :@attrs, :$!content,
    :@!classes, :@!ids,
    Bool :$!self-close = False,
    Bool :$!trim-outer = False,
    Bool :$!trim-inner = False,
    Int  :$!output-indent-width = 2,
    Int  :$!line, Int :$!column,
  ) {
    @!attrs = @attrs.list;

    self.merge-shorthands;

    if !$!self-close && self.is-void && $!content.chars == 0 {
      $!self-close = True;
    }

    self.build-open;
  }

  method is-void { $!name (elem) @VOID-ELEMENTS }

  method build-open {
    $!open = self.get-indent ~ '<' ~ $!name ~ self.render-attrs ~ '>';
  }

  method close {
    return "\n" if $!self-close;
    '</' ~ $!name ~ '>' ~ "\n";
  }

  method get-indent {
    ' ' x ($!indent * $!output-indent-width);
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

  method merge-shorthands {
    if @!ids.elems {
      my $existing = self.find-attr-value('id');
      my @parts = (|@!ids, |($existing.defined ?? ($existing,) !! ()));
      self.set-attr('id', @parts.join('_'));
    }

    if @!classes.elems {
      my $existing = self.find-attr-value('class');
      my @parts;
      if $existing.defined {
        @parts.push: $_ for $existing.split(' ');
      }
      @parts.push: $_ for @!classes;
      self.set-attr('class', @parts.unique.join(' '));
    }
  }

  method ordered-attrs {
    my @out;
    my %seen;

    if (my $id = @!attrs.first({ .key eq 'id' })).defined {
      @out.push: $id;
      %seen<id> = True;
    }
    if (my $cls = @!attrs.first({ .key eq 'class' })).defined {
      @out.push: $cls;
      %seen<class> = True;
    }
    for @!attrs -> $p {
      next if %seen{$p.key};
      @out.push: $p;
    }
    @out;
  }

  method render-attrs {
    my @rendered;
    for self.ordered-attrs -> $p {
      my $r = self.render-attr-pair($p.key, $p.value);
      @rendered.push: $r if $r.defined;
    }
    @rendered.elems ?? ' ' ~ @rendered.join(' ') !! '';
  }

  method render-attr-pair(Str $key, $value) {
    return Nil if !$value.defined;
    return Nil if $value === False;
    return $key if $value === True;

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

  method expand-prefix(Str $prefix, $value) {
    my @result;
    for $value.list -> $p {
      my $sub-key = "$prefix-{$p.key}";
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
    "$key='" ~ html-escape($value) ~ "'";
  }
}
