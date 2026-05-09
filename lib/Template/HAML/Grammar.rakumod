
use Template::HAML::Renderer;

# Line-ending policy: HAML source is treated as LF-terminated. Callers should
# normalize CRLF to LF before parsing (HAML.render does this).

grammar Grammar is export {
  token ws  { \h* }
  token nl  { \n }
  token eol { $$ \n? }

  token word    { \w+ }
  token number  { \d+ }
  token to-eol  { \N* }
  token expr    { \N* }
  token sigil   { <[%.#]> }
  token op      { <[=\-]> }
  token if      { if }

  token indent { ^^ \h* }

  token tag-name        { <[A..Za..z_]> [ <[\w \: \-]> ]* }
  token explicit-tag-name { '%' <tag-name> }
  token shorthand-class { '.' <word> }
  token shorthand-id    { '#' <word> }
  token shorthand       { <shorthand-class> | <shorthand-id> }

  token trim-modifiers  { <[<>]> ** 0..2 }
  token void-marker     { '/' }

  rule param-key            { <word> ':' }
  rule symbol               { ':' <word> }
  rule phrase               { [ <word> ]* }
  rule single-quoted-string { "'" <phrase> "'" }
  rule double-quoted-string { '"' <phrase> '"' }
  rule quoted-string        { [ <single-quoted-string> | <double-quoted-string> ] }
  rule param-value          { [ <quoted-string> | <symbol> ] }
  rule param                { <param-key> <param-value> }
  rule params               { <param> [ ',' <param> ]* }
  rule params-hash          { '{' <params>? '}' }
  rule tag-type             { <sigil><word> }
  rule css-class            { '.' <word> }
  rule css-classes          { <css-class> [ <css-class> ]* }

  token tag {
    <indent>
    [
      | <explicit-tag-name> <shorthand>*
      | <shorthand>+
    ]
    <params-hash>?
    <trim-modifiers>
    <void-marker>?
    <to-eol>
    <.eol>
  }

  token statement { <indent> <op> <.ws> <if> <.ws> <expr> <.eol> }

  proto token line { * }
  multi token line:sym<blank>          { ^^ \h* $$ \n+ }
  multi token line:sym<doctype>        { ^^ '!!!' <to-eol> <.eol> }
  multi token line:sym<silent-comment> { ^^ \h* '-#' <to-eol> <.eol> }
  multi token line:sym<comment>        { ^^ \h* '/' <to-eol> <.eol> }
  multi token line:sym<filter>         { ^^ \h* ':' <word> <.eol> }
  multi token line:sym<statement>      { <statement> }
  multi token line:sym<tag>            { <tag> }
  multi token line:sym<plain>          { ^^ \h* <!before <[%.#=\-:/!]>> \N <to-eol> <.eol> }

  rule TOP {
    <line>*
    $
  }
}
