# tinygo.el

TinyGo support for Emacs language-server clients. It starts your usual Go LSP
server with the target-specific environment required to understand TinyGo,
including the `machine` package. Completion, diagnostics, navigation,
formatting, and refactoring stay in your existing Emacs LSP client and server.

The default server is [gopls](https://go.dev/gopls/), but any server that
speaks LSP over standard input/output can be used.

## How it works

TinyGo's [IDE guidance](https://tinygo.org/docs/guides/ide-integration/helix/)
is to run `gopls` with the `GOROOT`, `GOOS`, `GOARCH`, and build tags produced
by `tinygo info <target>`. This package obtains that environment and applies
it only to the TinyGo LSP workspace. It does not create a separate completion
engine or change ordinary Go projects.

## Requirements

- Emacs 27.1 or later. Eglot is built in from Emacs 29.
- [TinyGo](https://tinygo.org/getting-started/install/) on `exec-path`.
- A Go LSP server on `exec-path`, normally `gopls`.
- Eglot or [lsp-mode](https://emacs-lsp.github.io/lsp-mode/).
- A POSIX `env` command (Linux, macOS, and BSD work out of the box).

Install `gopls` if needed:

```sh
go install golang.org/x/tools/gopls@latest
```

## Installation

### package.el (Emacs 29+)

After publishing this repository, install it from its Git URL:

```elisp
(package-vc-install "https://github.com/zombieleet/emacs-tinygo")
(require 'tinygo)
```

### straight.el

```elisp
(straight-use-package
 '(tinygo :type git :host github :repo "zombieleet/emacs-tinygo"))
(require 'tinygo)
```

### Manual installation

Clone this repository, then add it to your init file:

```elisp
(add-to-list 'load-path "/path/to/emacs-tinygo")
(require 'tinygo)
```

## Select a TinyGo target

The target is project-specific. The recommended method is a `.tinygo-target`
file at the project root whose only contents are the target name:

```text
pico
```

`tinygo.el` finds this file from subdirectories automatically. Opening a Go or
Go tree-sitter buffer beneath it validates the target and starts TinyGo-aware
LSP support automatically. Commit the file when all contributors use the same
target.

Alternatively, configure Emacs directory locals in `.dir-locals.el`:

```elisp
((go-mode . ((tinygo-target . "pico"))))
```

For a session-only project setting, run `M-x tinygo-set-target`. The command
verifies the target with `tinygo info`, applies it to all open Go buffers in
the project, and restarts the active LSP workspace with a fresh environment.

## Automatic behavior

After `(require 'tinygo)`, simply open a Go file beneath `.tinygo-target`. The
package automatically prepares the TinyGo environment and starts an LSP client.
Ordinary Go projects are unaffected.

The `auto` client setting reuses an active Eglot or lsp-mode session, respects
an already loaded lsp-mode configuration, and otherwise prefers Eglot. To
choose explicitly:

```elisp
(setq tinygo-lsp-client 'eglot)    ; or 'lsp-mode
```

To disable automatic startup:

```elisp
(setq tinygo-auto-start nil)
```

Manual commands remain available:

```text
M-x tinygo-ensure
M-x tinygo-eglot-ensure
M-x tinygo-lsp-ensure
```

Use one LSP client per buffer: do not enable Eglot and lsp-mode together.

### Eglot

Eglot exposes LSP completions through Emacs's completion-at-point API. Its
server override is buffer-local, so normal Go projects retain their existing
Eglot configuration.

### lsp-mode

The TinyGo client has priority over the ordinary Go client, but activates only
when the buffer has a TinyGo target. Existing completion frontends such as
Corfu or Company continue to work.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `tinygo-command` | `"tinygo"` | TinyGo executable. |
| `tinygo-target` | `nil` | Target, including directory-local values. |
| `tinygo-lsp-server-command` | `("gopls")` | LSP server command. |
| `tinygo-lsp-client` | `auto` | `auto`, `eglot`, or `lsp-mode`. |
| `tinygo-auto-start` | `t` | Start automatically for `.tinygo-target`. |

For another compatible LSP server:

```elisp
(setq tinygo-lsp-server-command '("my-go-language-server" "--stdio"))
```

Run `M-x tinygo-clear-environment-cache` after a TinyGo upgrade or target
definition change. The next workspace will query `tinygo info` again.

## Troubleshooting

- **No TinyGo target:** create `.tinygo-target`, set `tinygo-target` in
  `.dir-locals.el`, or run `M-x tinygo-set-target`.
- **TinyGo is not found:** ensure `tinygo` is in Emacs's `exec-path`, then
  restart Emacs after changing shell configuration.
- **`machine` cannot be resolved:** stop the existing Go workspace, start it
  with `tinygo-ensure`, and verify `tinygo info <target>` works in a terminal.
- **Diagnostics show the prior target:** reconnect the workspace. A server
  restart is required to receive a changed environment.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md). Run all checks with:

```sh
make check
```

## License

Copyright © 2026 tinygo.el contributors. Distributed under the
[MIT License](LICENSE).
