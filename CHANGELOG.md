# Changelog

All notable changes to this project are documented here.

## [Unreleased]

### Fixed

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
