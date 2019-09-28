
grammar Grammar is export {

  token single-quote { \' }
  token double-quote { \" }
  token name { \w+ }
  token number { \d+ }

  rule key { <name> ':' }
  rule symbol { ':' <name> }
  rule phrase { [ <name> ]* }
  rule single-quoted-string { <single-quote><phrase><single-quote> }
  rule double-quoted-string { <double-quote><phrase><double-quote> }
  rule quoted-string { [ <single-quoted-string> | <double-quoted-string> ] }
  rule param { <key> [ <quoted-string> | <symbol> ] }
  rule params { <param> [ ',' <param> ]* }
  rule params-hash { '{' <params> '}' }
  rule tag { '%' <name><params-hash>? }

  rule line {
    [
      | <tag>
    ]*
  }

  rule TOP {
    <lines>
  }
}
