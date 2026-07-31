# Contributing to tinygo.el

Thank you for helping improve TinyGo support in Emacs.

## Development setup

Clone the repository and run:

```sh
make check
```

This requires Emacs 27.1 or later. Tests mock `tinygo info`, so TinyGo is not
required for the unit-test suite.

## Pull requests

- Keep each change focused and explain its user-visible behavior.
- Add ERT coverage for bug fixes and new behavior.
- Run `make check` before submitting.
- Update `README.md` when configuration or behavior changes.
- Preserve Emacs 27.1 compatibility unless deliberately raising the minimum.

## Bug reports

Include the Emacs version, TinyGo version, LSP client and server, target, the
value of `tinygo-lsp-server-command`, and `tinygo info <target>` output with
any sensitive paths removed.

## Style

Use conventional two-space Emacs Lisp indentation, lexical binding, clear
docstrings, and public names prefixed with `tinygo-`.
