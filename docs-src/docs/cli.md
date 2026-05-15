# Command-line interface

Template::HAML ships with a `haml` script for rendering and checking templates from the shell.

## Subcommands

| Command          | Purpose                                                     |
|------------------|-------------------------------------------------------------|
| `haml render`    | Render one or more HAML files to HTML.                      |
| `haml check`     | Parse-only sanity check; non-zero exit on parse failure.    |
| `haml fmt`       | Pretty-print a HAML file in [canonical form](canonical-form.md). |
| `haml help`      | Top-level help. Also `--help`, `-h`.                        |

## Rendering

```sh
haml render view.haml
```

Output goes to standard out. Multiple files are concatenated in the order given. To write the result to a file, pass `-o`:

```sh
haml render view.haml -o view.html
```

### Passing locals

Use `--locals` with a comma-separated list of `key=value` pairs:

```sh
haml render greet.haml --locals name=Alice,greeting=hi
```

The values are made available as Raku scalars inside the template (e.g. `#{$name}`).

### Format and escaping

| Flag                  | Effect                                                  |
|-----------------------|---------------------------------------------------------|
| `--format html5`      | HTML5 output (default).                                 |
| `--format html4`      | HTML 4.01 Transitional.                                 |
| `--format xhtml`      | XHTML 1.0 Transitional; void elements emit `<br />`.    |
| `--escape-html`       | Escape HTML in `=` expressions (default).               |
| `--no-escape-html`    | Disable HTML escaping for `=` expressions.              |
| `--ugly`              | Single-line output with no inter-tag whitespace.        |

## Checking

```sh
haml check view.haml
```

`check` parses each file and reports `OK` for files that parse cleanly. It exits with a non-zero status if any file fails to parse, so it is suitable for use in pre-commit hooks or CI.

## Formatting

```sh
haml fmt view.haml
```

`fmt` pretty-prints each HAML file in [canonical form](canonical-form.md) and writes the result to standard out. Use the following flags to change behavior:

| Flag           | Effect                                                                |
|----------------|-----------------------------------------------------------------------|
| `-o <path>`    | Write the formatted result to a file (single input only).             |
| `--in-place`   | Rewrite each input file with its canonical form.                      |
| `--check`      | Exit non-zero if any file differs from its canonical form. No output. |

`--check` mode is suitable for CI: it emits no stdout, writes a one-line diagnostic to stderr for each non-canonical file, and exits with status `1` when at least one file is out of form. `--in-place` and `-o` are mutually exclusive, and neither may be combined with `--check`.

The canonical form is idempotent: `haml fmt | haml fmt` always equals `haml fmt`. See the [canonical form spec](canonical-form.md) for the full set of rules.

## Help

Each subcommand has its own help:

```sh
haml --help
haml render --help
haml check --help
```
