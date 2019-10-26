
use Template::Haml::Lines;
use Template::Haml::Renderer;
use Template::Haml::Line;

grammar Grammar is export {

  token ws { \h* }
  token indent { ^^ \h* }
  token eol { $$ \n* }

  token word { \w+ }
  token number { \d+ }
  token sigil { <[%.#]>**1 }
  token op { <[=\-]>**1 }

  rule param-key { <word> ':' }
  rule symbol { ':' <word> }
  rule phrase { [ <word> ]* }
  rule single-quoted-string { "'" <phrase> "'" }
  rule double-quoted-string { '"' <phrase> '"' }
  rule quoted-string { [ <single-quoted-string> | <double-quoted-string> ] }
  rule param-value { [ <quoted-string> | <symbol> ] }
  rule param { <param-key> <param-value> }
  rule params { <param> [ ',' <param> ]* }
  rule params-hash { '{' <params>? '}' }
  rule line-type { <sigil><word> }
  rule css-class { '.' <word> }
  rule css-classes { <css-class> [ <css-class> ]* }

  token line { <indent><line-type><css-classes>?<params-hash>? <phrase>? <.eol> }

  rule TOP {
    <line>*
    $
  }
}
