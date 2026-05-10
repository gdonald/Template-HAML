# Control flow

Template::HAML recognizes a small set of control-flow keywords that follow the
silent operator `-`. Each opens an indented block whose body is conditionally
or repeatedly rendered; the keyword line itself produces no output and consumes
no level of output indentation.

## `if` / `elsif` / `else`

```haml
- if $count == 0
  %p Nothing here yet.
- elsif $count == 1
  %p One item.
- else
  %p
    Many items.
```

The first matching branch renders; subsequent `elsif`/`else` branches are
skipped. An `elsif` or `else` without a preceding `if`/`unless` raises
`X::HAML::OrphanElse`.

## `unless`

```haml
- unless $logged-in
  %a(href='/login') Sign in
```

`unless` is the inverse of `if`: it renders the body when the expression is
falsey. It also accepts trailing `elsif`/`else` branches.

## `for`

Both Raku-native and Python-flavored forms are accepted:

```haml
- for $items -> $item
  %li
    = $item.name

- for $name in $names
  %p
    = $name
```

The loop variable is added to the locals available to the body — and *only* the
body. Sibling lines outside the loop will not see the loop variable.

## `while`

```haml
- while $queue.elems
  %li
    = $queue.shift
```

Templates iterate at most `Renderer.max-while-iters` times (default `10000`) as
a runaway-loop safeguard.

## `given` / `when` / `default`

```haml
- given $status
  - when 'ok'
    %p.success All good
  - when 'warn'
    %p.warning Heads up
  - default
    %p.error Unknown status
```

`given EXPR` topicalizes the expression as `$_` for its `when` and `default`
children. Each `when EXPR` smartmatches against the topic (`$_ ~~ EXPR`); the
first match wins. `default` runs only if no `when` matched. Children other than
`when`/`default` directly under `given` are ignored.

## Indentation

A control-flow line consumes one level of source indentation but produces zero
levels in the output. So:

```haml
%div
  - if $show
    %p Hi
```

renders as:

```html
<div>
  <p>Hi</p>
</div>
```

— the `%p` is one level deep in the output, not two, because `- if` is
transparent.

## Errors

| Exception              | Raised when                                         |
|------------------------|-----------------------------------------------------|
| `X::HAML::OrphanElse`  | `elsif` or `else` appears without a preceding `if`. |
| `X::HAML::Eval`        | The condition or iterator expression fails to eval. |
