
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
  token expr    { \N+ }
  token sigil   { <[%.#]> }
  token output-op { '!=' | '&=' | '==' | '=' | '-' | '~' }

  token indent { ^^ \h* }

  token tag-name        { <[A..Za..z_]> [ <[\w \: \-]> ]* }
  token explicit-tag-name { '%' <tag-name> }
  token shorthand-interp-body { [ '\\' . | <-[\\ }]> ]* }
  token shorthand-interp { <[#!]> '{' <shorthand-interp-body> '}' }
  token shorthand-escaped-interp { '\\' <[#!]> '{' <shorthand-interp-body> '}' }
  token shorthand-atom  {
    | <shorthand-escaped-interp>
    | <shorthand-interp>
    | <[\w \-]>+
  }
  token shorthand-name  { <shorthand-atom>+ }
  token shorthand-class { '.' <shorthand-name> }
  token shorthand-id    { '#' <!before '{'> <shorthand-name> }
  token shorthand       { <shorthand-class> | <shorthand-id> }

  token trim-modifiers  { <[<>]> ** 0..2 }
  token void-marker     { '/' }

  token sq-content { [ \\ . | <-[\\ ']> ]* }
  token dq-content { [ \\ . | <-[\\ "]> ]* }
  rule  single-quoted-string { "'" <sq-content> "'" }
  rule  double-quoted-string { '"' <dq-content> '"' }
  rule  quoted-string        { <single-quoted-string> | <double-quoted-string> }

  token symbol      { ':' <word> }
  token hyphen-name { <[A..Za..z_]> [ <[\w \: \-]> ]* }

  token array-value { '[' \s* <value> [ \s* ',' \s* <value> ]* \s* ','? \s* ']' }
  token hash-value  { '{' \s* [ <pair> [ \s* ',' \s* <pair> ]* \s* ','? \s* ]? '}' }

  token value {
    | <quoted-string>
    | <number>
    | <bool>
    | <symbol>
    | <hash-value>
    | <array-value>
  }

  token rocket-key  { <quoted-string> | <symbol> | <word> }
  token pair-bare   { <word> \s* ':' \s* <value> }
  token pair-rocket { <rocket-key> \s* '=>' \s* <value> }
  token pair        { <pair-rocket> | <pair-bare> }

  token params-hash { '{' \s* [ <pair> [ \s* ',' \s* <pair> ]* \s* ','? \s* ]? '}' }

  token html-bool-attr  { <hyphen-name> }
  token html-keyed-attr { <hyphen-name> \s* '=' \s* <quoted-string> }
  token html-attr       { <html-keyed-attr> | <html-bool-attr> }
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

  token statement { <indent> <output-op> <.ws> <expr> <.eol> }

  token comment-condition { '[' $<cond>=( <-[ \] ]>+ ) ']' }
  token comment-revealed  { '!' }

  proto token line { * }
  multi token line:sym<blank>          { ^^ \h* $$ \n+ }
  multi token line:sym<doctype>        { ^^ '!!!' <to-eol> <.eol> }
  multi token line:sym<silent-comment> {
    ^^ $<head>=[\h*] '-#' \N* \n
    [
      ^^ \h* $$ \n
      |
      ^^ $<body>=[\h+] \N* \n
         <?{ $<body>[*-1].Str.chars > $<head>.chars }>
    ]*
  }
  multi token line:sym<comment>        {
    ^^ $<head>=[\h*] '/' <comment-revealed>? <comment-condition>? <to-eol> <.eol>
  }
  multi token line:sym<filter> {
    ^^ $<head>=[\h*] ':' <word> \h* <.eol>
    [
      | ^^ $<body-line>=[ \h* \n ]
      | ^^ $<body-line>=[ \h+ \N* [ \n | $ ] ]
          <?{
            my $bl   = ($<body-line>[*-1] // '').Str;
            my $head = ($<head> // '').Str;
            my $m    = $bl ~~ /^ \h+/;
            my $bws  = $m ?? $m.Str.chars !! 0;
            $bws > $head.chars;
          }>
    ]*
  }
  multi token line:sym<statement>      { <statement> }
  multi token line:sym<tag>            { <tag> }
  multi token line:sym<plain> {
    ^^ $<head>=[\h*]
    <!before
      [
        | '%'
        | '.' \w
        | '#' \w
        | '='
        | '-'
        | '/'
        | '!='
        | '!!!'
        | '&='
        | '~'
        | ':' \w
      ]
    >
    $<plain-text>=[\N+]
    <.eol>
  }

  rule TOP {
    <line>*
    $
  }
}
