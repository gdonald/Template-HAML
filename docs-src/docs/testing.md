# Tests

The test suite lives under `t/`. Each file uses Raku's built-in `Test` module.

## Run the suite

```shell
prove6 -Ilib t/
```

`prove6` is a TAP runner; `-Ilib` puts the project's modules on the include path. Install test-depends from `META6.json` first if you don't have them:

```shell
zef install --deps-only --/test --test-depends .
```

## Author tests

Author-only checks are gated behind `AUTHOR_TESTING=1`. The META validation in `t/000-meta.rakutest` runs only when this variable is set, so contributors don't fail builds over local metadata churn.

```shell
AUTHOR_TESTING=1 prove6 -Ilib t/
```

## Golden-file tests

`t/041-golden-files.rakutest` iterates `t/fixtures/golden/*.haml` against `t/fixtures/golden/*.html` and asserts the rendered output matches the recorded golden output. Add a new fixture by dropping a matched `.haml`/`.html` pair into that directory.

## CI

Every push to `main` and every PR runs `prove6 -Ilib t/` via the GitHub Actions workflow at `.github/workflows/ci.yml`. The matrix covers the latest Rakudo release and the prior minor release, and caches `~/.zef` per OS/version.
