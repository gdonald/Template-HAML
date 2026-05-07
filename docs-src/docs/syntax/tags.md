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
