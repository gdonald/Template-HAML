
use Template::HAML::Eval;
use Template::HAML::Interpolation;

unit module Template::HAML::Filters;

sub html-escape(Str $s --> Str) {
  $s.subst('&', '&amp;', :g)
    .subst('<', '&lt;',  :g)
    .subst('>', '&gt;',  :g)
    .subst('"', '&quot;', :g)
    .subst("'", '&#39;', :g);
}

my %filters;

#| Register a filter handler under C<:name>. The handler is called as
#| C<sub (Str $body, %locals --> Str)>; its return value is emitted
#| in place of the filter block.
sub register-filter(Str :$name!, :&handler!) is export {
  %filters{$name} = &handler;
}

#| Look up a registered filter by name; returns C<Nil> if not found.
sub lookup-filter(Str $name) is export {
  %filters{$name};
}

#| C<True> if a filter with C<$name> is currently registered.
sub has-filter(Str $name --> Bool) is export {
  %filters{$name}:exists;
}

#| Sorted list of registered filter names.
sub filter-names(--> Seq) is export {
  %filters.keys.sort;
}

sub interp-body(Str $body, %locals --> Str) {
  return '' unless $body.chars;
  $body.lines.map({ interpolate($_, %locals) }).join("\n");
}

sub current-cfg() {
  try { $*HAML-CFG } // Nil;
}

sub script-style-attrs(Str $kind --> Str) {
  my $cfg  = current-cfg();
  my $mime = $cfg.defined ?? $cfg.mime-type !! '';
  my $q    = $cfg.defined ?? $cfg.attr-quote !! "'";
  my $is-xhtml = $cfg.defined && $cfg.is-xhtml;

  my $type = $mime.chars
    ?? $mime
    !! ($is-xhtml ?? ($kind eq 'script' ?? 'text/javascript' !! 'text/css') !! '');
  $type.chars ?? " type=$q$type$q" !! '';
}

sub needs-cdata(--> Bool) {
  my $cfg = current-cfg();
  return False unless $cfg.defined;
  $cfg.is-xhtml || $cfg.cdata;
}

register-filter :name<plain>, :handler(-> Str $body, %locals --> Str {
  interp-body($body, %locals);
});

register-filter :name<escaped>, :handler(-> Str $body, %locals --> Str {
  html-escape(interp-body($body, %locals));
});

register-filter :name<javascript>, :handler(-> Str $body, %locals --> Str {
  my $attrs = script-style-attrs('script');
  if !$body.chars {
    "<script$attrs></script>";
  } else {
    my $inner = interp-body($body, %locals).lines.map({ '  ' ~ $_ }).join("\n");
    if needs-cdata() {
      "<script$attrs>\n  //<![CDATA[\n" ~ $inner ~ "\n  //]]>\n</script>";
    } else {
      "<script$attrs>\n" ~ $inner ~ "\n</script>";
    }
  }
});

register-filter :name<css>, :handler(-> Str $body, %locals --> Str {
  my $attrs = script-style-attrs('style');
  if !$body.chars {
    "<style$attrs></style>";
  } else {
    my $inner = interp-body($body, %locals).lines.map({ '  ' ~ $_ }).join("\n");
    if needs-cdata() {
      "<style$attrs>\n  /*<![CDATA[*/\n" ~ $inner ~ "\n  /*]]>*/\n</style>";
    } else {
      "<style$attrs>\n" ~ $inner ~ "\n</style>";
    }
  }
});

register-filter :name<cdata>, :handler(-> Str $body, %locals --> Str {
  if !$body.chars {
    "<![CDATA[]]>";
  } else {
    my $inner = interp-body($body, %locals).lines.map({ '  ' ~ $_ }).join("\n");
    "<![CDATA[\n" ~ $inner ~ "\n]]>";
  }
});

register-filter :name<preserve>, :handler(-> Str $body, %locals --> Str {
  if !$body.chars {
    '';
  } else {
    interp-body($body, %locals).subst("\n", '&#x000A;', :g);
  }
});

register-filter :name<raku>, :handler(-> Str $body, %locals --> Str {
  if !$body.chars {
    '';
  } else {
    my $val = eval-haml($body, %locals);
    $val.defined ?? $val.Str !! '';
  }
});

=begin pod

=head1 NAME

Template::HAML::Filters - filter registry

=head1 SYNOPSIS

=begin code :lang<raku>
use Template::HAML::Filters;

register-filter(
  :name<shout>,
  :handler(-> Str $body, %locals --> Str { $body.uc }),
);
=end code

=head1 BUILT-IN FILTERS

=item C<:plain> - Emit raw text, no sigil parsing, with C<#{}> interpolation.
=item C<:escaped> - HTML-escape then emit.
=item C<:javascript> - Wrap content in a C<< <script> >> tag.
=item C<:css> - Wrap content in a C<< <style> >> tag.
=item C<:cdata> - Wrap content in C<< <![CDATA[ ... ]]> >>.
=item C<:preserve> - Replace literal newlines with C<&#x000A;>.
=item C<:raku> - Evaluate the body as Raku code; emit its return value.

=head1 SUBS

=head2 register-filter(Str :$name!, :&handler!)

Register a filter handler under C<$name>.

=head2 lookup-filter(Str $name)

Return the handler associated with C<$name>, or C<Nil>.

=head2 has-filter(Str $name --> Bool)

Whether a filter with C<$name> is registered.

=head2 filter-names(--> Seq)

Sorted sequence of registered filter names.

=end pod
