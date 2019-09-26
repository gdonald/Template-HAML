
grammar Grammar is export {

  token single-quote { \' }
  token double-quote { \" }
  token word { \w+ }
  token number { \d+ }

  rule single-quoted-string { <single-quote><phrase><single-quote> }
  rule double-quoted-string { <double-quote><phrase><double-quote> }
  rule quoted-string { [ <single-quoted-string> | <double-quoted-string> ] }

  rule tag { '%' <word> }

  rule tags {
    [
      | <tag>
    ]*
  }

  rule TOP {
    <tags>
  }
}
