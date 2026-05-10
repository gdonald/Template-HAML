
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

register-filter :name<plain>, :handler(-> Str $body, %locals --> Str {
  interp-body($body, %locals);
});

register-filter :name<escaped>, :handler(-> Str $body, %locals --> Str {
  html-escape(interp-body($body, %locals));
});

register-filter :name<javascript>, :handler(-> Str $body, %locals --> Str {
  return "<script></script>" unless $body.chars;
  my $inner = interp-body($body, %locals).lines.map({ '  ' ~ $_ }).join("\n");
  "<script>\n" ~ $inner ~ "\n</script>";
});

register-filter :name<css>, :handler(-> Str $body, %locals --> Str {
  return "<style></style>" unless $body.chars;
  my $inner = interp-body($body, %locals).lines.map({ '  ' ~ $_ }).join("\n");
  "<style>\n" ~ $inner ~ "\n</style>";
});

register-filter :name<cdata>, :handler(-> Str $body, %locals --> Str {
  return "<![CDATA[]]>" unless $body.chars;
  my $inner = interp-body($body, %locals).lines.map({ '  ' ~ $_ }).join("\n");
  "<![CDATA[\n" ~ $inner ~ "\n]]>";
});

register-filter :name<preserve>, :handler(-> Str $body, %locals --> Str {
  return '' unless $body.chars;
  interp-body($body, %locals).subst("\n", '&#x000A;', :g);
});

register-filter :name<raku>, :handler(-> Str $body, %locals --> Str {
  return '' unless $body.chars;
  my $val = eval-haml($body, %locals);
  $val.defined ?? $val.Str !! '';
});
