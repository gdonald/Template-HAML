
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

sub register-filter(Str :$name!, :&handler!) is export {
  %filters{$name} = &handler;
}

sub lookup-filter(Str $name) is export {
  %filters{$name};
}

sub has-filter(Str $name --> Bool) is export {
  %filters{$name}:exists;
}

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
