# Attributes

Template::HAML supports a Ruby-style attribute hash on any tag:

```haml
%a{href: '/about', title: 'About us'} About
```

```html
<a href='/about' title='About us'>About</a>
```

## Value types

Today the supported value types inside `{ ... }` are:

- Single-quoted strings: `'value'`
- Double-quoted strings: `"value"`
- Symbols (treated as strings): `:value`

```haml
%input{type: :text, name: 'email'}
%a{href: "/", class: 'home'} Home
```

## Multiple attributes

Separate attributes with commas:

```haml
%a{href: '/', class: 'home', id: 'home-link'} Home
```

```html
<a href='/' class='home' id='home-link'>Home</a>
```

## Class shorthand merges with `class:`

The `.classname` shorthand on a tag merges with any `class:` entry in the attribute hash. The two forms compose:

```haml
%p.lead{class: 'intro'} Welcome
```

```html
<p class='lead intro'>Welcome</p>
```

## Multi-line attribute hashes

An attribute hash, an HTML-style attribute list, an array value, or a nested hash may span multiple lines. The tag does not close until the matching `}` (or `)`) is seen.

```haml
%a{
  href: '/',
  title: 'home'
}
```

```html
<a href='/' title='home'></a>
```

Nested hashes and arrays may also span lines:

```haml
%a{
  class: ['foo', 'bar'],
  data: {
    id: 1,
    role: 'main'
  }
}
```

```html
<a class='foo bar' data-id='1' data-role='main'></a>
```

HTML-style attributes may also be split across lines:

```haml
%a(
  href='/'
  title='home'
)
```

```html
<a href='/' title='home'></a>
```

Content and child indentation pick up after the closing brace:

```haml
%ul{
  class: 'list'
}
  %li one
  %li two
```

```html
<ul class='list'>
  <li>one</li>
  <li>two</li>
</ul>
```

Source line numbers are preserved across multi-line hashes, so children render and report at their actual line in the source.
