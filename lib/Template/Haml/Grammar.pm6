
use Template::Haml::Lines;
use Template::Haml::Renderer;
use Template::Haml::Tag;

grammar Grammar is export {

  token word { \w+ }
  token number { \d+ }
  token indent { \s+ }
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
  rule params-hash { '{' <params> '}' }
  rule tag-type { <sigil><word> }
  rule css-class { '.' <word> }
  rule css-classes { <css-class> [ <css-class> ]* }
  rule tag { <indent>? <tag-type><css-classes>?<params-hash>? <phrase>? }

  rule lines {
    [
      | <tag>
    ]*
  }

  rule TOP { <lines> }
}
