# Changelog

All notable changes to this project are documented here.

## [Unreleased]

### Fixed

- Keep the target after the language server starts. lsp-mode defers startup
  through a timer and binds `default-directory` to the workspace root before
  asking for the server command and environment, both of which re-resolved the
  target from that directory. Where `.tinygo-target` sits below the workspace
  root -- a Go module under `examples/` is the ordinary case -- this raised
  `No TinyGo target` from inside a timer, with nothing tying it to the file
  just opened. The resolved target is now pinned buffer-locally.
- Disable Flycheck checkers that drive the host Go toolchain. They resolve the
  host GOROOT rather than TinyGo's, lack the target's build tags, and reject
  `#cgo` flags TinyGo libraries depend on, so what they report describes the
  toolchain rather than the code -- and disabling one merely promotes the next
  in the chain. See `tinygo-disabled-flycheck-checkers`; `go-gofmt` is left
  alone, since formatting does not depend on any of this.
- Enable cgo for the language server. Passing GOARCH is what makes Go treat
  the analysis as a cross-build, and cgo is off by default there, so cgo files
  were dropped from every package. A library binding C then reported its whole
  API as undefined while GOROOT and the build tags looked correct -- espradio,
  whose `Enable`, `Connect` and `Scan` all live in a cgo file, produced seven
  `undefined: espradio.*` errors for a program that compiles. The server only
  parses, so this needs no C cross-compiler.
- Stop dropping the first character of `tinygo info` values that begin with
  the letter `t`. The separator was written `[ \t]` in Elisp source, which is
  the character class `[space backslash t]`, so `tinygo.wasm` was read as
  `inygo.wasm`. This affected every target whose leading build tag starts with
  `t`, including `wasm` and the ESP32-C3 boards, and made gopls select a
  different implementation file (`syscall/proc_hosted.go` instead of
  `proc_emulated.go` on wasm) with no visible error.
- Do not activate TinyGo support for ordinary Go projects when `tinygo-target`
  has a global value. The lsp-mode client has priority over the standard Go
  client, so it would take over unrelated Go work. Activation now requires a
  project-scoped target; explicit commands still honour the global default.
- Treat GOOS and GOARCH as optional. Only GOROOT and the build tags are
  specified by TinyGo's IDE guidance, so a release that renames or drops those
  lines now costs word-size accuracy rather than preventing the language server
  from starting at all.
- Pass the required context arguments to Eglot server-contact functions.
- Restart Eglot and lsp-mode with their required server/workspace objects.
- Validate interactive targets before changing project state.

### Changed

- Supply the server environment through lsp-mode's `:environment-fn` and, for
  Eglot, a `process-environment` binding, so a POSIX `env` command is no longer
  required. It is still used as the wrapper where available.
- Interactive target selections now apply to all open Go buffers in a project.
- Go buffers beneath `.tinygo-target` now start TinyGo LSP support by default.
- Automatic client selection now respects active or loaded lsp-mode setups.

### Added

- Initial public release with Eglot and lsp-mode integration.
- Target discovery through `.tinygo-target` and directory-local variables.
- ERT tests and GitHub Actions continuous integration.
