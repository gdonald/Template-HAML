# Embedded Raku code

Template::HAML lets you embed Raku expressions directly in a template. Each
embedded line begins with an output operator and is followed by a Raku
expression.

## Operators

| Operator | Behavior                                                   |
|----------|------------------------------------------------------------|
| `=`      | Evaluate the expression, HTML-escape the result, emit it.  |
| `!=`     | Evaluate the expression, emit the result without escaping. |
| `&=`     | Evaluate the expression, force HTML-escape, emit it.       |
| `-`      | Evaluate the expression for side effects only — emit nothing. |

```haml
= 1 + 2
- my $x = 'hello'
= $x
!= '<b>raw</b>'
```

renders to:

```html
3
hello
<b>raw</b>
```

## Locals

Pass values into a template with the `:locals` named argument. Each key is bound
as a `$key` lexical visible to embedded expressions.

```raku
HAML.render(
  :src(q:to/HAML/),
    %h1= $title
    %p Visitor count: #{ $count }
    HAML
  :locals(%(:title<Welcome>, :count(42))),
);
```

Locals of any type are bound under the `$` sigil; reach into structured values
with the usual postfix syntax (`$items.elems`, `$cfg<title>`, `$user.name`).

Locals are also visible inside `#{...}` and `!{...}` interpolations in tag
content, plain text, and double-quoted attribute strings — see [Plain
text](plain-text.md) for the full interpolation syntax.

## Escaping

`=` escapes `& < > " '` by default. Use `!=` only when the value is already
known-safe HTML.

## Errors

Compilation or runtime failures inside embedded code are wrapped in
[`X::HAML::Eval`](../api.md#exceptions), which carries the offending source
line and column for diagnostics.
