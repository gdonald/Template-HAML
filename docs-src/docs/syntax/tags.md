# Tags

A tag in HAML is introduced by a sigil at the start of a line:

| Sigil | Meaning                              |
|-------|--------------------------------------|
| `%`   | Element name (`%p`, `%div`, `%h1`)   |
| `.`   | Class on a `<div>` (`.container`)    |
| `#`   | Id on a `<div>` (`#main`)            |

## Element names

```haml
%p Hello
%div A block
%h1 Title
```

renders to:

```html
<p>Hello</p>
<div>A block</div>
<h1>Title</h1>
```

## Class shorthand

`%tag.classname` adds a class to an element:

```haml
%p.lead Welcome
```

```html
<p class='lead'>Welcome</p>
```

You can chain multiple classes:

```haml
%p.lead.intro Welcome
```

```html
<p class='lead intro'>Welcome</p>
```

## Id shorthand

`%tag#name` sets the element's id:

```haml
%section#main
```

```html
<section id='main'></section>
```

## Combining shorthand and attributes

The class shorthand merges with a `class:` attribute hash entry:

```haml
%p.lead{class: 'intro'} Welcome
```

```html
<p class='lead intro'>Welcome</p>
```

See [Attributes](attributes.md) for the full attribute hash syntax.

## Shorthand interpolation

`#{ ... }` and `!{ ... }` are recognized inside class and id shorthand and
may be combined with literal segments (including hyphens):

```haml
%div.item-#{ $id }
%div#row-#{ $n }
%li.item-#{ $id }#row-#{ $n }
```

with `:locals(%(id => 7, n => 4))` renders to:

```html
<div class='item-7'></div>
<div id='row-4'></div>
<li id='row-4' class='item-7'></li>
```

Multiple interpolations may appear in a single shorthand segment:

```haml
%div.a-#{ $x }-b-#{ $y }
```

with `:locals(%(x => 1, y => 2))` renders to:

```html
<div class='a-1-b-2'></div>
```

`#{ ... }` HTML-escapes its value; `!{ ... }` emits it raw:

```haml
%div.item-#{ $s }
```

with `:locals(%(s => 'a&b'))` renders to:

```html
<div class='item-a&amp;b'></div>
```

Interpolated shorthand merges with hash-style `class:` and `id:` entries
using the same rules as plain shorthand — classes accumulate, ids
concatenate with `_`:

```haml
%p.item-#{ $id }{class: 'active'}
%p#row-#{ $n }{id: 'extra'}
```

with `:locals(%(id => 9, n => 5))` renders to:

```html
<p class='active item-9'></p>
<p id='row-5_extra'></p>
```

To produce a literal `#{...}` in a shorthand segment, escape the `#` with
a backslash:

```haml
%div.literal-\#{x}
```

renders to:

```html
<div class='literal-#{x}'></div>
```
