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
