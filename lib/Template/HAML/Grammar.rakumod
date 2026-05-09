
use Template::HAML::Renderer;

# Line-ending policy: HAML source is treated as LF-terminated. Callers should
# normalize CRLF to LF before parsing (HAML.render does this).

grammar Grammar is export {
  token ws  { \h* }
  token nl  { \n }
  token eol { $$ \n? }

  token word    { \w+ }
  token number  { '-'? \d+ [ '.' \d+ ]? }
  token bool    { 'True' | 'False' | 'true' | 'false' | 'Nil' }
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

  token sq-content { [ \\ . | <-[\\ ']> ]* }
  token dq-content { [ \\ . | <-[\\ "]> ]* }
  rule  single-quoted-string { "'" <sq-content> "'" }
  rule  double-quoted-string { '"' <dq-content> '"' }
  rule  quoted-string        { <single-quoted-string> | <double-quoted-string> }

  rule  symbol      { ':' <word> }
  token hyphen-name { <[A..Za..z_]> [ <[\w \: \-]> ]* }

  rule  array-value { '[' <value> [ ',' <value> ]* ','? ']' }
  rule  hash-value  { '{' [ <pair> [ ',' <pair> ]* ','? ]? '}' }

  rule value {
    | <quoted-string>
    | <number>
    | <bool>
    | <symbol>
    | <hash-value>
    | <array-value>
  }

  rule  rocket-key  { <quoted-string> | <symbol> | <word> }
  rule  pair-bare   { <word> ':' <value> }
  rule  pair-rocket { <rocket-key> '=>' <value> }
  rule  pair        { <pair-rocket> | <pair-bare> }

  rule  params-hash { '{' [ <pair> [ ',' <pair> ]* ','? ]? '}' }

  token html-bool-attr  { <hyphen-name> }
  rule  html-keyed-attr { <hyphen-name> '=' <quoted-string> }
  rule  html-attr       { <html-keyed-attr> | <html-bool-attr> }
  token html-attrs      { '(' [ \s* <html-attr> ]+ \s* ')' }

  rule param-key   { <word> ':' }
  rule param-value { <value> }
  rule param       { <pair-bare> }
  rule params      { <pair> [ ',' <pair> ]* ','? }
  rule css-class   { '.' <word> }
  rule css-classes { <css-class> [ <css-class> ]* }
  rule tag-type    { <sigil><word> }
  rule phrase      { [ <word> ]* }

  token tag {
    <indent>
    [
      | <explicit-tag-name> <shorthand>*
      | <shorthand>+
    ]
    <html-attrs>?
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
